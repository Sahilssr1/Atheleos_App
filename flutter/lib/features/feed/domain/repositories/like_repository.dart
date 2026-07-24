abstract class LikeRepository {
  Future<void> togglePostLike(String postId, String userId);
}
