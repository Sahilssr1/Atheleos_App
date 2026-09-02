import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../../domain/repositories/clip_repository.dart';
import '../../data/repositories/clip_repository_impl.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../feed/presentation/controllers/like_controller.dart';

final clipRepositoryProvider = Provider<ClipRepository>((ref) {
  return ClipRepositoryImpl();
});

final selectedClipSportProvider = StateProvider<String>((ref) => 'All');

class ClipsNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  final ClipRepository _repository;
  final String _userId;
  final String _sport;
  final Set<String> _likedIds;
  final Set<String> _bookmarkedIds;
  final Ref _ref;

  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  ClipsNotifier(
    this._repository,
    this._userId,
    this._sport,
    this._likedIds,
    this._bookmarkedIds,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    try {
      final clips = await _repository.getClipsPaginated(
        sport: _sport,
        limit: 8,
        currentUserId: _userId,
      );

      final mapped = clips.map((clip) {
        return clip.copyWith(
          hasLiked: _likedIds.contains(clip.id) || clip.hasLiked,
          hasBookmarked: _bookmarkedIds.contains(clip.id) || clip.hasBookmarked,
        );
      }).toList();

      state = AsyncValue.data(mapped);
      _ref.read(sharedLikeStateProvider.notifier).registerPosts(mapped);
      _hasMore = clips.length >= 8;
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> refresh() async {
    _hasMore = true;
    _isLoadingMore = false;
    await _loadFirstPage();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;

    final currentClips = state.valueOrNull ?? [];
    if (currentClips.isEmpty) {
      _isLoadingMore = false;
      return;
    }

    final lastClipId = currentClips.last.id;

    try {
      final clips = await _repository.getClipsPaginated(
        sport: _sport,
        limit: 8,
        lastClipId: lastClipId,
        currentUserId: _userId,
      );

      if (clips.isEmpty) {
        _hasMore = false;
        _isLoadingMore = false;
        return;
      }

      final mapped = clips.map((clip) {
        return clip.copyWith(
          hasLiked: _likedIds.contains(clip.id) || clip.hasLiked,
          hasBookmarked: _bookmarkedIds.contains(clip.id) || clip.hasBookmarked,
        );
      }).toList();

      // Guard against duplicates (e.g. when the pagination cursor was deleted)
      final existingIds = currentClips.map((c) => c.id).toSet();
      final newClips = mapped.where((c) => !existingIds.contains(c.id)).toList();

      state = AsyncValue.data([...currentClips, ...newClips]);
      _ref.read(sharedLikeStateProvider.notifier).registerPosts(newClips);
      _hasMore = clips.length >= 8;
    } catch (err) {
      debugPrint('Error loading more clips: $err');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Removes a clip from the in-memory state (used after deletion).
  void removePost(String clipId) {
    final currentClips = state.valueOrNull;
    if (currentClips == null) return;
    final updated = currentClips.where((c) => c.id != clipId).toList();
    if (updated.length == currentClips.length) return;
    state = AsyncValue.data(updated);
  }

  void updateLikedIds(Set<String> likedIds) {
    _likedIds.clear();
    _likedIds.addAll(likedIds);
    if (state is AsyncData<List<PostModel>>) {
      final clips = state.asData!.value;
      final updated = clips.map((c) => c.copyWith(hasLiked: likedIds.contains(c.id))).toList();
      state = AsyncValue.data(updated);
    }
  }

  void updateBookmarkedIds(Set<String> bookmarkedIds) {
    _bookmarkedIds.clear();
    _bookmarkedIds.addAll(bookmarkedIds);
    if (state is AsyncData<List<PostModel>>) {
      final clips = state.asData!.value;
      final updated = clips.map((c) => c.copyWith(hasBookmarked: bookmarkedIds.contains(c.id))).toList();
      state = AsyncValue.data(updated);
    }
  }

  Future<void> toggleLike(String clipId, bool currentlyLiked) async {
    PostModel? clip;
    if (state is AsyncData<List<PostModel>>) {
      final clips = state.asData!.value;
      for (final c in clips) {
        if (c.id == clipId) {
          clip = c;
          break;
        }
      }
    }
    if (clip != null) {
      await _ref.read(sharedLikeStateProvider.notifier).toggleLike(clip);
    }
  }

  Future<void> toggleBookmark(String clipId, bool currentlyBookmarked) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (_userId.isNotEmpty ? _userId : 'user_1');

    if (currentlyBookmarked) {
      _bookmarkedIds.remove(clipId);
      CacheManager().removeBookmarkedPostId(effectiveUserId, clipId);
    } else {
      _bookmarkedIds.add(clipId);
      CacheManager().addBookmarkedPostId(effectiveUserId, clipId);
    }

    // Optimistic UI update
    if (state is AsyncData<List<PostModel>>) {
      final clips = state.asData!.value;
      final updated = clips.map((c) {
        if (c.id == clipId) {
          final newBookmarks = currentlyBookmarked ? (c.bookmarks - 1).clamp(0, 9999999) : c.bookmarks + 1;
          return c.copyWith(hasBookmarked: !currentlyBookmarked, bookmarks: newBookmarks);
        }
        return c;
      }).toList();
      state = AsyncValue.data(updated);
      
      final clip = clips.firstWhere((c) => c.id == clipId);
      await _ref.read(bookmarkRepositoryProvider).toggleBookmark(effectiveUserId, clip);
    }
  }

  Future<void> incrementShare(String clipId) async {
    await _ref.read(postRepositoryProvider).incrementShareCount(clipId);
  }

  Future<void> incrementView(String clipId) async {
    await _ref.read(postRepositoryProvider).incrementViewCount(clipId);
  }

  Future<void> uploadClip(PostModel clip) async {
    await _repository.createClip(clip);
  }
}

final clipsProvider = StateNotifierProvider<ClipsNotifier, AsyncValue<List<PostModel>>>((ref) {
  final repository = ref.watch(clipRepositoryProvider);
  final userId = ref.watch(loggedInUserIdProvider);
  final sport = ref.watch(selectedClipSportProvider);

  // Read initial cached values synchronously to avoid cold-start flicker
  final cachedLiked = CacheManager().loadLikedPostIds(userId);
  final cachedBookmarked = CacheManager().loadBookmarkedPostIds(userId);
  final likedIds = ref.read(userLikesIdsProvider).valueOrNull ?? cachedLiked;
  final bookmarkedIds = ref.read(userBookmarksIdsProvider).valueOrNull ?? cachedBookmarked;

  final notifier = ClipsNotifier(repository, userId, sport, likedIds, bookmarkedIds, ref);

  // Manually listen to remote syncs to update UI without resetting pagination
  ref.listen(userLikesIdsProvider, (prev, next) {
    if (next.hasValue) notifier.updateLikedIds(next.value!);
  });
  
  ref.listen(userBookmarksIdsProvider, (prev, next) {
    if (next.hasValue) notifier.updateBookmarkedIds(next.value!);
  });

  return notifier;
});

// User's clips provider — shows all user posts that contain video media
final userClipsProvider = StreamProvider.family<List<PostModel>, String>((ref, userId) {
  if (userId.isEmpty) return Stream.value([]);
  final loggedInUserId = ref.watch(loggedInUserIdProvider);
  final cachedLiked = CacheManager().loadLikedPostIds(loggedInUserId);
  final cachedBookmarked = CacheManager().loadBookmarkedPostIds(loggedInUserId);
  final likedIds = ref.watch(userLikesIdsProvider).valueOrNull ?? cachedLiked;
  final bookmarkedIds = ref.watch(userBookmarksIdsProvider).valueOrNull ?? cachedBookmarked;

  return FirebaseFirestore.instance
      .collection('posts')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
        final list = snapshot.docs.map((doc) => PostModel.fromMap({...doc.data(), 'id': doc.id}, currentUserId: loggedInUserId)).toList();
        // Filter for video content only (Instagram Reels behavior)
        final videoOnly = list.where((post) => post.hasVideo).toList();
        videoOnly.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return videoOnly.map((clip) {
          return clip.copyWith(
            hasLiked: likedIds.contains(clip.id) || clip.hasLiked,
            hasBookmarked: bookmarkedIds.contains(clip.id) || clip.hasBookmarked,
          );
        }).toList();
      });
});
