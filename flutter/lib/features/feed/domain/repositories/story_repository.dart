import '../../domain/models/story_model.dart';

abstract class StoryRepository {
  Stream<List<StoryModel>> watchActiveStories();
  Future<void> createStory(StoryModel story);
  Future<void> toggleStoryLike(String storyId, String userId);
  Future<void> markStoryViewed(String storyId, String userId);
  Future<void> deleteStory(String storyId);
}
