import '../../domain/models/story_model.dart';
import '../../domain/repositories/story_repository.dart';

class DummyStoryRepository implements StoryRepository {
  final List<StoryModel> _stories = [
    StoryModel(
      id: 'story_1',
      userId: 'user_1',
      userName: 'Tyler Brooks',
      userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      verified: true,
      mediaUrl: 'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
      createdAt: DateTime.now(),
    ),
    StoryModel(
      id: 'story_2',
      userId: 'user_2',
      userName: 'Sarah Jenkins',
      userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
      verified: true,
      mediaUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
      createdAt: DateTime.now(),
    ),
    StoryModel(
      id: 'story_3',
      userId: 'user_3',
      userName: 'Marcus Thompson',
      userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=200&h=200',
      verified: false,
      mediaUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
      viewedBy: const ['user_1'],
      createdAt: DateTime.now(),
    ),
    StoryModel(
      id: 'story_4',
      userId: 'user_4',
      userName: 'Elena Rostova',
      userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200&h=200',
      verified: true,
      mediaUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&q=80&w=800',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Stream<List<StoryModel>> watchActiveStories() {
    return Stream.value(List.from(_stories));
  }

  @override
  Future<void> createStory(StoryModel story) async {
    _stories.add(story);
  }

  @override
  Future<void> toggleStoryLike(String storyId, String userId) async {
    final index = _stories.indexWhere((s) => s.id == storyId);
    if (index != -1) {
      final story = _stories[index];
      final likes = List<String>.from(story.likes);
      if (likes.contains(userId)) {
        likes.remove(userId);
      } else {
        likes.add(userId);
      }
      _stories[index] = story.copyWith(likes: likes);
    }
  }

  @override
  Future<void> markStoryViewed(String storyId, String userId) async {
    final index = _stories.indexWhere((s) => s.id == storyId);
    if (index != -1) {
      final story = _stories[index];
      final viewedBy = List<String>.from(story.viewedBy);
      if (!viewedBy.contains(userId)) {
        viewedBy.add(userId);
        _stories[index] = story.copyWith(viewedBy: viewedBy);
      }
    }
  }

  @override
  Future<void> deleteStory(String storyId) async {
    _stories.removeWhere((s) => s.id == storyId);
  }
}
