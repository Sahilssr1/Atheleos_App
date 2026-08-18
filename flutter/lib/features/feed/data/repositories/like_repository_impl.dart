import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/like_repository.dart';

class LikeRepositoryImpl implements LikeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> togglePostLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final userLikeRef = _firestore.collection('users').doc(userId).collection('likes').doc(postId);

    await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final map = postDoc.data() ?? {};
      final likedBy = List<String>.from(map['likedBy'] ?? []);
      final currentLikes = map['likes'] as int? ?? likedBy.length;

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': (currentLikes - 1).clamp(0, double.infinity).toInt(),
        });
        transaction.delete(likeRef);
        transaction.delete(userLikeRef);
      } else {
        likedBy.add(userId);
        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': currentLikes + 1,
        });
        transaction.set(likeRef, {
          'userId': userId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        transaction.set(userLikeRef, {
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }
}
