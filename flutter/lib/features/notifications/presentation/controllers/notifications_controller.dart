import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../data/notification_repository.dart';
import '../../data/notification_service.dart';
import '../../domain/models/notification_model.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

/// Builds the [NotificationActor] for the currently logged-in user. Used by
/// every producer (likes, comments, follows…) so the sender identity is
/// resolved in exactly one place.
NotificationActor notificationActorOf(Ref ref) {
  final uid = ref.read(loggedInUserIdProvider);
  final profile = ref.read(currentUserProvider).valueOrNull;
  return NotificationActor(
    id: uid,
    name: profile?.name ?? 'Someone',
    avatar: profile?.avatarUrl ?? '',
  );
}

/// The active filter chip in the Notification Center.
final notificationFilterProvider =
    StateProvider<NotificationCategory>((ref) => NotificationCategory.all);

/// Live unread count for the app-bar badge (aggregation query — cheap).
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(loggedInUserIdProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchUnreadCount(uid);
});

/// Immutable UI state for the paginated notification list.
class NotificationsState {
  final List<AppNotification> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const NotificationsState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Merges a real-time first page with lazily-loaded older pages so the top of
/// the list stays live while history is paginated on demand.
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repo, this._uid, this._category)
      : super(const NotificationsState()) {
    _listen();
  }

  final NotificationRepository _repo;
  final String _uid;
  final NotificationCategory _category;

  StreamSubscription<List<AppNotification>>? _sub;

  // Newest page delivered in real time.
  List<AppNotification> _firstPage = const [];
  // Older pages fetched via the cursor.
  final List<AppNotification> _older = [];

  void _listen() {
    if (_uid.isEmpty) {
      state = state.copyWith(isLoading: false, hasMore: false, items: const []);
      return;
    }
    _sub = _repo.watchFirstPage(_uid, _category).listen(
      (page) {
        _firstPage = page;
        state = state.copyWith(
          items: _merged(),
          isLoading: false,
          clearError: true,
          hasMore: _firstPage.length >= NotificationRepository.pageSize
              ? state.hasMore
              : (_older.isEmpty ? false : state.hasMore),
        );
      },
      onError: (err) {
        state = state.copyWith(isLoading: false, error: err);
      },
    );
  }

  List<AppNotification> _merged() {
    final seen = <String>{};
    final combined = <AppNotification>[];
    for (final n in [..._firstPage, ..._older]) {
      if (seen.add(n.id)) combined.add(n);
    }
    combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  Future<void> loadMore() async {
    if (_uid.isEmpty || state.isLoadingMore || !state.hasMore) return;
    final items = state.items;
    if (items.isEmpty) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final cursor = items.last.createdAt;
      final older = await _repo.fetchOlder(_uid, _category, cursor);
      _older.addAll(older);
      state = state.copyWith(
        items: _merged(),
        isLoadingMore: false,
        hasMore: older.length >= NotificationRepository.pageSize,
      );
    } catch (err) {
      state = state.copyWith(isLoadingMore: false, error: err);
    }
  }

  Future<void> markAsRead(String id) async {
    if (_uid.isEmpty) return;
    state = state.copyWith(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(read: true) : n)
          .toList(),
    );
    // Keep older-page cache consistent with the optimistic change.
    for (var i = 0; i < _older.length; i++) {
      if (_older[i].id == id) _older[i] = _older[i].copyWith(read: true);
    }
    await _repo.markAsRead(_uid, id);
  }

  Future<void> markAllAsRead() async {
    if (_uid.isEmpty) return;
    state = state.copyWith(
      items: state.items.map((n) => n.copyWith(read: true)).toList(),
    );
    for (var i = 0; i < _older.length; i++) {
      _older[i] = _older[i].copyWith(read: true);
    }
    await _repo.markAllAsRead(_uid);
  }

  Future<void> delete(String id) async {
    _older.removeWhere((n) => n.id == id);
    state = state.copyWith(
      items: state.items.where((n) => n.id != id).toList(),
    );
    await _repo.delete(_uid, id);
  }

  Future<void> clearAll() async {
    _older.clear();
    _firstPage = const [];
    state = state.copyWith(items: const [], hasMore: false);
    await _repo.clearAll(_uid);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Rebuilds automatically when the logged-in user or the active filter changes.
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  final uid = ref.watch(loggedInUserIdProvider);
  final category = ref.watch(notificationFilterProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  return NotificationsNotifier(repo, uid, category);
});
