class DummyStory {
  final String id;
  final String userName;
  final String userAvatar;
  final bool hasUnread;
  final String? storyMediaUrl;

  const DummyStory({
    required this.id,
    required this.userName,
    required this.userAvatar,
    required this.hasUnread,
    this.storyMediaUrl,
  });
}

final List<DummyStory> dummyStories = [
  const DummyStory(
    id: 'story_1',
    userName: 'Tyler B.',
    userAvatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=200&h=200',
    hasUnread: true,
  ),
  const DummyStory(
    id: 'story_2',
    userName: 'Sarah J.',
    userAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=200&h=200',
    hasUnread: true,
  ),
  const DummyStory(
    id: 'story_3',
    userName: 'Marcus T.',
    userAvatar: 'https://images.unsplash.com/photo-1544651397-887117144036?auto=format&fit=crop&q=80&w=200&h=200',
    hasUnread: false,
  ),
];
