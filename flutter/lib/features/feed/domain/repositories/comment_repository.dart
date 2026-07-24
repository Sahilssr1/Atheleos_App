import '../models/comment_model.dart';

abstract class CommentRepository {
  Stream<List<CommentModel>> watchComments(String postId);
  Future<void> addComment(CommentModel comment);
  Future<void> editComment(String postId, String commentId, String text);
  Future<void> deleteComment(String postId, String commentId);
  Future<void> toggleLikeComment(String postId, String commentId, String userId);
}
