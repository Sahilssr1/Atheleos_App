import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/models/notification_model.dart';
import '../domain/notification_navigation.dart';

/// Lightweight description of who triggered a notification.
class NotificationActor {
  final String id;
  final String name;
  final String avatar;

  const NotificationActor({
    required this.id,
    required this.name,
    this.avatar = '',
  });

  /// The platform itself (verification, security, announcements, welcome…).
  static const system =
      NotificationActor(id: 'system', name: 'ATHELEOS', avatar: '');
}

/// Central, modular pipeline for **creating** notifications.
///
/// Every producer in the app (likes, comments, follows, messages, events,
/// verification, system events) funnels through here so the production rules
/// live in exactly one place:
///  * never notify a user about their own action,
///  * honour the receiver's per-type preference toggle (Settings → Firestore),
///  * de-duplicate via deterministic document ids,
///  * denormalise the deep-link destination,
///  * queue an email for important, email-eligible events.
///
/// Adding a new notification type requires no changes here — only a new value
/// in [NotificationType] plus its metadata.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache of receiver preference maps to avoid re-reading settings on
  // every single like within a session. Cheap and bounded.
  final Map<String, Map<String, dynamic>> _prefsCache = {};

  CollectionReference<Map<String, dynamic>> _inbox(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('notifications');

  Future<Map<String, dynamic>> _receiverNotificationPrefs(String uid) async {
    final cached = _prefsCache[uid];
    if (cached != null) return cached;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('preferences')
          .get();
      final prefs = Map<String, dynamic>.from(
        snap.data()?['notifications'] ?? const {},
      );
      _prefsCache[uid] = prefs;
      return prefs;
    } catch (_) {
      return const {};
    }
  }

  /// Clears any cached preferences (call after the user edits Settings).
  void invalidatePrefsCache([String? uid]) {
    if (uid == null) {
      _prefsCache.clear();
    } else {
      _prefsCache.remove(uid);
    }
  }

  /// The generic creation entry-point. Type-specific helpers below delegate here.
  ///
  /// [dedupeKey] produces a deterministic document id so repeated identical
  /// actions (e.g. like → unlike → like) collapse onto a single notification
  /// instead of spamming the inbox.
  Future<void> create({
    required String receiverId,
    required NotificationType type,
    required NotificationActor actor,
    String? title,
    String? body,
    String? relatedObjectId,
    String? secondaryObjectId,
    String? thumbnailUrl,
    String? dedupeKey,
    Map<String, dynamic> data = const {},
    bool allowSelf = false,
    String? emailSubject,
    String? emailHtml,
  }) async {
    if (receiverId.isEmpty) return;

    // 1. Never notify a user about their own action (except self-directed
    //    system notifications such as "password changed").
    if (!allowSelf && receiverId == actor.id) return;

    // 2. Honour the receiver's per-type preference toggle.
    final prefKey = type.preferenceKey;
    if (prefKey != null) {
      final prefs = await _receiverNotificationPrefs(receiverId);
      final enabled = prefs[prefKey];
      if (enabled is bool && enabled == false) {
        return; // user disabled this category → generate nothing.
      }
    }

    // 3. Deterministic id for de-duplication.
    final docId = dedupeKey ??
        'ntf_${type.id}_${DateTime.now().microsecondsSinceEpoch}';

    final resolvedBody = (body == null || body.isEmpty) ? type.meta.defaultBody : body;
    final resolvedTitle = (title == null || title.isEmpty) ? actor.name : title;

    final deepLink = NotificationNavigation.routeFor(
      type: type,
      senderId: actor.id,
      relatedObjectId: relatedObjectId,
      secondaryObjectId: secondaryObjectId,
    );

    final map = <String, dynamic>{
      'id': docId,
      'type': type.id,
      'category': type.category.id,
      'senderId': actor.id,
      'senderName': actor.name,
      'senderAvatar': actor.avatar,
      'receiverId': receiverId,
      'relatedObjectId': relatedObjectId,
      'secondaryObjectId': secondaryObjectId,
      'title': resolvedTitle,
      'body': resolvedBody,
      'thumbnailUrl': thumbnailUrl,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'deepLink': deepLink,
      'data': data,
    };

    try {
      await _inbox(receiverId).doc(docId).set(map);
    } catch (e) {
      debugPrint('NotificationService: failed to write notification: $e');
      return;
    }

    // 4. Email fan-out for important, email-eligible events.
    if (type.emailEligible) {
      await _maybeQueueEmail(
        receiverId: receiverId,
        subject: emailSubject ?? resolvedTitle,
        html: emailHtml ?? '<p>$resolvedBody</p>',
      );
    }
  }

  /// Writes to the `mail` collection consumed by the Firebase "Trigger Email"
  /// extension (or any server worker). Gated by the receiver's master
  /// `emailNotifications` toggle. No-ops silently if the user opted out.
  Future<void> _maybeQueueEmail({
    required String receiverId,
    required String subject,
    required String html,
  }) async {
    try {
      final prefs = await _receiverNotificationPrefs(receiverId);
      final emailEnabled = prefs['emailNotifications'];
      if (emailEnabled is bool && emailEnabled == false) return;

      final userSnap =
          await _firestore.collection('users').doc(receiverId).get();
      final email = userSnap.data()?['email'] as String?;
      if (email == null || email.isEmpty) return;

      await _firestore.collection('mail').add({
        'to': email,
        'uid': receiverId,
        'message': {'subject': subject, 'html': html},
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('NotificationService: failed to queue email: $e');
    }
  }

  // ── Typed producers ───────────────────────────────────────────────────────
  // These are thin, self-documenting wrappers used across the codebase.

  Future<void> like({
    required String receiverId,
    required NotificationActor actor,
    required String contentId,
    required bool isReel,
    String? thumbnailUrl,
  }) {
    return create(
      receiverId: receiverId,
      type: isReel ? NotificationType.reelLike : NotificationType.postLike,
      actor: actor,
      relatedObjectId: contentId,
      thumbnailUrl: thumbnailUrl,
      // One like-doc per (content, actor) so unlike/relike never duplicates.
      dedupeKey: 'like_${contentId}_${actor.id}',
    );
  }

  Future<void> comment({
    required String receiverId,
    required NotificationActor actor,
    required String contentId,
    required String commentId,
    required bool isReel,
    String? preview,
    String? thumbnailUrl,
  }) {
    return create(
      receiverId: receiverId,
      type: isReel ? NotificationType.reelComment : NotificationType.postComment,
      actor: actor,
      relatedObjectId: contentId,
      secondaryObjectId: commentId,
      body: preview == null || preview.isEmpty
          ? null
          : (isReel ? 'commented on your reel: "$preview"' : 'commented: "$preview"'),
      thumbnailUrl: thumbnailUrl,
      dedupeKey: 'comment_$commentId',
    );
  }

  Future<void> commentReply({
    required String receiverId,
    required NotificationActor actor,
    required String contentId,
    required String commentId,
    String? preview,
  }) {
    return create(
      receiverId: receiverId,
      type: NotificationType.commentReply,
      actor: actor,
      relatedObjectId: contentId,
      secondaryObjectId: commentId,
      body: preview == null || preview.isEmpty ? null : 'replied: "$preview"',
      dedupeKey: 'reply_$commentId',
    );
  }

  Future<void> follow({
    required String receiverId,
    required NotificationActor actor,
  }) {
    return create(
      receiverId: receiverId,
      type: NotificationType.follow,
      actor: actor,
      dedupeKey: 'follow_${actor.id}',
    );
  }

  Future<void> message({
    required String receiverId,
    required NotificationActor actor,
    required String messageId,
    NotificationType type = NotificationType.message,
    String? preview,
    bool isRequest = false,
  }) {
    return create(
      receiverId: receiverId,
      type: isRequest ? NotificationType.messageRequest : type,
      actor: actor,
      relatedObjectId: messageId,
      body: preview,
      dedupeKey: 'message_$messageId',
    );
  }

  /// Self-directed system/security notification (e.g. password changed).
  Future<void> system({
    required String receiverId,
    required NotificationType type,
    String? title,
    String? body,
    String? emailSubject,
    String? emailHtml,
  }) {
    return create(
      receiverId: receiverId,
      type: type,
      actor: NotificationActor.system,
      title: title,
      body: body,
      allowSelf: true,
      emailSubject: emailSubject,
      emailHtml: emailHtml,
    );
  }
}
