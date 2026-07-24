import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class AtheleosAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final bool showActions;

  const AtheleosAppBar({
    super.key,
    this.titleText = 'ATHELEOS',
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      title: Text(
        titleText,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
      actions: showActions
          ? [
              // Events Combine Button
              IconButton(
                tooltip: 'Combine & Events',
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: () {
                  context.push('/events');
                },
              ),
              // Notifications Alerts Button
              IconButton(
                tooltip: 'Alerts & Notifications',
                icon: const Icon(Icons.notifications_none_outlined),
                onPressed: () {
                  context.push('/notifications');
                },
              ),
              // Chat Message Button
              IconButton(
                tooltip: 'Direct Messages',
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: () {
                  context.push('/chat');
                },
              ),
              const SizedBox(width: 8),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
