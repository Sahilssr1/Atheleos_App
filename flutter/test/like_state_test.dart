import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/feed/presentation/controllers/like_controller.dart';
import 'package:atheleos/features/feed/presentation/controllers/feed_controller.dart' show likeRepositoryProvider, userLikesIdsProvider;
import 'package:atheleos/features/profile/presentation/controllers/profile_controller.dart' show loggedInUserIdProvider;
import 'package:atheleos/features/feed/domain/models/post_model.dart';
import 'package:atheleos/features/feed/domain/repositories/like_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atheleos/core/services/cache_manager.dart';

class MockLikeRepository implements LikeRepository {
  final Set<String> likedPosts = {};
  bool shouldFail = false;

  @override
  Future<void> togglePostLike(String postId, String userId, {bool? targetLiked}) async {
    if (shouldFail) {
      throw Exception('Network error');
    }
    final bool shouldLike = targetLiked ?? !likedPosts.contains(postId);
    if (shouldLike) {
      likedPosts.add(postId);
    } else {
      likedPosts.remove(postId);
    }
  }

  @override
  Future<bool> isPostLikedByUser(String postId, String userId) async {
    return likedPosts.contains(postId);
  }

  @override
  Future<Set<String>> getUserLikedPostIds(String userId) async {
    return likedPosts;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CacheManager().init();
  });

  test('PostLikeState copyWith preserves and updates state properly', () {
    const state = PostLikeState(isLiked: false, likesCount: 10, isPending: false);
    final updated = state.copyWith(isLiked: true, likesCount: 11);

    expect(updated.isLiked, isTrue);
    expect(updated.likesCount, 11);
    expect(updated.isPending, isFalse);
  });

  test('SharedLikeNotifier registers and toggles post like optimistically and persists', () async {
    final mockRepo = MockLikeRepository();
    final container = ProviderContainer(
      overrides: [
        likeRepositoryProvider.overrideWithValue(mockRepo),
        loggedInUserIdProvider.overrideWith((ref) => 'test_user_id'),
        userLikesIdsProvider.overrideWith((ref) => Stream.value({})),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(sharedLikeStateProvider.notifier);

    final post = PostModel(
      id: 'post_100',
      type: 'post',
      userId: 'user_author',
      userName: 'Athlete',
      userAvatar: '',
      verified: false,
      sport: 'Basketball',
      position: 'Guard',
      category: PostCategory.training,
      content: 'Morning drills',
      media: [],
      likes: 5,
      commentsCount: 2,
      bookmarks: 1,
      shares: 0,
      views: 10,
      createdAt: DateTime.now(),
      hasLiked: false,
      hasBookmarked: false,
    );

    // Initial registration
    notifier.registerPost(post);
    final initial = container.read(postLikeProvider(post));
    expect(initial.isLiked, isFalse);
    expect(initial.likesCount, 5);

    // Toggle Like
    await notifier.toggleLike(post);
    final afterLike = container.read(postLikeProvider(post));
    expect(afterLike.isLiked, isTrue);
    expect(afterLike.likesCount, 6);
    expect(mockRepo.likedPosts.contains('post_100'), isTrue);

    // Double tap with forceLike: true does not unlike
    await notifier.toggleLike(post, forceLike: true);
    final afterDoubleTap = container.read(postLikeProvider(post));
    expect(afterDoubleTap.isLiked, isTrue);
    expect(afterDoubleTap.likesCount, 6);

    // Toggle Unlike
    await notifier.toggleLike(post);
    final afterUnlike = container.read(postLikeProvider(post));
    expect(afterUnlike.isLiked, isFalse);
    expect(afterUnlike.likesCount, 5);
    expect(mockRepo.likedPosts.contains('post_100'), isFalse);
  });

  test('SharedLikeNotifier rolls back state if backend fails', () async {
    final mockRepo = MockLikeRepository()..shouldFail = true;
    final container = ProviderContainer(
      overrides: [
        likeRepositoryProvider.overrideWithValue(mockRepo),
        loggedInUserIdProvider.overrideWith((ref) => 'test_user_id'),
        userLikesIdsProvider.overrideWith((ref) => Stream.value({})),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(sharedLikeStateProvider.notifier);

    final post = PostModel(
      id: 'post_200',
      type: 'post',
      userId: 'user_author',
      userName: 'Athlete',
      userAvatar: '',
      verified: false,
      sport: 'Basketball',
      position: 'Guard',
      category: PostCategory.training,
      content: 'Rollback test',
      media: [],
      likes: 12,
      commentsCount: 0,
      bookmarks: 0,
      shares: 0,
      views: 5,
      createdAt: DateTime.now(),
      hasLiked: false,
      hasBookmarked: false,
    );

    notifier.registerPost(post);
    expect(container.read(postLikeProvider(post)).isLiked, isFalse);

    // Attempt toggle with failure
    await notifier.toggleLike(post);

    // Should rollback to original state
    final stateAfterRollback = container.read(postLikeProvider(post));
    expect(stateAfterRollback.isLiked, isFalse);
    expect(stateAfterRollback.likesCount, 12);
  });
}
