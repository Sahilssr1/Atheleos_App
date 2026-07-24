class DummyClip {
  final String id;
  final String title;
  final String athlete;
  final String sport;
  final String views;
  final int likes;
  final bool hasLiked;
  final String bgUrl;

  const DummyClip({
    required this.id,
    required this.title,
    required this.athlete,
    required this.sport,
    required this.views,
    required this.likes,
    required this.hasLiked,
    required this.bgUrl,
  });

  DummyClip copyWith({
    bool? hasLiked,
    int? likes,
  }) {
    return DummyClip(
      id: id,
      title: title,
      athlete: athlete,
      sport: sport,
      views: views,
      likes: likes ?? this.likes,
      hasLiked: hasLiked ?? this.hasLiked,
      bgUrl: bgUrl,
    );
  }
}

final List<DummyClip> dummyClips = [
  const DummyClip(
    id: 'clip_1',
    title: 'Overtime Winning Basket! 🏀🔥',
    athlete: 'Marcus Thompson',
    sport: 'Basketball',
    views: '12.4K',
    likes: 823,
    hasLiked: false,
    bgUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=600',
  ),
  const DummyClip(
    id: 'clip_2',
    title: '40-Yard Dash: 4.41s ⚡️🏈',
    athlete: 'Tyler Brooks',
    sport: 'Football',
    views: '8.1K',
    likes: 542,
    hasLiked: true,
    bgUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=600',
  )
];
