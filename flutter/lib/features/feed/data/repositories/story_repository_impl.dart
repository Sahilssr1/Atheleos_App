import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/story_model.dart';
import '../../domain/repositories/story_repository.dart';

class StoryRepositoryImpl implements StoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<StoryModel>> watchActiveStories() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final cutoffIso = cutoff.toIso8601String();
    return _firestore
        .collection('stories')
        .where('createdAt', isGreaterThan: cutoffIso)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) {
                try {
                  return StoryModel.fromMap(doc.data(), doc.id);
                } catch (e) {
                  return null;
                }
              })
              .whereType<StoryModel>()
              .where((story) => story.createdAt.isAfter(cutoff))
              .toList();
          // Sort newest first
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  @override
  Future<void> createStory(StoryModel story) async {
    await _firestore.collection('stories').doc(story.id).set(story.toMap());
  }

  @override
  Future<void> toggleStoryLike(String storyId, String userId) async {
    final ref = _firestore.collection('stories').doc(storyId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final likes = List<String>.from(data['likes'] ?? []);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      transaction.update(ref, {'likes': likes});
    });
  }

  @override
  Future<void> markStoryViewed(String storyId, String userId) async {
    final ref = _firestore.collection('stories').doc(storyId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final viewedBy = List<String>.from(data['viewedBy'] ?? []);
      if (!viewedBy.contains(userId)) {
        viewedBy.add(userId);
        transaction.update(ref, {'viewedBy': viewedBy});
      }
    });
  }

  @override
  Future<void> deleteStory(String storyId) async {
    await _firestore.collection('stories').doc(storyId).delete();
  }
}
