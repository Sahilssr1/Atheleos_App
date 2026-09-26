import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/notifications/presentation/controllers/notifications_controller.dart';

class AtheleosAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String titleText;
  final Widget? title;
  final bool showActions;
  final Widget? leading;

  const AtheleosAppBar({
    super.key,
    this.titleText = 'ATHELEOS',
    this.title,
    this.showActions = true,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return AppBar(
      backgroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 16,
      leading: leading,
      title: title ??
          (titleText == 'ATHELEOS'
              ? Image.asset(
                  'assets/images/atheleos_banner.png',
                  height: 32,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                )
              : Text(
                  titleText,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                )),
      actions: showActions
          ? [
              // Events Combine Button (Calendar outline icon)
              IconButton(
                tooltip: 'Events & Combine',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () {
                  context.push('/events');
                },
              ),
              // Notifications Alerts Button with live unread badge
              IconButton(
                tooltip: 'Alerts & Notifications',
                icon: _NotificationBell(count: unreadCount),
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

class _NotificationBell extends StatelessWidget {
  final int count;
  const _NotificationBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(count > 0
            ? Icons.notifications
            : Icons.notifications_none_outlined),
        if (count > 0)
          Positioned(
            right: -5,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
