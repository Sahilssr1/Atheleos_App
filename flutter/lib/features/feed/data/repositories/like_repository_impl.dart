import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/like_repository.dart';

class LikeRepositoryImpl implements LikeRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> togglePostLike(String postId, String userId, {bool? targetLiked}) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : userId;

    if (effectiveUserId.isEmpty || postId.isEmpty) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final postLikeRef = postRef.collection('likes').doc(effectiveUserId);
    final userLikeRef = _firestore.collection('users').doc(effectiveUserId).collection('likes').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final postLikeDoc = await transaction.get(postLikeRef);
        final userLikeDoc = await transaction.get(userLikeRef);

        final postExists = postDoc.exists;
        final map = postExists ? (postDoc.data() ?? {}) : <String, dynamic>{};

        final rawLikes = map['likes'] ?? map['likeCount'];
        int currentLikes = 0;
        if (rawLikes is int) {
          currentLikes = rawLikes;
        } else if (rawLikes is num) {
          currentLikes = rawLikes.toInt();
        } else if (rawLikes is String) {
          currentLikes = int.tryParse(rawLikes) ?? 0;
        }

        final bool isAlreadyLiked = postLikeDoc.exists || userLikeDoc.exists;
        final bool shouldLike = targetLiked ?? !isAlreadyLiked;

        if (!shouldLike) {
          // If already unliked, nothing to do
          if (!isAlreadyLiked && !postLikeDoc.exists && !userLikeDoc.exists) return;

          // UNLIKE
          final newLikes = (currentLikes - 1).clamp(0, double.infinity).toInt();
          transaction.delete(postLikeRef);
          transaction.delete(userLikeRef);

          if (postExists) {
            transaction.update(postRef, {
              'likes': newLikes,
              'likeCount': newLikes,
            });
          }
        } else {
          // If already liked, ensure both subcollection docs exist without double-incrementing count
          if (isAlreadyLiked && postLikeDoc.exists && userLikeDoc.exists) return;

          // LIKE
          final newLikes = isAlreadyLiked ? currentLikes : currentLikes + 1;
          final now = FieldValue.serverTimestamp();
          transaction.set(postLikeRef, {
            'userId': effectiveUserId,
            'createdAt': now,
          });
          transaction.set(userLikeRef, {
            'postId': postId,
            'createdAt': now,
          });

          if (postExists) {
            transaction.update(postRef, {
              'likes': newLikes,
              'likeCount': newLikes,
            });
          }
        }
      });
    } catch (e) {
      debugPrint('Error toggling post like in LikeRepositoryImpl: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPostLikedByUser(String postId, String userId) async {
    final effectiveUserId = userId.isNotEmpty
        ? userId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (effectiveUserId.isEmpty || postId.isEmpty) return false;

    try {
      final userLikeDoc = await _firestore
          .collection('users')
          .doc(effectiveUserId)
          .collection('likes')
          .doc(postId)
          .get();
      if (userLikeDoc.exists) return true;

      final postLikeDoc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(effectiveUserId)
          .get();
      return postLikeDoc.exists;
    } catch (e) {
      debugPrint('Error checking isPostLikedByUser: $e');
      return false;
    }
  }

  @override
  Future<Set<String>> getUserLikedPostIds(String userId) async {
    final effectiveUserId = userId.isNotEmpty
        ? userId
        : (FirebaseAuth.instance.currentUser?.uid ?? '');
    if (effectiveUserId.isEmpty) return {};

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(effectiveUserId)
          .collection('likes')
          .get();
      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('Error fetching user liked post IDs: $e');
      return {};
    }
  }
}
