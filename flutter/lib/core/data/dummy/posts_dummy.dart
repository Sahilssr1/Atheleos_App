class DummyPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String sport;
  final String position;
  final bool verified;
  final String content;
  final String? mediaUrl;
  final String category;
  final int likes;
  final int shares;
  final String time;
  final bool hasLiked;

  const DummyPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.sport,
    required this.position,
    required this.verified,
    required this.content,
    this.mediaUrl,
    required this.category,
    required this.likes,
    required this.shares,
    required this.time,
    required this.hasLiked,
  });

  DummyPost copyWith({
    bool? hasLiked,
    int? likes,
  }) {
    return DummyPost(
      id: id,
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      sport: sport,
      position: position,
      verified: verified,
      content: content,
      mediaUrl: mediaUrl,
      category: category,
      likes: likes ?? this.likes,
      shares: shares,
      time: time,
      hasLiked: hasLiked ?? this.hasLiked,
    );
  }
}

final List<DummyPost> dummyPosts = [
  const DummyPost(
    id: 'post_1',
    userId: 'user_1',
    userName: 'Tyler Brooks',
    userAvatar: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&q=80&w=200&h=200',
    sport: 'Football',
    position: 'QB',
    verified: true,
    content: 'Big win last night! Put up 350 passing yards and 4 touchdowns to advance to the State Semifinals. Incredibly proud of the offensive line for protecting me and giving our wide receivers the time to get open. Film session starts today. Let\'s keep this momentum going! 🏆🏈',
    mediaUrl: 'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
    category: 'Match',
    likes: 142,
    shares: 18,
    time: '4h ago',
    hasLiked: false,
  ),
  const DummyPost(
    id: 'post_2',
    userId: 'user_3',
    userName: 'Marcus Thompson',
    userAvatar: 'https://images.unsplash.com/photo-1544651397-887117144036?auto=format&fit=crop&q=80&w=200&h=200',
    sport: 'Basketball',
    position: 'PG',
    verified: false,
    content: 'Focusing on off-the-dribble mid-range pull-ups and lateral speed drills this morning. 500 makes down before breakfast. The goal is consistency and quick release. Always working on my defense and leadership skills as a point guard. College programs, film link is in bio! #ClassOf2027',
    mediaUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
    category: 'Training',
    likes: 98,
    shares: 12,
    time: '6h ago',
    hasLiked: true,
  )
];
