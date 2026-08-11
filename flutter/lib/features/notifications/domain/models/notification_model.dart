import 'package:cloud_firestore/cloud_firestore.dart';

/// High-level grouping used for the filter chips in the Notification Center.
enum NotificationCategory {
  all,
  social,
  stories,
  messages,
  verification,
  events,
  coaches,
  federations,
  collaborations,
  system,
}

extension NotificationCategoryX on NotificationCategory {
  /// Stable string persisted to Firestore.
  String get id => name;

  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.social:
        return 'Social';
      case NotificationCategory.stories:
        return 'Stories';
      case NotificationCategory.messages:
        return 'Messages';
      case NotificationCategory.verification:
        return 'Verification';
      case NotificationCategory.events:
        return 'Events';
      case NotificationCategory.coaches:
        return 'Coaches';
      case NotificationCategory.federations:
        return 'Federations';
      case NotificationCategory.collaborations:
        return 'Collabs';
      case NotificationCategory.system:
        return 'System';
    }
  }

  static NotificationCategory fromId(String? id) {
    return NotificationCategory.values.firstWhere(
      (c) => c.id == id,
      orElse: () => NotificationCategory.all,
    );
  }
}

/// Every notification kind the platform can emit. The enum is the single source
/// of truth: adding a new notification type only requires (1) a new value here,
/// (2) its metadata in [NotificationTypeMeta.of], and (3) a route in the
/// navigation resolver. Nothing else in the pipeline needs to change.
enum NotificationType {
  // ── Social ────────────────────────────────────────────────────────────────
  postLike,
  reelLike,
  storyLike,
  postComment,
  reelComment,
  commentReply,
  mention,
  follow,
  followRequest,
  followAccept,
  postShare,
  reelShare,
  bookmark,

  // ── Stories ─────────────────────────────────────────────────────────────
  storyReply,
  storyMention,
  storyReaction,

  // ── Messages ────────────────────────────────────────────────────────────
  message,
  messageRequest,
  voiceMessage,
  imageMessage,
  videoMessage,

  // ── Verification ────────────────────────────────────────────────────────
  verificationSubmitted,
  verificationApproved,
  verificationRejected,
  verificationMoreInfo,

  // ── Events ──────────────────────────────────────────────────────────────
  eventInvitation,
  eventAccepted,
  eventReminder,
  eventCancelled,
  eventUpdated,
  tournamentInvitation,

  // ── Coaches ─────────────────────────────────────────────────────────────
  coachInvitation,
  coachAccepted,
  coachDeclined,

  // ── Federations ─────────────────────────────────────────────────────────
  federationAnnouncement,
  competitionAnnouncement,

  // ── Collaborations ──────────────────────────────────────────────────────
  collabRequest,
  collabAccepted,
  collabRejected,

  // ── System ──────────────────────────────────────────────────────────────
  welcome,
  accountWarning,
  securityAlert,
  passwordChanged,
  emailChanged,
  phoneChanged,
  newLogin,
  appUpdate,

  /// Fallback for forward-compatibility when the app receives a type it does
  /// not yet understand (older client, newer server).
  unknown,
}

/// Static metadata attached to each [NotificationType]. Keeping this in one
/// place makes the system modular — new categories, preference keys, default
/// copy and email-eligibility all live together.
class NotificationTypeMeta {
  /// The grouping used for filtering.
  final NotificationCategory category;

  /// The key inside `settings/preferences.notifications.*` that gates whether a
  /// push notification is generated. `null` means the type is always delivered
  /// (e.g. security alerts).
  final String? preferenceKey;

  /// Default action verb / body used when a caller does not supply its own.
  final String defaultBody;

  /// Whether an email should also be sent when the user has email
  /// notifications enabled. Reserved for important events only.
  final bool emailEligible;

  const NotificationTypeMeta({
    required this.category,
    required this.preferenceKey,
    required this.defaultBody,
    this.emailEligible = false,
  });

  static const Map<NotificationType, NotificationTypeMeta> _table = {
    // Social
    NotificationType.postLike: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'liked your post'),
    NotificationType.reelLike: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'liked your reel'),
    NotificationType.storyLike: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'liked your story'),
    NotificationType.postComment: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'comments',
        defaultBody: 'commented on your post'),
    NotificationType.reelComment: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'comments',
        defaultBody: 'commented on your reel'),
    NotificationType.commentReply: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'replies',
        defaultBody: 'replied to your comment'),
    NotificationType.mention: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'mentions',
        defaultBody: 'mentioned you'),
    NotificationType.follow: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'newFollowers',
        defaultBody: 'started following you'),
    NotificationType.followRequest: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'newFollowers',
        defaultBody: 'requested to follow you'),
    NotificationType.followAccept: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'newFollowers',
        defaultBody: 'accepted your follow request'),
    NotificationType.postShare: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'shared your post'),
    NotificationType.reelShare: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'shared your reel'),
    NotificationType.bookmark: NotificationTypeMeta(
        category: NotificationCategory.social,
        preferenceKey: 'likes',
        defaultBody: 'saved your content'),

    // Stories
    NotificationType.storyReply: NotificationTypeMeta(
        category: NotificationCategory.stories,
        preferenceKey: 'comments',
        defaultBody: 'replied to your story'),
    NotificationType.storyMention: NotificationTypeMeta(
        category: NotificationCategory.stories,
        preferenceKey: 'mentions',
        defaultBody: 'mentioned you in their story'),
    NotificationType.storyReaction: NotificationTypeMeta(
        category: NotificationCategory.stories,
        preferenceKey: 'likes',
        defaultBody: 'reacted to your story'),

    // Messages
    NotificationType.message: NotificationTypeMeta(
        category: NotificationCategory.messages,
        preferenceKey: 'directMessages',
        defaultBody: 'sent you a message'),
    NotificationType.messageRequest: NotificationTypeMeta(
        category: NotificationCategory.messages,
        preferenceKey: 'directMessages',
        defaultBody: 'sent you a message request'),
    NotificationType.voiceMessage: NotificationTypeMeta(
        category: NotificationCategory.messages,
        preferenceKey: 'directMessages',
        defaultBody: 'sent you a voice message'),
    NotificationType.imageMessage: NotificationTypeMeta(
        category: NotificationCategory.messages,
        preferenceKey: 'directMessages',
        defaultBody: 'sent you a photo'),
    NotificationType.videoMessage: NotificationTypeMeta(
        category: NotificationCategory.messages,
        preferenceKey: 'directMessages',
        defaultBody: 'sent you a video'),

    // Verification (important → email eligible)
    NotificationType.verificationSubmitted: NotificationTypeMeta(
        category: NotificationCategory.verification,
        preferenceKey: 'verificationUpdates',
        defaultBody: 'Your verification request was submitted',
        emailEligible: true),
    NotificationType.verificationApproved: NotificationTypeMeta(
        category: NotificationCategory.verification,
        preferenceKey: 'verificationUpdates',
        defaultBody: 'Your account has been verified',
        emailEligible: true),
    NotificationType.verificationRejected: NotificationTypeMeta(
        category: NotificationCategory.verification,
        preferenceKey: 'verificationUpdates',
        defaultBody: 'Your verification request was declined',
        emailEligible: true),
    NotificationType.verificationMoreInfo: NotificationTypeMeta(
        category: NotificationCategory.verification,
        preferenceKey: 'verificationUpdates',
        defaultBody: 'We need more information to verify your account',
        emailEligible: true),

    // Events (reminders → email eligible)
    NotificationType.eventInvitation: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'eventReminders',
        defaultBody: 'invited you to an event'),
    NotificationType.eventAccepted: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'eventReminders',
        defaultBody: 'accepted your event invitation'),
    NotificationType.eventReminder: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'eventReminders',
        defaultBody: 'Your event is starting soon',
        emailEligible: true),
    NotificationType.eventCancelled: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'eventReminders',
        defaultBody: 'An event you joined was cancelled'),
    NotificationType.eventUpdated: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'eventReminders',
        defaultBody: 'An event you joined was updated'),
    NotificationType.tournamentInvitation: NotificationTypeMeta(
        category: NotificationCategory.events,
        preferenceKey: 'tournamentInvitations',
        defaultBody: 'invited you to a tournament'),

    // Coaches
    NotificationType.coachInvitation: NotificationTypeMeta(
        category: NotificationCategory.coaches,
        preferenceKey: 'coachInvitations',
        defaultBody: 'sent you a coaching invitation'),
    NotificationType.coachAccepted: NotificationTypeMeta(
        category: NotificationCategory.coaches,
        preferenceKey: 'coachInvitations',
        defaultBody: 'accepted your coaching request'),
    NotificationType.coachDeclined: NotificationTypeMeta(
        category: NotificationCategory.coaches,
        preferenceKey: 'coachInvitations',
        defaultBody: 'declined your coaching request'),

    // Federations
    NotificationType.federationAnnouncement: NotificationTypeMeta(
        category: NotificationCategory.federations,
        preferenceKey: 'federationAnnouncements',
        defaultBody: 'posted an announcement'),
    NotificationType.competitionAnnouncement: NotificationTypeMeta(
        category: NotificationCategory.federations,
        preferenceKey: 'federationAnnouncements',
        defaultBody: 'announced a new competition'),

    // Collaborations (requests → email eligible)
    NotificationType.collabRequest: NotificationTypeMeta(
        category: NotificationCategory.collaborations,
        preferenceKey: 'collaborationRequests',
        defaultBody: 'sent you a collaboration request',
        emailEligible: true),
    NotificationType.collabAccepted: NotificationTypeMeta(
        category: NotificationCategory.collaborations,
        preferenceKey: 'collaborationRequests',
        defaultBody: 'accepted your collaboration request'),
    NotificationType.collabRejected: NotificationTypeMeta(
        category: NotificationCategory.collaborations,
        preferenceKey: 'collaborationRequests',
        defaultBody: 'declined your collaboration request'),

    // System — never gated by a per-type toggle; security items are email eligible.
    NotificationType.welcome: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'Welcome to ATHELEOS'),
    NotificationType.accountWarning: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'There is an important update about your account',
        emailEligible: true),
    NotificationType.securityAlert: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'We noticed unusual activity on your account',
        emailEligible: true),
    NotificationType.passwordChanged: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'Your password was changed',
        emailEligible: true),
    NotificationType.emailChanged: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'Your email address was changed',
        emailEligible: true),
    NotificationType.phoneChanged: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'Your phone number was changed',
        emailEligible: true),
    NotificationType.newLogin: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'A new device signed in to your account',
        emailEligible: true),
    NotificationType.appUpdate: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'A new version of ATHELEOS is available'),

    NotificationType.unknown: NotificationTypeMeta(
        category: NotificationCategory.system,
        preferenceKey: null,
        defaultBody: 'You have a new notification'),
  };

  static NotificationTypeMeta of(NotificationType type) =>
      _table[type] ?? _table[NotificationType.unknown]!;
}

extension NotificationTypeX on NotificationType {
  /// Stable string persisted to Firestore & FCM payloads.
  String get id => name;

  NotificationTypeMeta get meta => NotificationTypeMeta.of(this);

  NotificationCategory get category => meta.category;

  String? get preferenceKey => meta.preferenceKey;

  bool get emailEligible => meta.emailEligible;

  static NotificationType fromId(String? id) {
    if (id == null) return NotificationType.unknown;
    return NotificationType.values.firstWhere(
      (t) => t.id == id,
      orElse: () => NotificationType.unknown,
    );
  }
}

/// The canonical, scalable notification document.
///
/// Firestore path: `users/{receiverId}/notifications/{id}`.
class AppNotification {
  final String id;
  final NotificationType type;

  /// Who triggered it (may be a real user, a federation/brand, or 'system').
  final String senderId;
  final String senderName;
  final String senderAvatar;

  /// Inbox owner.
  final String receiverId;

  /// Primary object the notification points at (post id, event id, chat room id…).
  final String? relatedObjectId;

  /// Optional second identifier (e.g. the specific comment inside a post).
  final String? secondaryObjectId;

  final String title;
  final String body;

  /// Optional media preview (post/reel/story thumbnail).
  final String? thumbnailUrl;

  final bool read;
  final DateTime createdAt;

  /// Pre-computed deep-link route. Kept denormalised so both in-app taps and
  /// FCM payloads resolve to the exact same destination.
  final String? deepLink;

  /// Free-form extension bag for future notification types — keeps the model
  /// future-proof without schema migrations.
  final Map<String, dynamic> data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
    required this.receiverId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.relatedObjectId,
    this.secondaryObjectId,
    this.thumbnailUrl,
    this.deepLink,
    this.data = const {},
  });

  NotificationCategory get category => type.category;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      receiverId: receiverId,
      relatedObjectId: relatedObjectId,
      secondaryObjectId: secondaryObjectId,
      title: title,
      body: body,
      thumbnailUrl: thumbnailUrl,
      read: read ?? this.read,
      createdAt: createdAt,
      deepLink: deepLink,
      data: data,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.id,
        'category': category.id,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'receiverId': receiverId,
        'relatedObjectId': relatedObjectId,
        'secondaryObjectId': secondaryObjectId,
        'title': title,
        'body': body,
        'thumbnailUrl': thumbnailUrl,
        'read': read,
        'createdAt': createdAt is DateTime
            ? Timestamp.fromDate(createdAt)
            : FieldValue.serverTimestamp(),
        'deepLink': deepLink,
        'data': data,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map, String id) {
    final rawCreated = map['createdAt'];
    final createdAt = rawCreated is Timestamp
        ? rawCreated.toDate()
        : (rawCreated is DateTime ? rawCreated : DateTime.now());

    return AppNotification(
      id: id,
      type: NotificationTypeX.fromId(map['type'] as String?),
      senderId: map['senderId'] as String? ?? 'system',
      senderName: map['senderName'] as String? ?? 'ATHELEOS',
      senderAvatar: map['senderAvatar'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      relatedObjectId: map['relatedObjectId'] as String?,
      secondaryObjectId: map['secondaryObjectId'] as String?,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      read: map['read'] as bool? ?? false,
      createdAt: createdAt,
      deepLink: map['deepLink'] as String?,
      data: (map['data'] is Map)
          ? Map<String, dynamic>.from(map['data'] as Map)
          : const {},
    );
  }

  /// Instagram-style compact relative time: `now`, `5m`, `3h`, `2d`, `4w`, `1y`.
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 365).floor()}y';
  }

  /// Whether tapping this notification should open a user profile (avatar tap
  /// and body tap resolve to the same place for follow-type notifications).
  bool get pointsToProfile =>
      type == NotificationType.follow ||
      type == NotificationType.followRequest ||
      type == NotificationType.followAccept;
}
