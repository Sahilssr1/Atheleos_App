abstract class LikeRepository {
  Future<void> togglePostLike(String postId, String userId, {bool? targetLiked});
  Future<bool> isPostLikedByUser(String postId, String userId);
  Future<Set<String>> getUserLikedPostIds(String userId);
}
