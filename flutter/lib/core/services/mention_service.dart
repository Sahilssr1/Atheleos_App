import 'package:flutter/foundation.dart';
import '../../features/profile/domain/models/profile_model.dart';
import '../../features/notifications/data/notification_service.dart';
import '../../features/notifications/domain/models/notification_model.dart';
import '../models/mention_model.dart';

class MentionService {
  /// Regular expression to match @username tags.
  /// Supports standard alphanumeric characters, underscores, and dots in usernames.
  static final RegExp _mentionRegex = RegExp(r'@([a-zA-Z0-9_\.]+)');

  /// Parses text to extract and map mentions to their actual UIDs using the list of profiles.
  static List<MentionModel> parseAndMapMentions(
      String text, List<ProfileModel> allProfiles) {
    if (text.isEmpty) return const [];

    final matches = _mentionRegex.allMatches(text);
    final Set<MentionModel> uniqueMentions = {};

    for (final match in matches) {
      final matchedText = match.group(0);
      if (matchedText == null) continue;

      // Extract username without '@' and map case-insensitively
      final cleanUsername = matchedText.substring(1).trim().toLowerCase();

      try {
        final profile = allProfiles.firstWhere(
          (p) => p.username.toLowerCase() == cleanUsername,
        );
        uniqueMentions.add(MentionModel(
          uid: profile.id,
          username: profile.username,
        ));
      } catch (_) {
        // Fallback: Username not found in the seeded list (e.g. invalid username)
        debugPrint(
            'Mentioned username "$cleanUsername" does not match any profile.');
      }
    }

    return uniqueMentions.toList();
  }

  /// Sends a real-time Firestore notification to all mentioned users.
  static Future<void> sendMentionNotifications({
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String textContent,
    required String targetType, // 'post' | 'clip' | 'comment'
    required String targetId, // Post ID or Comment ID
    required List<MentionModel> mentions,
  }) async {
    final actor = NotificationActor(
      id: senderId,
      name: senderName,
      avatar: senderAvatar,
    );

    // Clean up text preview length.
    final previewText = textContent.length > 60
        ? '${textContent.substring(0, 57)}...'
        : textContent;

    for (final mention in mentions) {
      // Avoid notifying yourself.
      if (mention.uid == senderId || mention.uid.isEmpty) continue;

      // Route through the central pipeline (honours the receiver's `mentions`
      // preference, de-duplicates per surface, denormalises the deep link).
      await NotificationService.instance.create(
        receiverId: mention.uid,
        type: NotificationType.mention,
        actor: actor,
        body: 'mentioned you in a $targetType: "$previewText"',
        relatedObjectId: targetId,
        dedupeKey: 'mention_${targetType}_${targetId}_${senderId}_${mention.uid}',
      );

      debugPrint('Sent mention notification to user ${mention.uid} '
          '(username: ${mention.username})');
    }
  }
}
