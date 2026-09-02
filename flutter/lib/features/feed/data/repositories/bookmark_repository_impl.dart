import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../domain/repositories/bookmark_repository.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> toggleBookmark(String userId, PostModel post) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (userId.isNotEmpty ? userId : 'user_1');

    if (effectiveUserId.isEmpty) return;

    final postRef = _firestore.collection('posts').doc(post.id);
    final bookmarkRef = _firestore.collection('users').doc(effectiveUserId).collection('bookmarks').doc(post.id);

    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final map = postDoc.data() ?? {};
        final rawBookmarkedBy = map['bookmarkedBy'];
        final bookmarkedBy = List<String>.from((rawBookmarkedBy as List?)?.map((e) => e.toString()) ?? []);

        int currentBookmarks = 0;
        final rawBookmarks = map['bookmarks'] ?? map['bookmarkCount'];
        if (rawBookmarks is int) {
          currentBookmarks = rawBookmarks;
        } else if (rawBookmarks is num) {
          currentBookmarks = rawBookmarks.toInt();
        } else if (rawBookmarks is String) {
          currentBookmarks = int.tryParse(rawBookmarks) ?? bookmarkedBy.length;
        } else {
          currentBookmarks = bookmarkedBy.length;
        }

        if (bookmarkedBy.contains(effectiveUserId)) {
          bookmarkedBy.remove(effectiveUserId);
          transaction.update(postRef, {
            'bookmarkedBy': bookmarkedBy,
            'bookmarks': (currentBookmarks - 1).clamp(0, double.infinity).toInt(),
            'bookmarkCount': (currentBookmarks - 1).clamp(0, double.infinity).toInt(),
          });
          transaction.delete(bookmarkRef);
        } else {
          bookmarkedBy.add(effectiveUserId);
          final newBookmarks = currentBookmarks + 1;
          transaction.update(postRef, {
            'bookmarkedBy': bookmarkedBy,
            'bookmarks': newBookmarks,
            'bookmarkCount': newBookmarks,
          });
          // Save post data representation inside the bookmark to load it fast in one go
          final updatedPost = post.copyWith(
            hasBookmarked: true,
            bookmarks: newBookmarks,
          );
          transaction.set(bookmarkRef, {
            'postId': post.id,
            'createdAt': FieldValue.serverTimestamp(),
            'post': updatedPost.toMap(),
          });
        }
      });
    } catch (e) {
      debugPrint('Error toggling bookmark in BookmarkRepositoryImpl: $e');
    }
  }

  @override
  Stream<List<PostModel>> watchBookmarkedPosts(String userId) {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : (userId.isNotEmpty ? userId : 'user_1');

    return _firestore
        .collection('users')
        .doc(effectiveUserId)
        .collection('bookmarks')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final postMap = data['post'] as Map<String, dynamic>? ?? {};
            return PostModel.fromMap({
              ...postMap,
              'hasBookmarked': true,
            }, currentUserId: effectiveUserId);
          }).toList();
        });
  }
}
