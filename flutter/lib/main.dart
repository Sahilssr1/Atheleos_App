import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'dart:async';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'firebase_options.dart';
import 'core/services/cache_manager.dart';
import 'core/services/push_notification_service.dart';
import 'features/profile/presentation/controllers/settings_controller.dart';
import 'features/profile/presentation/controllers/profile_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap the global Flutter ImageCache so scrolling through hundreds of
  // posts can't grow the resident set forever. Values chosen to match a
  // typical short-form video app: ~150 decoded images / ~60 MB of RAM.
  PaintingBinding.instance.imageCache.maximumSize = 150;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 60 << 20; // 60 MB

  await CacheManager().init();
  timezone_data.initializeTimeZones();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 104857600, // 100 MB capped LRU cache to prevent phone storage crashes
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await PushNotificationService.instance.initialize();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const SizedBox.shrink();
  };

  runApp(
    const ProviderScope(
      child: AtheleosApp(),
    ),
  );
}

class AtheleosApp extends ConsumerStatefulWidget {
  const AtheleosApp({super.key});

  @override
  ConsumerState<AtheleosApp> createState() => _AtheleosAppState();
}

class _AtheleosAppState extends ConsumerState<AtheleosApp> {
  final _push = PushNotificationService.instance;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Keep logged-in user state in sync with Firebase Auth
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.uid.isNotEmpty) {
        if (ref.read(loggedInUserIdProvider).isEmpty) {
          ref.read(loggedInUserIdProvider.notifier).state = user.uid;
          ref.read(currentProfileIdProvider.notifier).state = user.uid;
        }
      }
    });

    // Route to any notification that launched the app from a terminated state.
    _push.pendingRoute.addListener(_handlePendingRoute);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingRoute();
      // Register the FCM token for the currently logged-in user.
      final uid = ref.read(loggedInUserIdProvider);
      if (uid.isNotEmpty) {
        _push.registerToken(uid);
      }
    });
  }

  void _handlePendingRoute() {
    final route = _push.consumePendingRoute();
    if (route == null || route.isEmpty) return;
    final router = ref.read(appRouterProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.push(route);
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _push.pendingRoute.removeListener(_handlePendingRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the FCM token bound to whoever is logged in.
    ref.listen<String>(loggedInUserIdProvider, (previous, next) {
      if (previous != null && previous.isNotEmpty && previous != next) {
        _push.unregisterToken(previous);
      }
      if (next.isNotEmpty) {
        _push.registerToken(next);
      }
    });

    final router = ref.watch(appRouterProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final themeMode = switch (preferences.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'Atheleos',
      debugShowCheckedModeBanner: false,

      // Material 3 Dark theme (sports-centric, high contrast volt & slate style)
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: Locale(preferences.language),
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // GoRouter Configuration
      routerConfig: router,
    );
  }
}
