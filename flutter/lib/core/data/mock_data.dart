import '../../features/feed/domain/models/post_model.dart';

/// Sample data used as a fallback when the Firestore collections are empty.
/// Uses Google's public test videos and Unsplash sport images so playback works
/// on every device without any backend setup.

const _v1 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
const _v2 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4';
const _v3 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnTheRoadAgain.mp4';
const _v4 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4';
const _v5 = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WhatCarCanYouGetForAGrand.mp4';

const _t1 = 'https://images.unsplash.com/photo-1519861531473-9200262188bf?auto=format&fit=crop&w=800&q=80';
const _t2 = 'https://images.unsplash.com/photo-1560272564-c83b66b1ad12?auto=format&fit=crop&w=800&q=80';
const _t3 = 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80';
const _t4 = 'https://images.unsplash.com/photo-1543326727-cf6c39e8f84c?auto=format&fit=crop&w=800&q=80';
const _t5 = 'https://images.unsplash.com/photo-1540539234-c14a20fb7c7b?auto=format&fit=crop&w=800&q=80';

const _a1 = 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=150&q=80';
const _a2 = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=150&q=80';
const _a3 = 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80';
const _a4 = 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=150&q=80';
const _a5 = 'https://images.unsplash.com/photo-1463453091185-61582044d556?auto=format&fit=crop&w=150&q=80';

final List<PostModel> mockClips = [
  PostModel(
    id: 'mock_clip_1',
    type: 'clip',
    content: 'Early morning sprint drills – pace is everything',
    userName: 'Jordan Vance',
    userId: 'mock_user_1',
    userAvatar: _a1,
    verified: true,
    sport: 'Athletics',
    position: 'Sprinter',
    views: 8200,
    likes: 412,
    hasLiked: false,
    hasBookmarked: false,
    category: PostCategory.general,
    media: [
      const MediaItem(
        mediaUrl: _v1,
        mediaType: 'video',
        thumbnailUrl: _t5,
        publicId: 'mock_clip_1',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    commentsCount: 34,
    shares: 12,
    bookmarks: 0,
  ),
  PostModel(
    id: 'mock_clip_2',
    type: 'clip',
    content: 'Footwork routine that changed my game',
    userName: 'Priya Sharma',
    userId: 'mock_user_2',
    userAvatar: _a3,
    verified: true,
    sport: 'Basketball',
    position: 'Point Guard',
    views: 14500,
    likes: 891,
    hasLiked: false,
    hasBookmarked: false,
    category: PostCategory.general,
    media: [
      const MediaItem(
        mediaUrl: _v2,
        mediaType: 'video',
        thumbnailUrl: _t1,
        publicId: 'mock_clip_2',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 8)),
    commentsCount: 67,
    shares: 29,
    bookmarks: 0,
  ),
  PostModel(
    id: 'mock_clip_3',
    type: 'clip',
    content: 'Full-body strength session – off-season prep',
    userName: 'Marcus Osei',
    userId: 'mock_user_3',
    userAvatar: _a2,
    verified: false,
    sport: 'Football',
    position: 'Centre-Back',
    views: 6100,
    likes: 278,
    hasLiked: false,
    hasBookmarked: false,
    category: PostCategory.general,
    media: [
      const MediaItem(
        mediaUrl: _v3,
        mediaType: 'video',
        thumbnailUrl: _t3,
        publicId: 'mock_clip_3',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 14)),
    commentsCount: 22,
    shares: 8,
    bookmarks: 0,
  ),
  PostModel(
    id: 'mock_clip_4',
    type: 'clip',
    content: 'Pool recovery – why cold-water therapy works',
    userName: 'Anika Reyes',
    userId: 'mock_user_4',
    userAvatar: _a4,
    verified: true,
    sport: 'Swimming',
    position: 'Freestyle',
    views: 3900,
    likes: 195,
    hasLiked: false,
    hasBookmarked: false,
    category: PostCategory.general,
    media: [
      const MediaItem(
        mediaUrl: _v4,
        mediaType: 'video',
        thumbnailUrl: _t4,
        publicId: 'mock_clip_4',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    commentsCount: 15,
    shares: 5,
    bookmarks: 0,
  ),
  PostModel(
    id: 'mock_clip_5',
    type: 'clip',
    content: 'Match highlights – regional quarter-final',
    userName: 'Devon Carr',
    userId: 'mock_user_5',
    userAvatar: _a5,
    verified: false,
    sport: 'Football',
    position: 'Winger',
    views: 22300,
    likes: 1432,
    hasLiked: false,
    hasBookmarked: false,
    category: PostCategory.general,
    media: [
      const MediaItem(
        mediaUrl: _v5,
        mediaType: 'video',
        thumbnailUrl: _t2,
        publicId: 'mock_clip_5',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    commentsCount: 118,
    shares: 74,
    bookmarks: 0,
  ),
];

final List<PostModel> mockPosts = [
  PostModel(
    id: 'mock_post_1',
    type: 'post',
    userId: 'mock_user_1',
    userName: 'Jordan Vance',
    userAvatar: _a1,
    sport: 'Athletics',
    position: 'Sprinter',
    verified: true,
    content:
        'Just wrapped up a personal-best 100 m in training — 10.42 s. The work is paying off. Consistency beats intensity every single day. 🏃‍♂️',
    category: PostCategory.training,
    likes: 324,
    commentsCount: 28,
    shares: 14,
    bookmarks: 9,
    views: 1850,
    hasLiked: false,
    hasBookmarked: false,
    media: [
      const MediaItem(
        mediaUrl: _v1,
        mediaType: 'video',
        thumbnailUrl: _t5,
        publicId: 'mock_post_1',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  PostModel(
    id: 'mock_post_2',
    type: 'post',
    userId: 'mock_user_2',
    userName: 'Priya Sharma',
    userAvatar: _a3,
    sport: 'Basketball',
    position: 'Point Guard',
    verified: true,
    content:
        'Footwork is the foundation. Before you focus on shooting or handles, lock in your footwork. Spent 45 min purely on jab-steps today.',
    category: PostCategory.training,
    likes: 512,
    commentsCount: 45,
    shares: 21,
    bookmarks: 17,
    views: 2900,
    hasLiked: false,
    hasBookmarked: false,
    media: [
      const MediaItem(
        mediaUrl: _t1,
        mediaType: 'image',
        publicId: 'mock_post_2',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  PostModel(
    id: 'mock_post_3',
    type: 'post',
    userId: 'mock_user_3',
    userName: 'Marcus Osei',
    userAvatar: _a2,
    sport: 'Football',
    position: 'Centre-Back',
    verified: false,
    content:
        'Off-season strength block complete. 12 weeks of hard work in the gym. Coming back bigger, faster, and harder to beat. 💪',
    category: PostCategory.achievement,
    likes: 687,
    commentsCount: 59,
    shares: 33,
    bookmarks: 22,
    views: 4100,
    hasLiked: false,
    hasBookmarked: false,
    media: [
      const MediaItem(
        mediaUrl: _v2,
        mediaType: 'video',
        thumbnailUrl: _t3,
        publicId: 'mock_post_3',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 10)),
  ),
  PostModel(
    id: 'mock_post_4',
    type: 'post',
    userId: 'mock_user_4',
    userName: 'Anika Reyes',
    userAvatar: _a4,
    sport: 'Swimming',
    position: 'Freestyle',
    verified: true,
    content:
        'Recovery day. Ice bath + pool floats + stretching. You can\'t build on a broken foundation — rest is training.',
    category: PostCategory.recovery,
    likes: 203,
    commentsCount: 17,
    shares: 6,
    bookmarks: 8,
    views: 1200,
    hasLiked: false,
    hasBookmarked: false,
    media: [
      const MediaItem(
        mediaUrl: _t4,
        mediaType: 'image',
        publicId: 'mock_post_4',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(hours: 18)),
  ),
  PostModel(
    id: 'mock_post_5',
    type: 'post',
    userId: 'mock_user_5',
    userName: 'Devon Carr',
    userAvatar: _a5,
    sport: 'Football',
    position: 'Winger',
    verified: false,
    content:
        'Buzzer-beater finish in the regional quarter-final. This team never gives up. One more game to the final. 🔥',
    category: PostCategory.match,
    likes: 1204,
    commentsCount: 94,
    shares: 61,
    bookmarks: 43,
    views: 8700,
    hasLiked: false,
    hasBookmarked: false,
    media: [
      const MediaItem(
        mediaUrl: _v3,
        mediaType: 'video',
        thumbnailUrl: _t2,
        publicId: 'mock_post_5',
      )
    ],
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];
