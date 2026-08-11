import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/notifications/domain/models/notification_model.dart';
import '../../features/notifications/domain/notification_navigation.dart';
import '../../firebase_options.dart';

/// Background / terminated FCM handler.
///
/// Must be a top-level (or static) function. When the OS delivers a message
/// while the app is backgrounded or terminated it spins up a background
/// isolate and calls this. The system tray notification is drawn automatically
/// by the OS for messages carrying a `notification` block; we only need to make
/// sure Firebase is initialised in the isolate.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialised.
  }
  // No heavy work here — deep-link routing happens on tap via onMessageOpenedApp.
  debugPrint('FCM background message: ${message.messageId}');
}

/// Central push-notification integration (Firebase Cloud Messaging).
///
/// Responsibilities:
///  * request permission + configure foreground presentation,
///  * manage the device FCM token (`users/{uid}/fcm_tokens/{token}`),
///  * display foreground messages via a local notification,
///  * resolve taps (foreground, background, terminated) into a deep-link route
///    exposed through [pendingRoute] for the app shell to consume.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Emits a GoRouter location whenever a notification tap should navigate.
  /// The app shell listens and performs the actual navigation.
  final ValueNotifier<String?> pendingRoute = ValueNotifier<String?>(null);

  bool _initialised = false;
  String? _boundUid;
  StreamSubscription<String>? _tokenRefreshSub;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'atheleos_default',
    'General Notifications',
    description: 'Likes, comments, follows, messages and updates.',
    importance: Importance.high,
  );

  /// One-time initialisation. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialised) return;
    _initialised = true;

    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS: show heads-up notifications while the app is in the foreground.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _initLocalNotifications();

      // Foreground messages → draw a local notification so the user sees it.
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);

      // Tap on a system notification while backgrounded.
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => _routeFromData(m.data),
      );

      // Cold start from a terminated state via a notification tap.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _routeFromData(initial.data);
      }
    } catch (e) {
      debugPrint('PushNotificationService.initialize failed: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingRoute.value = payload;
        }
      },
    );

    // Android notification channel registration.
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    final route = _routeForData(message.data);

    // Prefer the FCM notification block; fall back to data fields.
    final title = notification?.title ?? message.data['title'] ?? 'ATHELEOS';
    final body = notification?.body ?? message.data['body'] ?? '';

    _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: route,
    );
  }

  /// Builds a deep-link route from an FCM data payload.
  String _routeForData(Map<String, dynamic> data) {
    // A denormalised deepLink always wins when present.
    final explicit = data['deepLink'] as String?;
    if (explicit != null && explicit.isNotEmpty) return explicit;

    final type = NotificationTypeX.fromId(data['type'] as String?);
    return NotificationNavigation.routeFor(
      type: type,
      senderId: (data['senderId'] as String?) ?? 'system',
      relatedObjectId: data['relatedObjectId'] as String?,
      secondaryObjectId: data['secondaryObjectId'] as String?,
    );
  }

  void _routeFromData(Map<String, dynamic> data) {
    pendingRoute.value = _routeForData(data);
  }

  /// Call once the user is authenticated. Persists the device token so the
  /// backend can target this device, and keeps it fresh on rotation.
  Future<void> registerToken(String uid) async {
    if (uid.isEmpty) return;
    _boundUid = uid;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(uid, token);
      }
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((t) {
        if (_boundUid != null) _saveToken(_boundUid!, t);
      });
    } catch (e) {
      debugPrint('PushNotificationService.registerToken failed: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcm_tokens')
        .doc(token)
        .set({
      'token': token,
      'platform': _platformName(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Call on sign-out so the device stops receiving the user's notifications.
  Future<void> unregisterToken(String uid) async {
    if (uid.isEmpty) return;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    _boundUid = null;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fcm_tokens')
            .doc(token)
            .delete();
      }
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('PushNotificationService.unregisterToken failed: $e');
    }
  }

  /// Consumes and clears the pending deep-link route (call after navigating).
  String? consumePendingRoute() {
    final route = pendingRoute.value;
    pendingRoute.value = null;
    return route;
  }

  String _platformName() {
    try {
      if (kIsWeb) return 'web';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }
}
