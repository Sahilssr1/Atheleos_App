import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/repositories/like_repository.dart';
import '../../data/repositories/like_repository_impl.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../domain/models/post_model.dart';
import 'feed_controller.dart' show userLikesIdsProvider, likeRepositoryProvider;

/// Unified Like State for an individual post/clip.
class PostLikeState {
  final bool isLiked;
  final int likesCount;
  final bool isPending;

  const PostLikeState({
    required this.isLiked,
    required this.likesCount,
    this.isPending = false,
  });

  PostLikeState copyWith({
    bool? isLiked,
    int? likesCount,
    bool? isPending,
  }) {
    return PostLikeState(
      isLiked: isLiked ?? this.isLiked,
      likesCount: likesCount ?? this.likesCount,
      isPending: isPending ?? this.isPending,
    );
  }

  @override
  String toString() => 'PostLikeState(isLiked: $isLiked, likesCount: $likesCount, isPending: $isPending)';
}

/// Central Shared Like State Notifier.
///
/// ONE SOURCE OF TRUTH across Feed, Reels, Profile, Search, and Details.
class SharedLikeNotifier extends StateNotifier<Map<String, PostLikeState>> {
  final LikeRepository _likeRepo;
  final Ref _ref;

  // Active optimistic likes/unlikes tracking sets to resolve stream race condition
  final Set<String> _optimisticLikes = {};
  final Set<String> _optimisticUnlikes = {};

  SharedLikeNotifier(this._likeRepo, this._ref) : super({});

  /// Register or hydrate a post's known initial state.
  void registerPost(PostModel post) {
    final userId = _ref.read(loggedInUserIdProvider);
    final cachedLikedIds = CacheManager().loadLikedPostIds(userId);
    final isLiked = cachedLikedIds.contains(post.id) || post.hasLiked;
    final current = state[post.id];

    if (current == null) {
      debugPrint('[LIKE DEBUG] Registered post ${post.id}: isLiked=$isLiked, likesCount=${post.likes}, source=Cache/Initial');
      state = {
        ...state,
        post.id: PostLikeState(
          isLiked: isLiked,
          likesCount: post.likes,
        ),
      };
    } else if (!current.isPending) {
      state = {
        ...state,
        post.id: current.copyWith(
          isLiked: isLiked,
          likesCount: post.likes,
        ),
      };
    }
  }

  /// Bulk register posts when feed/reels/profile loads a page/batch.
  void registerPosts(List<PostModel> posts) {
    if (posts.isEmpty) return;
    final userId = _ref.read(loggedInUserIdProvider);
    final cachedLikedIds = CacheManager().loadLikedPostIds(userId);
    final newState = Map<String, PostLikeState>.from(state);

    for (final post in posts) {
      final current = newState[post.id];
      final isLiked = cachedLikedIds.contains(post.id) || post.hasLiked;

      if (current == null) {
        newState[post.id] = PostLikeState(
          isLiked: isLiked,
          likesCount: post.likes,
        );
      } else if (!current.isPending) {
        newState[post.id] = current.copyWith(
          isLiked: isLiked,
          likesCount: post.likes,
        );
      }
    }
    state = newState;
  }

  /// Synchronize tracked posts when remote user likes stream updates from Firestore.
  /// Resolves server state with active local optimistic modifications to prevent latency reverting.
  void syncUserLikedIds(Set<String> userLikedIds) {
    // 1. Clean up optimistic tracking sets when the stream emits the matching server state
    _optimisticLikes.removeWhere((id) => userLikedIds.contains(id));
    _optimisticUnlikes.removeWhere((id) => !userLikedIds.contains(id));

    // Resolve Firestore server stream updates with current active optimistic operations
    final resolvedIds = Set<String>.from(userLikedIds)
      ..addAll(_optimisticLikes)
      ..removeAll(_optimisticUnlikes);

    // Save resolved IDs to cache to ensure cache doesn't get overwritten with stale stream data
    final userId = _ref.read(loggedInUserIdProvider);
    if (userId.isNotEmpty) {
      CacheManager().saveLikedPostIds(userId, resolvedIds);
    }

    final newState = Map<String, PostLikeState>.from(state);
    bool changed = false;

    // Sync any registered post whose state differs from the resolved state
    for (final entry in state.entries) {
      final postId = entry.key;
      final currentState = entry.value;
      final serverLiked = resolvedIds.contains(postId);

      if (currentState.isLiked != serverLiked && !currentState.isPending) {
        final diff = serverLiked ? 1 : -1;
        final newCount = (currentState.likesCount + diff).clamp(0, 9999999);
        newState[postId] = currentState.copyWith(
          isLiked: serverLiked,
          likesCount: newCount,
        );
        changed = true;
        debugPrint('[LIKE DEBUG] Synced post $postId from Firestore stream: isLiked=$serverLiked, likesCount=$newCount');
      }
    }

    if (changed) {
      state = newState;
    }
  }

  /// The ONE and ONLY toggle like operation across the entire application.
  Future<void> toggleLike(PostModel post, {bool? forceLike}) async {
    final postId = post.id;
    final currentState = state[postId] ?? PostLikeState(
      isLiked: post.hasLiked,
      likesCount: post.likes,
    );

    // If forceLike is true (e.g. from double tap) and already liked, do not flip back to false
    if (forceLike == true && currentState.isLiked) {
      debugPrint('[LIKE DEBUG] Post $postId already liked; forceLike ignored');
      return;
    }

    final bool targetLiked = forceLike ?? !currentState.isLiked;
    final int previousCount = currentState.likesCount;
    final int targetCount = targetLiked
        ? (currentState.isLiked ? previousCount : previousCount + 1)
        : (currentState.isLiked ? (previousCount - 1).clamp(0, 9999999) : previousCount);

    String? authUid;
    try {
      authUid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {}
    final userId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : _ref.read(loggedInUserIdProvider);

    debugPrint('''
[LIKE DEBUG]
========================================
userId: $userId
postId: $postId
likeDocument: posts/$postId/likes/$userId
isLikedByCurrentUser before update: ${currentState.isLiked}
isLikedByCurrentUser after update: $targetLiked
likeCount before update: $previousCount
likeCount after update: $targetCount
source: Optimistic UI
========================================''');

    // Add to our optimistic tracking sets
    if (targetLiked) {
      _optimisticLikes.add(postId);
      _optimisticUnlikes.remove(postId);
    } else {
      _optimisticUnlikes.add(postId);
      _optimisticLikes.remove(postId);
    }

    // 1. INSTANT OPTIMISTIC UI UPDATE
    state = {
      ...state,
      postId: PostLikeState(
        isLiked: targetLiked,
        likesCount: targetCount,
        isPending: true,
      ),
    };

    // Update persistent local disk cache
    if (targetLiked) {
      CacheManager().addLikedPostId(userId, postId);
    } else {
      CacheManager().removeLikedPostId(userId, postId);
    }

    // 2. CHECK CONNECTIVITY & QUEUE IF OFFLINE
    final isOnline = _ref.read(networkServiceProvider).isOnline;
    if (!isOnline) {
      debugPrint('[LIKE DEBUG] Network offline: queued like action for postId $postId');
      state = {
        ...state,
        postId: state[postId]!.copyWith(isPending: false),
      };
      if (targetLiked) {
        _optimisticLikes.remove(postId);
      } else {
        _optimisticUnlikes.remove(postId);
      }
      await _ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'like',
        targetId: postId,
        data: {'userId': userId, 'isLiked': targetLiked},
      );
      return;
    }

    // Safety fallback: Clear optimistic tracking after 5 seconds to prevent locks if stream fails
    Timer(const Duration(seconds: 5), () {
      if (mounted) {
        bool changed = false;
        if (_optimisticLikes.contains(postId)) {
          _optimisticLikes.remove(postId);
          changed = true;
        }
        if (_optimisticUnlikes.contains(postId)) {
          _optimisticUnlikes.remove(postId);
          changed = true;
        }
        if (changed) {
          final latestUserLikes = _ref.read(userLikesIdsProvider).valueOrNull ?? {};
          syncUserLikedIds(latestUserLikes);
        }
      }
    });

    // 3. FIRESTORE ATOMIC TRANSACTION
    try {
      await _likeRepo.togglePostLike(postId, userId, targetLiked: targetLiked);

      state = {
        ...state,
        postId: state[postId]!.copyWith(isPending: false),
      };

      debugPrint('[LIKE DEBUG] Firestore confirmed like state for $postId -> isLiked=$targetLiked, count=$targetCount');

      // Send notification only when liking (non-blocking)
      if (targetLiked) {
        try {
          final media = post.media.isNotEmpty ? post.media.first : null;
          unawaited(NotificationService.instance.like(
            receiverId: post.userId,
            actor: notificationActorOf(_ref),
            contentId: post.id,
            isReel: post.hasVideo,
            thumbnailUrl: media?.thumbnailUrl ?? media?.mediaUrl,
          ));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[LIKE DEBUG] FAILURE toggling like for $postId: $e. Rolling back!');

      // Clean up optimistic tracking sets on failure
      if (targetLiked) {
        _optimisticLikes.remove(postId);
      } else {
        _optimisticUnlikes.remove(postId);
      }

      // 4. ROLLBACK ON FAILURE
      state = {
        ...state,
        postId: PostLikeState(
          isLiked: currentState.isLiked,
          likesCount: previousCount,
          isPending: false,
        ),
      };

      if (currentState.isLiked) {
        CacheManager().addLikedPostId(userId, postId);
      } else {
        CacheManager().removeLikedPostId(userId, postId);
      }
    }
  }
}

/// Global provider for the shared like state map.
final sharedLikeStateProvider = StateNotifierProvider<SharedLikeNotifier, Map<String, PostLikeState>>((ref) {
  final likeRepo = ref.watch(likeRepositoryProvider);
  final notifier = SharedLikeNotifier(likeRepo, ref);

  // Listen to remote Firestore likes stream to keep all tracked posts in real-time sync
  ref.listen<AsyncValue<Set<String>>>(userLikesIdsProvider, (prev, next) {
    if (next.hasValue) {
      notifier.syncUserLikedIds(next.value!);
    }
  });

  return notifier;
});

/// Individual Post Like Selector Provider.
///
/// Any widget (Feed, Reels, Profile, Details, Search) watching this provider
/// receives instant reactive updates when the post is liked anywhere in the app.
final postLikeProvider = Provider.family<PostLikeState, PostModel>((ref, post) {
  final sharedState = ref.watch(sharedLikeStateProvider);
  final postState = sharedState[post.id];
  if (postState != null) {
    return postState;
  }

  // Not yet registered: initialize from disk cache / post model and register
  final userId = ref.watch(loggedInUserIdProvider);
  final cachedLikedIds = CacheManager().loadLikedPostIds(userId);
  final isLiked = cachedLikedIds.contains(post.id) || post.hasLiked;

  Future.microtask(() {
    ref.read(sharedLikeStateProvider.notifier).registerPost(post);
  });

  return PostLikeState(
    isLiked: isLiked,
    likesCount: post.likes,
  );
});
