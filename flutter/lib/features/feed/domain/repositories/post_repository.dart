import '../models/post_model.dart';

abstract class PostRepository {
  Future<List<PostModel>> getPosts({String? currentUserId});
  Future<List<PostModel>> getPostsByCategory(String category, {String? currentUserId});
  Stream<List<PostModel>> watchPosts({String? currentUserId});
  Stream<List<PostModel>> watchPostsByCategory(String category, {String? currentUserId});

  Stream<List<PostModel>> watchPostsFiltered({
    required String category,
    required String sport,
    required String sortBy, // 'Latest' | 'Trending'
    String? currentUserId,
  });

  Future<List<PostModel>> getPostsFilteredPaginated({
    required String category,
    required String sport,
    required String sortBy,
    int limit = 8,
    String? lastPostId,
    String? currentUserId,
  });

  Future<void> likePost(String postId, bool like);
  Future<void> togglePostLike(String postId, String userId, {bool? targetLiked});
  Future<void> toggleBookmark(String postId, bool bookmark);
  Future<void> togglePostBookmark(String postId, String userId);
  Future<void> createPost(PostModel post);
  Future<void> deletePost(PostModel post);
  Future<void> incrementShareCount(String postId);
  Future<void> incrementViewCount(String postId);
}
