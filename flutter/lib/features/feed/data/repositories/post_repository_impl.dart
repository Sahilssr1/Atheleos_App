import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/post_model.dart';
import '../../domain/repositories/post_repository.dart';

class PostRepositoryImpl implements PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PostModel _mapDocToPost(DocumentSnapshot doc, String? currentUserId) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return PostModel.fromMap({
      ...map,
      'id': doc.id,
    });
  }

  @override
  Future<List<PostModel>> getPosts({String? currentUserId}) async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
  }

  @override
  Future<List<PostModel>> getPostsByCategory(String category, {String? currentUserId}) async {
    if (category.toLowerCase() == 'all') {
      return getPosts(currentUserId: currentUserId);
    }
    final snapshot = await _firestore
        .collection('posts')
        .where('category', isEqualTo: category.toLowerCase())
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
  }

  @override
  Stream<List<PostModel>> watchPosts({String? currentUserId}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
        });
  }

  @override
  Stream<List<PostModel>> watchPostsByCategory(String category, {String? currentUserId}) {
    if (category.toLowerCase() == 'all') {
      return watchPosts(currentUserId: currentUserId);
    }
    return _firestore
        .collection('posts')
        .where('category', isEqualTo: category.toLowerCase())
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
          posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return posts;
        });
  }

  @override
  Stream<List<PostModel>> watchPostsFiltered({
    required String category,
    required String sport,
    required String sortBy,
    String? currentUserId,
  }) {
    Query query = _firestore.collection('posts');

    if (category.toLowerCase() != 'all') {
      query = query.where('category', isEqualTo: category.toLowerCase());
    }
    if (sport != 'All') {
      query = query.where('sport', isEqualTo: sport);
    }

    final sortField = sortBy == 'Trending' ? 'likes' : 'createdAt';
    query = query.orderBy(sortField, descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
    });
  }

  @override
  Future<List<PostModel>> getPostsFilteredPaginated({
    required String category,
    required String sport,
    required String sortBy,
    int limit = 8,
    String? lastPostId,
    String? currentUserId,
  }) async {
    Query query = _firestore.collection('posts');

    if (category.toLowerCase() != 'all') {
      query = query.where('category', isEqualTo: category.toLowerCase());
    }
    if (sport != 'All') {
      query = query.where('sport', isEqualTo: sport);
    }

    final sortField = sortBy == 'Trending' ? 'likes' : 'createdAt';
    query = query.orderBy(sortField, descending: true);

    if (lastPostId != null && lastPostId.isNotEmpty) {
      final lastDoc = await _firestore.collection('posts').doc(lastPostId).get();
      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
  }

  @override
  Future<void> likePost(String postId, bool like) async {
    // Deprecated in favor of togglePostLike
  }

  @override
  Future<void> togglePostLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final userLikeRef = _firestore.collection('users').doc(userId).collection('likes').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final currentLikes = postDoc.get('likes') as int? ?? 0;
        final likeSnapshot = await transaction.get(likeRef);

        if (likeSnapshot.exists) {
          transaction.delete(likeRef);
          transaction.delete(userLikeRef);
          transaction.update(postRef, {
            'likes': (currentLikes - 1).clamp(0, double.infinity).toInt(),
          });
        } else {
          final now = FieldValue.serverTimestamp();
          transaction.set(likeRef, {
            'userId': userId,
            'createdAt': now,
          });
          transaction.set(userLikeRef, {
            'postId': postId,
            'createdAt': now,
          });
          transaction.update(postRef, {
            'likes': currentLikes + 1,
          });
        }
      });
    } catch (e) {
      debugPrint('Error toggling post like: $e');
    }
  }

  @override
  Future<void> toggleBookmark(String postId, bool bookmark) async {
    // Deprecated in favor of togglePostBookmark
  }

  @override
  Future<void> togglePostBookmark(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final bookmarkRef = _firestore.collection('users').doc(userId).collection('bookmarks').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final currentBookmarks = postDoc.get('bookmarks') as int? ?? 0;
        final bookmarkSnapshot = await transaction.get(bookmarkRef);

        if (bookmarkSnapshot.exists) {
          transaction.delete(bookmarkRef);
          transaction.update(postRef, {
            'bookmarks': (currentBookmarks - 1).clamp(0, double.infinity).toInt(),
          });
        } else {
          final postModel = _mapDocToPost(postDoc, userId);
          transaction.set(bookmarkRef, {
            'postId': postId,
            'createdAt': FieldValue.serverTimestamp(),
            'post': postModel.toMap(),
          });
          transaction.update(postRef, {
            'bookmarks': currentBookmarks + 1,
          });
        }
      });
    } catch (e) {
      debugPrint('Error toggling post bookmark: $e');
    }
  }

  @override
  Future<void> createPost(PostModel post) async {
    final Map<String, dynamic> data = post.toMap();
    // Override the timestamp to use the server timestamp
    data['createdAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('posts').doc(post.id).set(data);
  }

  @override
  Future<void> incrementShareCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'shares': FieldValue.increment(1),
    });
  }

  @override
  Future<void> incrementViewCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'views': FieldValue.increment(1),
    });
  }

  @override
  Future<void> deletePost(PostModel post) async {
    final postRef = _firestore.collection('posts').doc(post.id);

    try {
      // Best-effort cleanup of subcollections + the post doc in a single batch.
      final likesSnapshot = await postRef.collection('likes').get();
      final commentsSnapshot = await postRef.collection('comments').get();

      final batch = _firestore.batch();
      for (final doc in likesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      for (final doc in commentsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(postRef);
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting post with subcollections, falling back to doc delete: $e');
      // Fallback: at minimum remove the post document itself.
      await postRef.delete();
    }

    // Remove the owner's own like/bookmark references to this post.
    try {
      final userRef = _firestore.collection('users').doc(post.userId);
      await Future.wait([
        userRef.collection('likes').doc(post.id).delete(),
        userRef.collection('bookmarks').doc(post.id).delete(),
      ]);
    } catch (_) {}

    // Keep the maintained profile counter in sync with uploads.
    try {
      await _firestore.collection('users').doc(post.userId).update({
        'postsCount': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error decrementing postsCount: $e');
    }
  }
}
