import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../domain/repositories/clip_repository.dart';

class ClipRepositoryImpl implements ClipRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  PostModel _mapDocToPost(DocumentSnapshot doc, String? currentUserId) {
    final map = doc.data() as Map<String, dynamic>? ?? {};
    return PostModel.fromMap({
      ...map,
      'id': doc.id,
    }, currentUserId: currentUserId);
  }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
  /// Filters posts to only include those with video media (Instagram Reels behavior)
  List<PostModel> _filterVideoOnly(List<PostModel> posts) {
    return posts.where((post) => post.hasVideo).toList();
  }

  @override
  Stream<List<PostModel>> watchClips({String? currentUserId}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final allPosts = snapshot.docs
              .map((doc) => _mapDocToPost(doc, currentUserId))
              .toList();
          return _filterVideoOnly(allPosts);
        });
  }

  @override
  Stream<List<PostModel>> watchClipsFiltered({required String sport, String? currentUserId}) {
    Query query = _firestore.collection('posts');
    if (sport != 'All') {
      query = query.where('sport', isEqualTo: sport);
    }
    query = query.orderBy('createdAt', descending: true);
    return query.snapshots().map((snapshot) {
      final allPosts = snapshot.docs
          .map((doc) => _mapDocToPost(doc, currentUserId))
          .toList();
      return _filterVideoOnly(allPosts);
    });
  }

  @override
  Future<List<PostModel>> getClipsPaginated({
    required String sport,
    int limit = 8,
    String? lastClipId,
    String? currentUserId,
  }) async {
    Query query = _firestore.collection('posts');
    if (sport != 'All') {
      query = query.where('sport', isEqualTo: sport);
    }
    query = query.orderBy('createdAt', descending: true);

    if (lastClipId != null && lastClipId.isNotEmpty) {
      final lastDoc = await _firestore.collection('posts').doc(lastClipId).get();
      if (lastDoc.exists) {
        query = query.startAfterDocument(lastDoc);
      }
    }

    // Fetch more than the limit since we filter client-side for video content
    query = query.limit(limit * 3);

    final snapshot = await query.get();
    final allPosts = snapshot.docs.map((doc) => _mapDocToPost(doc, currentUserId)).toList();
    return _filterVideoOnly(allPosts).take(limit).toList();
  }

  @override
  Future<void> createClip(PostModel clip) async {
    final Map<String, dynamic> data = clip.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['likeCount'] = 0;
    data['bookmarkedBy'] = <String>[];
    data['bookmarkCount'] = 0;
    await _firestore.collection('posts').doc(clip.id).set(data);
  }
}
