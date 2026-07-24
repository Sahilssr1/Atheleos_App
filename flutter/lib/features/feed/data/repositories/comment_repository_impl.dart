import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/repositories/comment_repository.dart';

class CommentRepositoryImpl implements CommentRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<CommentModel>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false) // oldest first makes reading conversational
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => CommentModel.fromMap(doc.data(), doc.id)).toList();
        });
  }

  @override
  Future<void> addComment(CommentModel comment) async {
    final postRef = _firestore.collection('posts').doc(comment.postId);
    final commentRef = postRef.collection('comments').doc(comment.commentId);

    await _firestore.runTransaction((transaction) async {
      // 1. Write comment
      transaction.set(commentRef, comment.toMap());

      // 2. Increment post commentsCount
      transaction.update(postRef, {
        'commentsCount': FieldValue.increment(1),
      });

      // 3. If nested reply, increment parent replyCount
      if (comment.parentId != null && comment.parentId!.isNotEmpty) {
        final parentRef = postRef.collection('comments').doc(comment.parentId);
        transaction.update(parentRef, {
          'replyCount': FieldValue.increment(1),
        });
      }
    });
  }

  @override
  Future<void> editComment(String postId, String commentId, String text) async {
    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
          'text': text,
          'edited': true,
        });
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final commentDoc = await transaction.get(commentRef);
      if (!commentDoc.exists) return;

      final parentId = commentDoc.get('parentId') as String?;

      // 1. Delete comment
      transaction.delete(commentRef);

      // 2. Decrement post commentsCount
      transaction.update(postRef, {
        'commentsCount': FieldValue.increment(-1),
      });

      // 3. If reply, decrement parent replyCount
      if (parentId != null && parentId.isNotEmpty) {
        final parentRef = postRef.collection('comments').doc(parentId);
        transaction.update(parentRef, {
          'replyCount': FieldValue.increment(-1),
        });
      }
    });
  }

  @override
  Future<void> toggleLikeComment(String postId, String commentId, String userId) async {
    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(commentRef);
      if (!doc.exists) return;

      final map = doc.data() ?? {};
      final likedBy = List<String>.from(map['likedBy'] ?? []);
      final currentLikes = map['likesCount'] as int? ?? likedBy.length;

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        transaction.update(commentRef, {
          'likedBy': likedBy,
          'likesCount': (currentLikes - 1).clamp(0, double.infinity).toInt(),
        });
      } else {
        likedBy.add(userId);
        transaction.update(commentRef, {
          'likedBy': likedBy,
          'likesCount': currentLikes + 1,
        });
      }
    });
  }
}
