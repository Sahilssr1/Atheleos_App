import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/notification_model.dart';

/// A single Instagram-style notification row: sender avatar with a small
/// type-badge, the message body, relative time, an optional media thumbnail and
/// an unread indicator.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.read;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _avatar(),
            const SizedBox(width: 14),
            Expanded(child: _body(context)),
            const SizedBox(width: 10),
            _trailing(),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final hasAvatar = notification.senderAvatar.isNotEmpty;
    return GestureDetector(
      onTap: onAvatarTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white10,
              backgroundImage:
                  hasAvatar ? CachedNetworkImageProvider(notification.senderAvatar) : null,
              child: hasAvatar
                  ? null
                  : const Icon(Icons.person, color: Colors.white38, size: 24),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _badge.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
                child: Icon(_badge.icon, size: 11, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final n = notification;
    final showSender = n.senderId != 'system' && n.senderName.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13.5, height: 1.35, color: Colors.white),
            children: [
              if (showSender)
                TextSpan(
                  text: '${n.senderName} ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              TextSpan(
                text: n.body,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          n.relativeTime,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
        ),
      ],
    );
  }

  Widget _trailing() {
    final thumb = notification.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: thumb,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(width: 44, height: 44, color: Colors.white10),
          errorWidget: (_, __, ___) =>
              Container(width: 44, height: 44, color: Colors.white10),
        ),
      );
    }
    if (!notification.read) {
      return Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
      );
    }
    return const SizedBox(width: 9);
  }

  _Badge get _badge => _badgeFor(notification.type);

  static _Badge _badgeFor(NotificationType type) {
    switch (type.category) {
      case NotificationCategory.social:
        if (type == NotificationType.follow ||
            type == NotificationType.followRequest ||
            type == NotificationType.followAccept) {
          return const _Badge(Icons.person_add, Color(0xFF3897F0));
        }
        if (type == NotificationType.postComment ||
            type == NotificationType.reelComment ||
            type == NotificationType.commentReply) {
          return const _Badge(Icons.mode_comment, Color(0xFF5C6BC0));
        }
        if (type == NotificationType.mention) {
          return const _Badge(Icons.alternate_email, Color(0xFF26A69A));
        }
        return const _Badge(Icons.favorite, Color(0xFFED4956));
      case NotificationCategory.stories:
        return const _Badge(Icons.auto_stories, Color(0xFFAB47BC));
      case NotificationCategory.messages:
        return const _Badge(Icons.chat_bubble, Color(0xFF29B6F6));
      case NotificationCategory.verification:
        return const _Badge(Icons.verified, Color(0xFF42A5F5));
      case NotificationCategory.events:
        return const _Badge(Icons.emoji_events, Color(0xFFFFB300));
      case NotificationCategory.coaches:
        return const _Badge(Icons.sports, Color(0xFF66BB6A));
      case NotificationCategory.federations:
        return const _Badge(Icons.campaign, Color(0xFFFF7043));
      case NotificationCategory.collaborations:
        return const _Badge(Icons.handshake, Color(0xFF8D6E63));
      case NotificationCategory.system:
        return const _Badge(Icons.info, Color(0xFF78909C));
      case NotificationCategory.all:
        return const _Badge(Icons.notifications, Color(0xFF78909C));
    }
  }
}

class _Badge {
  final IconData icon;
  final Color color;
  const _Badge(this.icon, this.color);
}
