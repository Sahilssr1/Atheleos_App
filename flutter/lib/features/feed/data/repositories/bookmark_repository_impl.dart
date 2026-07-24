import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../domain/repositories/bookmark_repository.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> toggleBookmark(String userId, PostModel post) async {
    final postRef = _firestore.collection('posts').doc(post.id);
    final bookmarkRef = _firestore.collection('users').doc(userId).collection('bookmarks').doc(post.id);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final map = postDoc.data() ?? {};
      final bookmarkedBy = List<String>.from(map['bookmarkedBy'] ?? []);
      final currentBookmarks = map['bookmarks'] as int? ?? bookmarkedBy.length;

      if (bookmarkedBy.contains(userId)) {
        bookmarkedBy.remove(userId);
        transaction.update(postRef, {
          'bookmarkedBy': bookmarkedBy,
          'bookmarks': (currentBookmarks - 1).clamp(0, double.infinity).toInt(),
        });
        transaction.delete(bookmarkRef);
      } else {
        bookmarkedBy.add(userId);
        transaction.update(postRef, {
          'bookmarkedBy': bookmarkedBy,
          'bookmarks': currentBookmarks + 1,
        });
        // Save post data representation inside the bookmark to load it fast in one go
        final updatedPost = post.copyWith(
          hasBookmarked: true,
          bookmarks: currentBookmarks + 1,
        );
        transaction.set(bookmarkRef, {
          'postId': post.id,
          'createdAt': FieldValue.serverTimestamp(),
          'post': updatedPost.toMap(),
        });
      }
    });
  }

  @override
  Stream<List<PostModel>> watchBookmarkedPosts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final postMap = data['post'] as Map<String, dynamic>? ?? {};
            // Post inside users' bookmarks has hasBookmarked as true
            return PostModel.fromMap({
              ...postMap,
              'hasBookmarked': true,
            });
          }).toList();
        });
  }
}
