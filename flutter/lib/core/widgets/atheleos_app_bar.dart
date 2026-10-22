import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/chat/presentation/controllers/chat_list_controller.dart';
import '../../features/notifications/presentation/controllers/notifications_controller.dart';
import '../../features/profile/presentation/controllers/profile_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

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
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final myId = ref.watch(loggedInUserIdProvider);
    final unreadMessages = showActions
        ? ref
            .watch(chatListProvider)
            .where((room) => room.unreadBy.contains(myId))
            .length
        : 0;

    return AppBar(
      backgroundColor: const Color(0xCC000000),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 56,
      centerTitle: false,
      titleSpacing: 16,
      leading: leading,
      iconTheme: const IconThemeData(color: Colors.white, size: 20),
      actionsIconTheme: const IconThemeData(color: Colors.white, size: 20),
      shape: const Border(
        bottom: BorderSide(color: Color(0x0FFFFFFF), width: 1),
      ),
      title: title ??
          (titleText == 'ATHELEOS'
              ? ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 24),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/images/atheleos_banner.png',
                      height: 24,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                )
              : Text(
                  titleText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.appBarTheme.titleTextStyle,
                )),
      actions: showActions
          ? [
              _TopBarAction(
                tooltip: 'Events & Combine',
                icon: AthIcons.calendar,
                onTap: () => context.push('/events'),
              ),
              const SizedBox(width: 6),
              _TopBarAction(
                tooltip: 'Alerts & Notifications',
                icon: AthIcons.bell,
                badgeCount: unreadNotifications,
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(width: 6),
              _TopBarAction(
                tooltip: 'Direct Messages',
                icon: AthIcons.chatRound,
                badgeCount: unreadMessages,
                onTap: () => context.push('/chat'),
              ),
              const SizedBox(width: 12),
            ]
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _TopBarAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  const _TopBarAction({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white, size: 21),
              if (badgeCount > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badgeCount > 9 ? '9+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
