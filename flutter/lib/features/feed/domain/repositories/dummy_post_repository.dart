import '../../domain/models/post_model.dart';
import '../../domain/repositories/post_repository.dart';

class DummyPostRepository implements PostRepository {
  final List<PostModel> _postsCache = [
    PostModel(
      id: 'post_1',
      type: 'post',
      userId: 'user_1',
      userName: 'Tyler Brooks',
      userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Football',
      position: 'Quarterback',
      verified: true,
      content: 'Massive victory tonight! 🏈 Put up 380 passing yards and 4 touchdowns to secure our spot in the State Semifinals. This team has put in endless hours on and off the field, and it\'s paying off. Huge shoutout to my offensive line for keeping me clean all night. Film session starts tomorrow morning. Let\'s keep climbing! #StateRun #AtheleosAthletes',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 312,
      commentsCount: 45,
      shares: 28,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 5, 10),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_2',
      type: 'post',
      userId: 'user_2',
      userName: 'Sarah Jenkins',
      userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Soccer',
      position: 'Forward',
      verified: true,
      content: 'Unbelievable feeling scoring the match-winner in the 89th minute! ⚽️ The atmosphere was electric. This victory moves us into the top spot of the division. Hard work, grit, and trust in each other got us this result. Time to recover and focus on the next opponent. #StrikerMindset #AtheleosFamily',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 245,
      commentsCount: 32,
      shares: 14,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 5, 8),
      hasLiked: true,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_3',
      type: 'post',
      userId: 'user_3',
      userName: 'Marcus Thompson',
      userAvatar: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Basketball',
      position: 'Point Guard',
      verified: false,
      content: 'Early morning grind. 🏀 Focusing on off-the-dribble mid-range pull-ups and lateral quickness drills today. Made 500 shots before breakfast. The formula is simple: put in the work when nobody is watching. College scouts, full game films are updated on my Atheleos profile! #ClassOf2027 #HardWorkPaysOff',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.training,
      likes: 189,
      commentsCount: 21,
      shares: 11,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 5, 7),
      hasLiked: false,
      hasBookmarked: true,
    ),
    PostModel(
      id: 'post_4',
      type: 'post',
      userId: 'user_4',
      userName: 'Elena Rostova',
      userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Athletics',
      position: 'Sprinter',
      verified: true,
      content: 'Finally broke my personal record in the 100m sprint today with a time of 11.24s! 🏃‍♀️💨 Every millisecond counts. Thank you to my coach, family, and training partners for pushing me past my limits. This is only the beginning. The Olympic trials are within reach. #Sprinter #TrackAndField',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.achievement,
      likes: 520,
      commentsCount: 78,
      shares: 62,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 5, 4),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_5',
      type: 'post',
      userId: 'user_5',
      userName: 'Rohit Sharma',
      userAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Cricket',
      position: 'Opening Batsman',
      verified: true,
      content: 'Incredible feeling to score a century under lights in front of a packed stadium! 🏏 Standard was extremely high, but the partnership with our middle order kept us ahead. This win is for the fans who supported us through every ball. We keep building from here. #Century #TeamIndia #CricketLovers',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 890,
      commentsCount: 154,
      shares: 120,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 5, 0),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_6',
      type: 'post',
      userId: 'user_6',
      userName: 'Michael Phelps',
      userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Swimming',
      position: 'Butterfly',
      verified: true,
      content: 'Nothing compares to the quiet focus of the pool at 5 AM. 🏊‍♂️ Heavy yardage block today focusing on underwater kicks and maintaining streamline under extreme fatigue. Recovering with high protein meal and compression gear. Your only limit is you. #SwimLife #OlympicsJourney',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1519315901367-f34ff9154487?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.training,
      likes: 412,
      commentsCount: 39,
      shares: 15,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 4, 22),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_7',
      type: 'post',
      userId: 'user_7',
      userName: 'Emma Watson',
      userAvatar: 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Tennis',
      position: 'Singles',
      verified: true,
      content: 'Tough three-setter battle today, but we secured the spot in the Quarterfinals! 🎾 The courts were fast and hot, requiring full focus. Credit to my opponent for an amazing match. Time to rehydrate, jump in the ice bath, and prepare for tomorrow. Let\'s go! #Tennis #WTA #ClayCourt',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 340,
      commentsCount: 26,
      shares: 8,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 4, 12),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_8',
      type: 'post',
      userId: 'user_8',
      userName: 'Anya Petrova',
      userAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Volleyball',
      position: 'Setter',
      verified: false,
      content: 'Perfecting the connection with my middle blockers. 🏐 Quick tempo sets require precision and split-second decision-making. Video analysis showed some great progress. Getting ready for our big conference tournament this weekend! #SetterLife #Volleyball #TeamSport',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1592656094267-764a45157575?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.training,
      likes: 156,
      commentsCount: 12,
      shares: 4,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 4, 9),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_9',
      type: 'post',
      userId: 'user_9',
      userName: 'Yuki Tanaka',
      userAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Badminton',
      position: 'Singles',
      verified: true,
      content: 'First Place at the National Junior Badminton Championships! 🏸🏆 Words cannot describe how grateful I am. Countless hours of shuttle drills, footwork exercises, and fitness tests led to this moment. Ready to transition to the senior circuit next season! #Champion #Badminton #NeverGiveUp',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1626224583764-f87db24ac4ea?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.achievement,
      likes: 670,
      commentsCount: 95,
      shares: 42,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 3, 14),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_10',
      type: 'post',
      userId: 'user_10',
      userName: 'Jordan Bell',
      userAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Basketball',
      position: 'Forward',
      verified: true,
      content: 'Crucial recovery day after a grueling double-overtime win. 🧊🔋 Ice baths, hyperbaric chamber, and active stretching are key to longevity. Listening to your body is just as important as pushing it. Ready to go for the finals on Friday! #ActiveRecovery #AthleteWellness #RestAndRefuel',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.recovery,
      likes: 210,
      commentsCount: 18,
      shares: 5,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 3, 8),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_11',
      type: 'post',
      userId: 'user_1',
      userName: 'Tyler Brooks',
      userAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Football',
      position: 'Quarterback',
      verified: true,
      content: 'Focusing heavily on mechanics today. 🏈 Keeping my base solid, hitching properly, and releasing the ball at the highest point. Minor adjustments yield massive improvements in accuracy downfield. Hard work is non-negotiable. #Mechanics #QBDrills #AtheleosFootball',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1568194157720-8eae29934b3a?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.training,
      likes: 198,
      commentsCount: 14,
      shares: 7,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 2, 16),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_12',
      type: 'post',
      userId: 'user_11',
      userName: 'Sana Mir',
      userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Cricket',
      position: 'All-Rounder',
      verified: true,
      content: 'Extremely proud of the squad\'s performance in the regional championship! 🏆🏏 Grateful to be named Player of the Tournament. It represents all the early mornings and late-night nets. To all young girls wanting to play cricket: follow your dreams, work hard, and never doubt your power. #WomenInSports #Cricket',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1608248597279-f99d160bfcbc?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.achievement,
      likes: 512,
      commentsCount: 68,
      shares: 34,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 2, 10),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_13',
      type: 'post',
      userId: 'user_12',
      userName: 'Sophia Lind',
      userAvatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Swimming',
      position: 'Freestyle',
      verified: false,
      content: 'New personal best in the 200m Freestyle! 🏊‍♀️💨 Clocked in at 1:55.82 today. Shaving off even 0.2 seconds feels like a monumental task, but consistent pacing and tight turns did the job. Time to analyze the video and look for the next millisecond. #SwimmerLife #PersonalBest',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1530541930197-ff16ac917b0e?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 278,
      commentsCount: 31,
      shares: 12,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 1, 18),
      hasLiked: false,
      hasBookmarked: false,
    ),
    PostModel(
      id: 'post_14',
      type: 'post',
      userId: 'user_13',
      userName: 'Alex Rivera',
      userAvatar: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200&h=200',
      sport: 'Volleyball',
      position: 'Libero',
      verified: true,
      content: '26 digs in tonight\'s 5-set nailbiter! 🏐 Defending the backcourt is all about reading the hitter\'s shoulders and having zero fear of hitting the floor. Our hitters did an outstanding job converting transitions. Massive crowd support tonight, thank you! #Libero #VolleyballDefense #Grind',
      media: [
        MediaItem(
          mediaUrl: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?auto=format&fit=crop&q=80&w=800',
          mediaType: 'image',
        ),
      ],
      category: PostCategory.match,
      likes: 224,
      commentsCount: 19,
      shares: 8,
      bookmarks: 0,
      views: 0,
      createdAt: DateTime(2026, 7, 1, 12),
      hasLiked: false,
      hasBookmarked: false,
    ),
  ];

  @override
  Future<List<PostModel>> getPosts({String? currentUserId, int limit = 12}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _postsCache.take(limit).toList();
  }

  @override
  Future<List<PostModel>> getPostsByCategory(String category, {String? currentUserId, int limit = 12}) async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (category == 'All') {
      return _postsCache.take(limit).toList();
    }
    return _postsCache
        .where((post) => post.category.name.toLowerCase() == category.toLowerCase())
        .take(limit)
        .toList();
  }

  @override
  Stream<List<PostModel>> watchPosts({String? currentUserId, int limit = 12}) {
    return Stream.value(_postsCache.take(limit).toList());
  }

  @override
  Stream<List<PostModel>> watchPostsByCategory(String category, {String? currentUserId, int limit = 12}) {
    if (category == 'All') {
      return Stream.value(_postsCache.take(limit).toList());
    }
    return Stream.value(
      _postsCache
          .where((p) => p.category.name.toLowerCase() == category.toLowerCase())
          .take(limit)
          .toList(),
    );
  }

  @override
  Stream<List<PostModel>> watchPostsFiltered({
    required String category,
    required String sport,
    required String sortBy,
    String? currentUserId,
    int limit = 12,
  }) {
    var result = List<PostModel>.from(_postsCache);
    if (category != 'All') {
      result = result.where((p) => p.category.name.toLowerCase() == category.toLowerCase()).toList();
    }
    if (sport != 'All') {
      result = result.where((p) => p.sport == sport).toList();
    }
    if (sortBy == 'Trending') {
      result.sort((a, b) => b.likes.compareTo(a.likes));
    } else {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return Stream.value(result.take(limit).toList());
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
    List<PostModel> result = List.from(_postsCache);
    if (category != 'All') {
      result = result.where((p) => p.category.name.toLowerCase() == category.toLowerCase()).toList();
    }
    if (sport != 'All') {
      result = result.where((p) => p.sport == sport).toList();
    }
    if (sortBy == 'Trending') {
      result.sort((a, b) => b.likes.compareTo(a.likes));
    } else {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    int startIndex = 0;
    if (lastPostId != null && lastPostId.isNotEmpty) {
      final index = result.indexWhere((p) => p.id == lastPostId);
      if (index != -1) {
        startIndex = index + 1;
      }
    }

    if (startIndex >= result.length) {
      return [];
    }

    return result.sublist(startIndex).take(limit).toList();
  }

  @override
  Future<void> likePost(String postId, bool like) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      final newLikes = post.likes + (like ? 1 : -1);
      _postsCache[index] = post.copyWith(hasLiked: like, likes: newLikes);
    }
  }

  @override
  Future<void> togglePostLike(String postId, String userId, {bool? targetLiked}) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      final bool newLiked = targetLiked ?? !post.hasLiked;
      final int newLikes = newLiked
          ? (post.hasLiked ? post.likes : post.likes + 1)
          : (post.hasLiked ? (post.likes - 1).clamp(0, 9999999) : post.likes);
      _postsCache[index] = post.copyWith(
        hasLiked: newLiked,
        likes: newLikes,
      );
    }
  }

  @override
  Future<void> toggleBookmark(String postId, bool bookmark) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      _postsCache[index] = post.copyWith(hasBookmarked: bookmark);
    }
  }

  @override
  Future<void> togglePostBookmark(String postId, String userId) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      _postsCache[index] = post.copyWith(hasBookmarked: !post.hasBookmarked);
    }
  }

  @override
  Future<void> createPost(PostModel post) async {
    _postsCache.insert(0, post);
  }

  @override
  Future<void> deletePost(PostModel post) async {
    _postsCache.removeWhere((p) => p.id == post.id);
  }

  @override
  Future<void> incrementShareCount(String postId) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      _postsCache[index] = post.copyWith(shares: post.shares + 1);
    }
  }

  @override
  Future<void> incrementViewCount(String postId) async {
    final index = _postsCache.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _postsCache[index];
      _postsCache[index] = post.copyWith(views: post.views + 1);
    }
  }
}
