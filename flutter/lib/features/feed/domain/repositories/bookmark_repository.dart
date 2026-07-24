import '../../../feed/domain/models/post_model.dart';

abstract class BookmarkRepository {
  Future<void> toggleBookmark(String userId, PostModel post);
  Stream<List<PostModel>> watchBookmarkedPosts(String userId);
}
