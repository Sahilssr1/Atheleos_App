import '../../../../core/services/sports_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    }, currentUserId: currentUserId);
  }

  @override
  Future<List<PostModel>> getPosts({String? currentUserId, int limit = 12}) async {
    final snapshot = await _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
  }

  @override
  Future<List<PostModel>> getPostsByCategory(String category, {String? currentUserId, int limit = 12}) async {
    if (category.toLowerCase() == 'all') {
      return getPosts(currentUserId: currentUserId, limit: limit);
    }
    final snapshot = await _firestore
        .collection('posts')
        .where('category', isEqualTo: category.toLowerCase())
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
  }

  @override
  Stream<List<PostModel>> watchPosts({String? currentUserId, int limit = 12}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
        });
  }

  @override
  Stream<List<PostModel>> watchPostsByCategory(String category, {String? currentUserId, int limit = 12}) {
    if (category.toLowerCase() == 'all') {
      return watchPosts(currentUserId: currentUserId, limit: limit);
    }
    return _firestore
        .collection('posts')
        .where('category', isEqualTo: category.toLowerCase())
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          final posts = snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
          return posts;
        });
  }

  @override
  Stream<List<PostModel>> watchPostsFiltered({
    required String category,
    required String sport,
    String sortBy = 'Latest',
    String? currentUserId,
    int limit = 12,
  }) {
    Query query = _firestore.collection('posts');

    if (category.toLowerCase() != 'all') {
      query = query.where('category', isEqualTo: category.toLowerCase());
    }
    if (sport.toLowerCase() != 'all') {
      final sportsList = SportsService.getSportsForCategory(sport);
      if (sportsList.isNotEmpty) {
        final matchTerms = <String>{
          sport.toLowerCase(),
          sport,
          ...sportsList,
          ...sportsList.map((s) => s.toLowerCase()),
        }.take(30).toList();
        query = query.where('sport', whereIn: matchTerms);
      } else {
        query = query.where('sport', isEqualTo: sport);
      }
    }

    final sortField = sortBy == 'Trending' ? 'likes' : 'createdAt';
    query = query.orderBy(sortField, descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
    });
  }

  @override
  Future<List<PostModel>> getPostsFilteredPaginated({
    required String category,
    required String sport,
    String sortBy = 'Latest',
    int limit = 8,
    String? lastPostId,
    String? currentUserId,
  }) async {
    Query query = _firestore.collection('posts');

    if (category.toLowerCase() != 'all') {
      query = query.where('category', isEqualTo: category.toLowerCase());
    }
    if (sport.toLowerCase() != 'all') {
      final sportsList = SportsService.getSportsForCategory(sport);
      if (sportsList.isNotEmpty) {
        final matchTerms = <String>{
          sport.toLowerCase(),
          sport,
          ...sportsList,
          ...sportsList.map((s) => s.toLowerCase()),
        }.take(30).toList();
        query = query.where('sport', whereIn: matchTerms);
      } else {
        query = query.where('sport', isEqualTo: sport);
      }
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

    try {
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
    } catch (e) {
      debugPrint('[POST QUERY FALLBACK] $e');
      Query fallback = _firestore.collection('posts');
      if (category.toLowerCase() != 'all') {
        fallback = fallback.where('category', isEqualTo: category.toLowerCase());
      }
      final snap = await fallback.limit(limit * 3).get();
      final allPosts = snap.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
      final filtered = allPosts.where((p) {
        if (sport.toLowerCase() == 'all') return true;
        final matchTerms = SportsService.getSportsForCategory(sport);
        return matchTerms.contains(p.sport) ||
               p.sport.toLowerCase() == sport.toLowerCase() ||
               matchTerms.map((m) => m.toLowerCase()).contains(p.sport.toLowerCase());
      }).toList();
      filtered.sort((a, b) => sortBy == 'Trending' ? b.likes.compareTo(a.likes) : b.createdAt.compareTo(a.createdAt));
      return filtered.take(limit).toList();
    }
  }

  @override
  Future<void> likePost(String postId, bool like) async {
    // Deprecated in favor of togglePostLike
  }

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
      debugPrint('Error toggling post like in PostRepositoryImpl: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleBookmark(String postId, bool bookmark) async {
    // Deprecated in favor of togglePostBookmark
  }

  @override
  Future<void> togglePostBookmark(String postId, String userId) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final effectiveUserId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : userId;

    if (effectiveUserId.isEmpty) return;

    final postRef = _firestore.collection('posts').doc(postId);
    final bookmarkRef = _firestore.collection('users').doc(effectiveUserId).collection('bookmarks').doc(postId);

    try {
      await _firestore.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) return;

        final map = postDoc.data() ?? {};
        final bookmarkedBy = List<String>.from((map['bookmarkedBy'] as List?)?.map((e) => e.toString()) ?? []);
        final currentBookmarks = map['bookmarks'] as int? ?? (map['bookmarkCount'] as int? ?? bookmarkedBy.length);

        if (bookmarkedBy.contains(effectiveUserId)) {
          bookmarkedBy.remove(effectiveUserId);
          final newBookmarks = (currentBookmarks - 1).clamp(0, double.infinity).toInt();
          transaction.update(postRef, {
            'bookmarkedBy': bookmarkedBy,
            'bookmarks': newBookmarks,
            'bookmarkCount': newBookmarks,
          });
          transaction.delete(bookmarkRef);
        } else {
          bookmarkedBy.add(effectiveUserId);
          final newBookmarks = currentBookmarks + 1;
          final postModel = _mapDocToPost(postDoc, effectiveUserId);
          transaction.set(bookmarkRef, {
            'postId': postId,
            'createdAt': FieldValue.serverTimestamp(),
            'post': postModel.toMap(),
          });
          transaction.update(postRef, {
            'bookmarkedBy': bookmarkedBy,
            'bookmarks': newBookmarks,
            'bookmarkCount': newBookmarks,
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
