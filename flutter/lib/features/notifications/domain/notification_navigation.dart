import 'models/notification_model.dart';

/// Single source of truth that maps a notification to the exact in-app route.
///
/// Used both by an in-app tap (Notification Center) and by an FCM tap
/// (foreground/background/terminated) so every entry point lands on the same
/// destination. Adding a new notification type only needs a `case` here.
class NotificationNavigation {
  const NotificationNavigation._();

  /// Resolves the GoRouter location for [type] given the related object ids.
  /// Returns a safe fallback (`/notifications`) when a target is missing.
  static String routeFor({
    required NotificationType type,
    required String senderId,
    String? relatedObjectId,
    String? secondaryObjectId,
  }) {
    String profile(String id) => '/profile/$id';
    // Reels are posts (unified PostModel) so both open in the post detail viewer.
    String post(String id, {String? commentId}) =>
        commentId != null ? '/post/$id?commentId=$commentId' : '/post/$id';
    String chat() => '/chat/room?receiverId=$senderId';

    switch (type) {
      // ── Social: content likes / comments / shares / bookmarks ────────────
      case NotificationType.postLike:
      case NotificationType.postComment:
      case NotificationType.postShare:
      case NotificationType.bookmark:
      case NotificationType.reelLike:
      case NotificationType.reelComment:
      case NotificationType.reelShare:
        return relatedObjectId != null ? post(relatedObjectId) : profile(senderId);

      case NotificationType.commentReply:
        if (relatedObjectId != null && secondaryObjectId != null) {
          return post(relatedObjectId, commentId: secondaryObjectId);
        }
        return relatedObjectId != null ? post(relatedObjectId) : profile(senderId);

      case NotificationType.mention:
        // relatedObjectId encodes the surface (post/reel); secondary may be a comment.
        if (relatedObjectId != null && secondaryObjectId != null) {
          return post(relatedObjectId, commentId: secondaryObjectId);
        }
        return relatedObjectId != null ? post(relatedObjectId) : profile(senderId);

      // ── Social: follows ──────────────────────────────────────────────────
      case NotificationType.follow:
      case NotificationType.followRequest:
      case NotificationType.followAccept:
        return profile(senderId);

      // ── Stories ─────────────────────────────────────────────────────────
      case NotificationType.storyLike:
      case NotificationType.storyReply:
      case NotificationType.storyMention:
      case NotificationType.storyReaction:
        return profile(senderId);

      // ── Messages ────────────────────────────────────────────────────────
      case NotificationType.message:
      case NotificationType.messageRequest:
      case NotificationType.voiceMessage:
      case NotificationType.imageMessage:
      case NotificationType.videoMessage:
        return chat();

      // ── Verification ────────────────────────────────────────────────────
      case NotificationType.verificationSubmitted:
      case NotificationType.verificationApproved:
      case NotificationType.verificationRejected:
      case NotificationType.verificationMoreInfo:
        return '/settings/verification';

      // ── Events ──────────────────────────────────────────────────────────
      case NotificationType.eventInvitation:
      case NotificationType.eventAccepted:
      case NotificationType.eventReminder:
      case NotificationType.eventCancelled:
      case NotificationType.eventUpdated:
      case NotificationType.tournamentInvitation:
        return relatedObjectId != null ? '/events/$relatedObjectId' : '/events';

      // ── Coaches / Collaborations → open the requester's profile ──────────
      case NotificationType.coachInvitation:
      case NotificationType.coachAccepted:
      case NotificationType.coachDeclined:
      case NotificationType.collabRequest:
      case NotificationType.collabAccepted:
      case NotificationType.collabRejected:
        return profile(senderId);

      // ── Federations ─────────────────────────────────────────────────────
      case NotificationType.federationAnnouncement:
      case NotificationType.competitionAnnouncement:
        return profile(senderId);

      // ── System / security ───────────────────────────────────────────────
      case NotificationType.passwordChanged:
      case NotificationType.emailChanged:
      case NotificationType.phoneChanged:
      case NotificationType.securityAlert:
      case NotificationType.newLogin:
      case NotificationType.accountWarning:
        return '/settings';

      case NotificationType.welcome:
      case NotificationType.appUpdate:
      case NotificationType.unknown:
        return '/notifications';
    }
  }

  /// Convenience overload for a materialised [AppNotification]. Prefers the
  /// denormalised [AppNotification.deepLink] when present.
  static String forNotification(AppNotification n) {
    if (n.deepLink != null && n.deepLink!.isNotEmpty) return n.deepLink!;
    return routeFor(
      type: n.type,
      senderId: n.senderId,
      relatedObjectId: n.relatedObjectId,
      secondaryObjectId: n.secondaryObjectId,
    );
  }
}
