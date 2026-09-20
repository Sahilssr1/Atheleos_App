import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import providers/repositories we'll need to sync
import '../../../features/feed/presentation/controllers/feed_controller.dart';
import '../../../features/feed/domain/models/comment_model.dart';
import '../../../features/profile/presentation/controllers/profile_controller.dart';
import 'network_service.dart';

class OfflineAction {
  final String id;
  final String actionType; // 'like' | 'bookmark' | 'comment' | 'follow'
  final String targetId; // postId, commentId, or userId
  final Map<String, dynamic> data;

  const OfflineAction({
    required this.id,
    required this.actionType,
    required this.targetId,
    required this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actionType': actionType,
      'targetId': targetId,
      'data': data,
    };
  }

  factory OfflineAction.fromMap(Map<String, dynamic> map) {
    return OfflineAction(
      id: map['id'] as String,
      actionType: map['actionType'] as String,
      targetId: map['targetId'] as String,
      data: Map<String, dynamic>.from(map['data'] as Map),
    );
  }
}

class OfflineSyncNotifier extends StateNotifier<List<OfflineAction>> {
  static const String _queueKey = 'offline_sync_action_queue';
  final Ref _ref;

  OfflineSyncNotifier(this._ref) : super([]) {
    _loadQueue();
    // Listen to network changes to trigger sync
    _ref.listen<NetworkStatus>(networkServiceProvider, (previous, next) {
      if (next.isOnline && !(previous?.isOnline ?? false)) {
        // Just returned online! Sync queue.
        syncPendingActions();
      }
    });
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList(_queueKey) ?? [];
      state = data.map((jsonStr) => OfflineAction.fromMap(json.decode(jsonStr))).toList();
    } catch (_) {}
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = state.map((action) => json.encode(action.toMap())).toList();
      await prefs.setStringList(_queueKey, list);
    } catch (_) {}
  }

  /// Add action to offline queue
  Future<void> queueAction({
    required String actionType,
    required String targetId,
    required Map<String, dynamic> data,
  }) async {
    final action = OfflineAction(
      id: '${actionType}_${targetId}_${DateTime.now().millisecondsSinceEpoch}',
      actionType: actionType,
      targetId: targetId,
      data: data,
    );
    // Add to list and persist
    state = [...state, action];
    await _saveQueue();
  }

  bool _isSyncing = false;

  /// Process all pending sync actions sequentially with re-entrancy protection
  Future<void> syncPendingActions() async {
    if (_isSyncing || state.isEmpty) return;
    _isSyncing = true;

    try {
      final actions = List<OfflineAction>.from(state);
      state = [];
      await _saveQueue();

      debugPrint('OfflineSync: Syncing ${actions.length} pending actions...');

      for (final action in actions) {
        try {
          switch (action.actionType) {
            case 'like':
              final userId = action.data['userId'] as String;
              await _ref.read(postRepositoryProvider).togglePostLike(action.targetId, userId);
              break;
            case 'bookmark':
              final userId = action.data['userId'] as String;
              await _ref.read(postRepositoryProvider).togglePostBookmark(action.targetId, userId);
              break;
            case 'comment':
              final commentMap = action.data['comment'] as Map<String, dynamic>;
              final comment = CommentModel.fromMap(commentMap, commentMap['commentId'] as String);
              await _ref.read(commentRepositoryProvider).addComment(comment);
              break;
            case 'follow':
              final isFollowing = action.data['isFollowing'] as bool;
              // update follow in remote database via delegate
              final userRepo = _ref.read(userRepositoryProvider);
              await userRepo.updateFollowState(action.targetId, isFollowing);
              break;
          }
        } catch (e) {
          debugPrint('OfflineSync: Action ${action.id} failed to sync: $e');
        }
      }

      // Refresh feed and profiles silent check
      _ref.invalidate(feedPostsProvider);
    } finally {
      _isSyncing = false;
    }
  }
}

final offlineSyncProvider = StateNotifierProvider<OfflineSyncNotifier, List<OfflineAction>>((ref) {
  return OfflineSyncNotifier(ref);
});
