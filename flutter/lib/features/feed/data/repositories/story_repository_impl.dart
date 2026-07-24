import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/story_model.dart';
import '../../domain/repositories/story_repository.dart';

class StoryRepositoryImpl implements StoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<StoryModel>> watchActiveStories() {
    // Listen to all active stories and filter locally or query using ISO Strings.
    // To ensure firestore works seamlessly without requiring complex compound indexes on app start,
    // we query all and filter locally for stories under 24 hours.
    return _firestore
        .collection('stories')
        .snapshots()
        .map((snapshot) {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));
          final list = snapshot.docs
              .map((doc) => StoryModel.fromMap(doc.data(), doc.id))
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
