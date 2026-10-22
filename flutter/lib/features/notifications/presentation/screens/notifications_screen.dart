import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/notification_model.dart';
import '../../domain/notification_navigation.dart';
import '../controllers/notifications_controller.dart';
import '../widgets/notification_tile.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  void _openNotification(AppNotification n) {
    if (!n.read) {
      ref.read(notificationsProvider.notifier).markAsRead(n.id);
    }
    final route = NotificationNavigation.forNotification(n);
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final filter = ref.watch(notificationFilterProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('NOTIFICATIONS',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1)),
        actions: [
          TextButton(
            onPressed: state.items.any((n) => !n.read)
                ? () => ref.read(notificationsProvider.notifier).markAllAsRead()
                : null,
            child: const Text('Mark all read',
                style: TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF1A1A1A),
            onSelected: (value) {
              if (value == 'clear') _confirmClearAll();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: Text('Clear all',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _FilterBar(
            selected: filter,
            onSelected: (c) =>
                ref.read(notificationFilterProvider.notifier).state = c,
          ),
        ),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _EmptyState(
        icon: AthIcons.exclamationCircle,
        message: 'Could not load notifications.\nPull down to retry.',
      );
    }
    if (state.items.isEmpty) {
      return _EmptyState(
        icon: AthIcons.bell,
        message: _emptyMessage(ref.read(notificationFilterProvider)),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        // The first page is a live stream; invalidating rebuilds the notifier.
        ref.invalidate(notificationsProvider);
      },
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: Colors.white.withOpacity(0.05)),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
              ),
            );
          }
          final n = state.items[index];
          return Dismissible(
            key: ValueKey(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.redAccent.withOpacity(0.85),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              child: const Icon(AthIcons.trash, color: Colors.white),
            ),
            onDismissed: (_) =>
                ref.read(notificationsProvider.notifier).delete(n.id),
            child: NotificationTile(
              notification: n,
              onTap: () => _openNotification(n),
              onAvatarTap: () {
                if (n.senderId.isNotEmpty && n.senderId != 'system') {
                  context.push('/profile/${n.senderId}');
                }
              },
            ),
          );
        },
      ),
    );
  }

  String _emptyMessage(NotificationCategory c) {
    if (c == NotificationCategory.all) return 'No notifications yet.';
    return 'No ${c.label.toLowerCase()} notifications yet.';
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Clear all notifications?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently removes every notification from your inbox.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationsProvider.notifier).clearAll();
    }
  }
}

class _FilterBar extends StatelessWidget {
  final NotificationCategory selected;
  final ValueChanged<NotificationCategory> onSelected;

  const _FilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: NotificationCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = NotificationCategory.values[index];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(category.label),
            selected: isSelected,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: isSelected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.white10,
            selectedColor: AppTheme.primaryColor,
            side: BorderSide.none,
            onSelected: (_) => onSelected(category),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
