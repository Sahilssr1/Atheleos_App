import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/models/post_model.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/story_model.dart';
import '../../domain/repositories/post_repository.dart';
import '../../domain/repositories/comment_repository.dart';
import '../../domain/repositories/like_repository.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../../data/repositories/post_repository_impl.dart';
import '../../data/repositories/comment_repository_impl.dart';
import '../../data/repositories/like_repository_impl.dart';
import '../../data/repositories/bookmark_repository_impl.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../core/widgets/post_media_widget.dart' show preloadedVideoUrlProvider;
import '../../domain/repositories/story_repository.dart';
import '../../data/repositories/story_repository_impl.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/presentation/controllers/notifications_controller.dart';

// Provide instances of modular repositories
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepositoryImpl();
});

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepositoryImpl();
});

final likeRepositoryProvider = Provider<LikeRepository>((ref) {
  return LikeRepositoryImpl();
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepositoryImpl();
});

// Category & Sport & Sort filters state
final selectedCategoryProvider = StateProvider<String>((ref) => 'All');
final selectedSportProvider = StateProvider<String>((ref) => 'All');
final feedSortProvider = StateProvider<String>((ref) => 'Latest'); // Latest | Trending

// Streams of user likes & bookmarks sets
final userLikesIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  if (userId.isEmpty) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('likes')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
});

final userBookmarksIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  if (userId.isEmpty) return Stream.value({});
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('bookmarks')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
});

// Feed posts provider that listens to Firestore streams in real-time
final feedPostsProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<PostModel>>>((ref) {
  final repository = ref.watch(postRepositoryProvider);
  final category = ref.watch(selectedCategoryProvider);
  final sport = ref.watch(selectedSportProvider);
  final sortBy = ref.watch(feedSortProvider);
  final userId = ref.watch(loggedInUserIdProvider);

  // Read initial values instead of watching, to prevent full reload on changes
  final likedIds = ref.read(userLikesIdsProvider).valueOrNull ?? {};
  final bookmarkedIds = ref.read(userBookmarksIdsProvider).valueOrNull ?? {};

  final notifier = FeedNotifier(repository, category, sport, sortBy, userId, likedIds, bookmarkedIds, ref);

  // Manually listen to remote syncs to update UI without resetting pagination
  ref.listen(userLikesIdsProvider, (prev, next) {
    if (next.hasValue) notifier.updateLikedIds(next.value!);
  });
  
  ref.listen(userBookmarksIdsProvider, (prev, next) {
    if (next.hasValue) notifier.updateBookmarkedIds(next.value!);
  });

  return notifier;
});

class FeedNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  final PostRepository _repository;
  final String _category;
  final String _sport;
  final String _sortBy;
  final String _userId;
  final Set<String> _likedIds;
  final Set<String> _bookmarkedIds;
  final Ref _ref;

  bool _isLoadingMore = false;
  bool _hasMore = true;

  /// Highest post index for which we have already scheduled prefetching.
  /// Guards against `prefetchMediaForIndex` being called from
  /// `SliverChildBuilderDelegate.itemBuilder` (which fires on every scroll
  /// frame) re-triggering downloads for the same posts over and over.
  int _lastPrefetchedIndex = -1;

  /// URL of the post whose video we've told `preloadedVideoUrlProvider` to
  /// keep hot. Tracked so we only push a new value when it actually changes.
  String? _lastPreloadedVideoUrl;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  FeedNotifier(
    this._repository,
    this._category,
    this._sport,
    this._sortBy,
    this._userId,
    this._likedIds,
    this._bookmarkedIds,
    this._ref,
  ) : super(const AsyncValue.loading()) {
    _loadFromCache();
    _loadFirstPage();
  }

  /// Load cached feed immediately before hitting network
  void _loadFromCache() {
    try {
      final cacheManager = CacheManager();
      final cachedJson = cacheManager.loadFeed();
      if (cachedJson.isNotEmpty) {
        final List<PostModel> cachedPosts = cachedJson.map((map) {
          final mapped = PostModel.fromMap(map);
          return mapped.copyWith(
            hasLiked: _likedIds.contains(mapped.id),
            hasBookmarked: _bookmarkedIds.contains(mapped.id),
          );
        }).toList();
        state = AsyncValue.data(cachedPosts);
      }
    } catch (_) {}
  }

  Future<void> _loadFirstPage() async {
    try {
      final posts = await _repository.getPostsFilteredPaginated(
        category: _category,
        sport: _sport,
        sortBy: _sortBy,
        limit: 8,
        currentUserId: _userId,
      );

      final mapped = posts.map((post) {
        return post.copyWith(
          hasLiked: _likedIds.contains(post.id),
          hasBookmarked: _bookmarkedIds.contains(post.id),
        );
      }).toList();

      // Warm the media for the first visible batch BEFORE publishing so the
      // user sees images/videos already loaded on first render (Instagram
      // feel) instead of shimmer placeholders that pop into content.
      await _warmInitialBatch(mapped);

      state = AsyncValue.data(mapped);
      _hasMore = posts.length >= 8;
      _lastPrefetchedIndex = -1;

      // Ask any active feed video widget to hot-preload the very first
      // video in the batch so autoplay is instant when the user scrolls to
      // it.
      _updatePreloadedVideoForIndex(0, mapped);

      // Update local disk cache
      try {
        final cacheManager = CacheManager();
        cacheManager.saveFeed(mapped.map((p) => p.toMap()).toList());
      } catch (_) {}
    } catch (err, stack) {
      if (state is! AsyncData<List<PostModel>> || state.asData!.value.isEmpty) {
        state = AsyncValue.error(err, stack);
      }
    }
  }

  /// Instagram-style batch warmup: precache the first N image thumbnails
  /// (using the shared image cache — CachedNetworkImage stores decoded
  /// bitmaps here) and disk-cache the first video file. Bounded and
  /// non-fatal so a slow network never blocks the feed from appearing.
  Future<void> _warmInitialBatch(List<PostModel> posts) async {
    if (posts.isEmpty) return;
    const int warmupCount = 3;
    final int end = warmupCount.clamp(0, posts.length);

    final futures = <Future<void>>[];
    bool videoWarmed = false;
    for (int i = 0; i < end; i++) {
      final post = posts[i];
      for (final media in post.media) {
        if (media.mediaType == 'image') {
          futures.add(_precacheImageQuietly(media.mediaUrl));
        } else if (media.mediaType == 'video') {
          if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
            futures.add(_precacheImageQuietly(media.thumbnailUrl!));
          }
          // Only fully warm the FIRST video's file so we don't buffer
          // multiple videos at once when the feed first opens.
          if (!videoWarmed) {
            videoWarmed = true;
            unawaited(CacheManager().preloadVideo(media.mediaUrl));
          }
        }
      }
    }

    if (futures.isEmpty) return;
    // Race the batch against a hard 1.5s cap so the feed never sits blank
    // if some CDN request is slow.
    await Future.any([
      Future.wait(futures),
      Future<void>.delayed(const Duration(milliseconds: 1500)),
    ]);
  }

  Future<void> _precacheImageQuietly(String url) async {
    try {
      final provider = CachedNetworkImageProvider(url);
      await _resolveImage(provider);
    } catch (_) {}
  }

  Future<void> _resolveImage(ImageProvider provider) {
    final completer = Completer<void>();
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_, __) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      },
    );
    stream.addListener(listener);
    return completer.future;
  }

  Future<void> refresh() async {
    _hasMore = true;
    _isLoadingMore = false;
    _lastPrefetchedIndex = -1;
    _lastPreloadedVideoUrl = null;
    // Explicitly clear the global preload slot so the previously-preloaded
    // controller in `PostMediaWidget` is torn down.
    try {
      _ref.read(preloadedVideoUrlProvider.notifier).state = null;
    } catch (_) {}
    await _loadFirstPage();
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;

    final currentPosts = state.valueOrNull ?? [];
    if (currentPosts.isEmpty) {
      _isLoadingMore = false;
      return;
    }

    final lastPostId = currentPosts.last.id;

    try {
      final posts = await _repository.getPostsFilteredPaginated(
        category: _category,
        sport: _sport,
        sortBy: _sortBy,
        limit: 8,
        lastPostId: lastPostId,
        currentUserId: _userId,
      );

      if (posts.isEmpty) {
        _hasMore = false;
        _isLoadingMore = false;
        return;
      }

      final mapped = posts.map((post) {
        return post.copyWith(
          hasLiked: _likedIds.contains(post.id),
          hasBookmarked: _bookmarkedIds.contains(post.id),
        );
      }).toList();

      // Guard against duplicates (e.g. when the pagination cursor was deleted)
      final existingIds = currentPosts.map((p) => p.id).toSet();
      final newPosts = mapped.where((p) => !existingIds.contains(p.id)).toList();

      state = AsyncValue.data([...currentPosts, ...newPosts]);
      _hasMore = posts.length >= 8;
    } catch (err) {
      debugPrint('Error loading more posts: $err');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Removes a post from the in-memory feed state (used after deletion).
  void removePost(String postId) {
    final currentPosts = state.valueOrNull;
    if (currentPosts == null) return;
    final updated = currentPosts.where((p) => p.id != postId).toList();
    if (updated.length == currentPosts.length) return;
    state = AsyncValue.data(updated);

    // Keep local disk cache consistent
    try {
      CacheManager().saveFeed(updated.map((p) => p.toMap()).toList());
    } catch (_) {}
  }

  /// Instagram-style incremental prefetch.
  ///
  /// Called from the feed list's `itemBuilder`, which fires on EVERY visible
  /// scroll frame. This method must therefore be extremely cheap and MUST
  /// NOT re-launch downloads for posts it has already handled — otherwise a
  /// slow scroll spins up dozens of parallel HTTP requests and pins video
  /// bytes in memory.
  ///
  /// For each newly-seen index we:
  ///   1. Warm the image cache for the next few IMAGE thumbnails (cheap).
  ///   2. Ask [preloadedVideoUrlProvider] to hold ONE video controller hot
  ///      for the very next video the user is likely to encounter.
  ///   3. Kick off a de-duplicated on-disk cache of that single next video
  ///      via [CacheManager.preloadVideo] (streams to disk, capped
  ///      concurrency, no full-body buffering).
  void prefetchMediaForIndex(int currentIndex, List<PostModel> posts) {
    // Only advance the prefetch cursor forward — never re-prefetch on
    // upward scroll or on repeated builds of the same visible item.
    if (currentIndex <= _lastPrefetchedIndex) {
      // Still keep the preload target in sync while the user hovers on the
      // same visible batch (cheap: only updates provider on change).
      _updatePreloadedVideoForIndex(currentIndex, posts);
      return;
    }
    _lastPrefetchedIndex = currentIndex;

    final network = _ref.read(networkServiceProvider);
    if (network.speed == ConnectionSpeed.none) return; // offline

    // Fewer image precaches on slow networks so we don't hog bandwidth.
    final int imageAhead =
        network.speed == ConnectionSpeed.slow ? 1 : 3;

    final int start = currentIndex + 1;
    final int imageEnd = (currentIndex + imageAhead).clamp(0, posts.length - 1);

    for (int i = start; i <= imageEnd; i++) {
      final post = posts[i];
      for (final media in post.media) {
        if (media.mediaType == 'image') {
          unawaited(_precacheImageQuietly(media.mediaUrl));
        } else if (media.thumbnailUrl != null && media.thumbnailUrl!.isNotEmpty) {
          unawaited(_precacheImageQuietly(media.thumbnailUrl!));
        }
      }
    }

    _updatePreloadedVideoForIndex(currentIndex, posts);
  }

  /// Picks the very next video after [currentIndex] and asks
  /// [preloadedVideoUrlProvider] to hold ONE controller for it.
  /// Also disk-caches the file (streamed + de-duped inside CacheManager).
  void _updatePreloadedVideoForIndex(int currentIndex, List<PostModel> posts) {
    if (posts.isEmpty) return;
    String? nextVideoUrl;
    for (int i = currentIndex + 1;
        i < posts.length && i <= currentIndex + 5;
        i++) {
      for (final media in posts[i].media) {
        if (media.mediaType == 'video' && media.mediaUrl.isNotEmpty) {
          nextVideoUrl = media.mediaUrl;
          break;
        }
      }
      if (nextVideoUrl != null) break;
    }

    if (nextVideoUrl == _lastPreloadedVideoUrl) return;
    _lastPreloadedVideoUrl = nextVideoUrl;
    final targetUrl = nextVideoUrl;
    Future.microtask(() {
      try {
        _ref.read(preloadedVideoUrlProvider.notifier).state = targetUrl;
      } catch (_) {}
    });
    if (nextVideoUrl != null) {
      unawaited(CacheManager().preloadVideo(nextVideoUrl));
    }
  }

  void updateLikedIds(Set<String> likedIds) {
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) => p.copyWith(hasLiked: likedIds.contains(p.id))).toList();
      state = AsyncValue.data(updated);
    }
  }

  void updateBookmarkedIds(Set<String> bookmarkedIds) {
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) => p.copyWith(hasBookmarked: bookmarkedIds.contains(p.id))).toList();
      state = AsyncValue.data(updated);
    }
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    // Optimistic UI updates
    PostModel? likedPost;
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) {
        if (p.id == postId) {
          likedPost = p;
          final newLikes = currentlyLiked ? p.likes - 1 : p.likes + 1;
          return p.copyWith(hasLiked: !currentlyLiked, likes: newLikes);
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    }

    final isOnline = _ref.read(networkServiceProvider).isOnline;
    if (!isOnline) {
      await _ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'like',
        targetId: postId,
        data: {'userId': _userId, 'isLiked': !currentlyLiked},
      );
      return;
    }

    try {
      await _ref.read(likeRepositoryProvider).togglePostLike(postId, _userId);
      // Only emit a notification when adding a like (not on unlike).
      if (!currentlyLiked && likedPost != null) {
        _notifyLike(likedPost!);
      }
    } catch (_) {
      // Catch network exception and queue it
      await _ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'like',
        targetId: postId,
        data: {'userId': _userId, 'isLiked': !currentlyLiked},
      );
    }
  }

  void _notifyLike(PostModel post) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    unawaited(NotificationService.instance.like(
      receiverId: post.userId,
      actor: notificationActorOf(_ref),
      contentId: post.id,
      isReel: post.hasVideo,
      thumbnailUrl: media?.thumbnailUrl ?? media?.mediaUrl,
    ));
  }

  Future<void> toggleBookmark(String postId, bool currentlyBookmarked) async {
    // Optimistic UI update
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) {
        if (p.id == postId) {
          final newBookmarks = currentlyBookmarked ? p.bookmarks - 1 : p.bookmarks + 1;
          return p.copyWith(hasBookmarked: !currentlyBookmarked, bookmarks: newBookmarks);
        }
        return p;
      }).toList();
      state = AsyncValue.data(updated);
    }

    final isOnline = _ref.read(networkServiceProvider).isOnline;
    if (!isOnline) {
      await _ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'bookmark',
        targetId: postId,
        data: {'userId': _userId, 'isBookmarked': !currentlyBookmarked},
      );
      return;
    }

    try {
      if (state is AsyncData<List<PostModel>>) {
        final posts = state.asData!.value;
        final post = posts.firstWhere((p) => p.id == postId);
        await _ref.read(bookmarkRepositoryProvider).toggleBookmark(_userId, post);
      }
    } catch (_) {
      await _ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'bookmark',
        targetId: postId,
        data: {'userId': _userId, 'isBookmarked': !currentlyBookmarked},
      );
    }
  }

  Future<void> addNewPost(PostModel post) async {
    await _repository.createPost(post);
  }

  Future<void> incrementShare(String postId) async {
    await _repository.incrementShareCount(postId);
  }
}

// Comments Stream Provider - yields cached comments first for absolute instant feel
final commentsStreamProvider = StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  final repository = ref.watch(commentRepositoryProvider);
  final isOnline = ref.watch(networkServiceProvider.select((net) => net.isOnline));

  // If offline, yield cached comments list from disk
  if (!isOnline) {
    final cachedMaps = CacheManager().loadComments(postId);
    return Stream.value(cachedMaps.map((map) => CommentModel.fromMap(map, map['commentId'] as String)).toList());
  }

  return repository.watchComments(postId).map((comments) {
    // Save to cache disk
    Future.microtask(() {
      try {
        CacheManager().saveComments(postId, comments.map((c) => c.toMap()).toList());
      } catch (_) {}
    });
    return comments;
  });
});

// User's Bookmarked Posts Stream Provider
final bookmarkedPostsProvider = StreamProvider<List<PostModel>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  final repository = ref.watch(bookmarkRepositoryProvider);
  return repository.watchBookmarkedPosts(userId);
});

class UserPostsNotifier extends StateNotifier<AsyncValue<List<PostModel>>> {
  final String userId;
  final Ref ref;
  StreamSubscription? _sub;

  UserPostsNotifier(this.userId, this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    if (userId.isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    final loggedInUserId = ref.read(loggedInUserIdProvider);
    
    // Background sync listeners to apply optimistic/background updates without reloading the feed
    ref.listen<AsyncValue<Set<String>>>(userLikesIdsProvider, (prev, next) {
      if (next.hasValue) updateLikedIds(next.value!);
    });
    ref.listen<AsyncValue<Set<String>>>(userBookmarksIdsProvider, (prev, next) {
      if (next.hasValue) updateBookmarkedIds(next.value!);
    });

    _sub = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
          final fallbackLikedIds = ref.read(userLikesIdsProvider).valueOrNull ?? {};
          final bookmarkedIds = ref.read(userBookmarksIdsProvider).valueOrNull ?? {};

          final list = snapshot.docs.map((doc) => PostModel.fromMap({...doc.data(), 'id': doc.id})).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          final mapped = list.map((post) {
            final rawData = snapshot.docs.firstWhere((d) => d.id == post.id).data();
            final likedBy = List<String>.from(rawData['likedBy'] ?? []);
            return post.copyWith(
              hasLiked: likedBy.contains(loggedInUserId) || fallbackLikedIds.contains(post.id),
              hasBookmarked: bookmarkedIds.contains(post.id),
            );
          }).toList();
          
          state = AsyncValue.data(mapped);
        }, onError: (err, stack) {
          state = AsyncValue.error(err, stack);
        });
  }

  void updateLikedIds(Set<String> likedIds) {
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) {
        // Only override if it wasn't already natively liked by this user
        bool nativelyLiked = false;
        if (p.hasLiked) nativelyLiked = true; // Best effort guess without raw data
        return p.copyWith(hasLiked: nativelyLiked || likedIds.contains(p.id));
      }).toList();
      state = AsyncValue.data(updated);
    }
  }

  void updateBookmarkedIds(Set<String> bookmarkedIds) {
    if (state is AsyncData<List<PostModel>>) {
      final posts = state.asData!.value;
      final updated = posts.map((p) => p.copyWith(hasBookmarked: bookmarkedIds.contains(p.id))).toList();
      state = AsyncValue.data(updated);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final userPostsProvider = StateNotifierProvider.family<UserPostsNotifier, AsyncValue<List<PostModel>>, String>((ref, userId) {
  return UserPostsNotifier(userId, ref);
});

// Story Repository Provider
final storyRepositoryProvider = Provider<StoryRepository>((ref) {
  return StoryRepositoryImpl();
});

// Stories provider
final feedStoriesProvider =
    StateNotifierProvider<StoriesNotifier, AsyncValue<List<StoryModel>>>((ref) {
  final repo = ref.watch(storyRepositoryProvider);
  return StoriesNotifier(repo, ref);
});

class StoriesNotifier extends StateNotifier<AsyncValue<List<StoryModel>>> {
  final StoryRepository _repository;
  final Ref _ref;
  StreamSubscription? _subscription;

  StoriesNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchActiveStories().listen((stories) {
      state = AsyncValue.data(stories);
    }, onError: (err, stack) {
      state = AsyncValue.error(err, stack);
    });
  }

  Future<void> viewStory(String storyId) async {
    final userId = _ref.read(loggedInUserIdProvider);
    await _repository.markStoryViewed(storyId, userId);
  }

  Future<void> uploadStory(String filePath, {String? caption, String visibility = 'public'}) async {
    final userAsync = _ref.read(currentUserProvider);
    final user = userAsync.valueOrNull;
    final userId = user?.id ?? 'user_1';
    final userName = user?.name ?? 'Jordan Vance';
    final userAvatar = user?.avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=150';
    final verified = user?.verified ?? true;

    final idempotencyKey = const Uuid().v4();
    final fileName = filePath.split('/').last;
    final queue = _ref.read(uploadQueueProvider.notifier);
    final taskId = await queue.addTask(
      bytes: null,
      filePath: filePath,
      fileName: fileName,
      ownerType: 'story',
      idempotencyKey: idempotencyKey,
    );

    UploadTask? completedTask;
    await for (final tasks in _ref.read(uploadQueueProvider.notifier).stream) {
      final t = tasks.where((t) => t.id == taskId).firstOrNull;
      if (t == null) break;
      if (t.status == UploadStatus.completed) {
        completedTask = t;
        break;
      }
      if (t.status == UploadStatus.failed || t.status == UploadStatus.cancelled) {
        throw Exception(t.errorMessage ?? 'Story upload failed');
      }
    }

    if (completedTask == null || completedTask.mediaId == null) {
      throw Exception('Story task failed to return media ID');
    }

    final doc = await FirebaseFirestore.instance.collection('media').doc(completedTask.mediaId).get();
    final urls = doc.data()?['urls'] as Map?;
    final mediaUrl = urls?['original'] as String?;
    if (mediaUrl == null) {
      throw Exception('Story image variant URL is missing.');
    }

    final story = StoryModel(
      id: 'story_${DateTime.now().millisecondsSinceEpoch}_$userId',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      verified: verified,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      likes: [],
      viewedBy: [userId], // author automatically viewed
      caption: caption,
      visibility: visibility,
    );

    await _repository.createStory(story);
  }

  Future<void> deleteStory(String storyId) async {
    await _repository.deleteStory(storyId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
