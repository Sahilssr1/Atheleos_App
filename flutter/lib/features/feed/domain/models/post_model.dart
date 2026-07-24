import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/mention_model.dart';

enum PostCategory {
  training,
  match,
  achievement,
  recovery,
  general,
}

class MediaItem {
  final String mediaUrl;
  final String mediaType; // 'image' | 'video'
  final String? thumbnailUrl;
  final String? publicId;
  final int? width;
  final int? height;
  final double? duration;

  const MediaItem({
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    this.publicId,
    this.width,
    this.height,
    this.duration,
  });

  Map<String, dynamic> toMap() {
    return {
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl,
      'publicId': publicId,
      'width': width,
      'height': height,
      'duration': duration,
    };
  }

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      mediaUrl: map['mediaUrl'] as String? ?? '',
      mediaType: map['mediaType'] as String? ?? 'image',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      publicId: map['publicId'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      duration: (map['duration'] as num?)?.toDouble(),
    );
  }
}

class PostModel {
  final String id;
  final String type; // 'post' | 'clip'
  final String userId;
  final String userName;
  final String userAvatar;

  final String sport;
  final String position;

  final bool verified;

  final String content;

  final List<MediaItem> media;

  final PostCategory category;

  final int likes;
  final int commentsCount;
  final int shares;
  final int bookmarks;
  final int views;

  final bool hasLiked;
  final bool hasBookmarked;

  final bool edited;
  final bool deleted;

  final DateTime createdAt;
  final List<MentionModel> mentions;

  /// Whether this post contains any video media.
  /// Used to determine if this post should appear in the Clips/Reels section.
  bool get hasVideo => media.any((m) => m.mediaType == 'video');

  const PostModel({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.sport,
    required this.position,
    required this.verified,
    required this.content,
    required this.media,
    required this.category,
    required this.likes,
    required this.commentsCount,
    required this.shares,
    required this.bookmarks,
    required this.views,
    required this.hasLiked,
    required this.hasBookmarked,
    required this.createdAt,
    this.edited = false,
    this.deleted = false,
    this.mentions = const [],
  });

  PostModel copyWith({
    String? id,
    String? type,
    String? userId,
    String? userName,
    String? userAvatar,
    String? sport,
    String? position,
    bool? verified,
    String? content,
    List<MediaItem>? media,
    PostCategory? category,
    int? likes,
    int? commentsCount,
    int? shares,
    int? bookmarks,
    int? views,
    bool? hasLiked,
    bool? hasBookmarked,
    bool? edited,
    bool? deleted,
    DateTime? createdAt,
    List<MentionModel>? mentions,
  }) {
    return PostModel(
      id: id ?? this.id,
      type: type ?? this.type,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      sport: sport ?? this.sport,
      position: position ?? this.position,
      verified: verified ?? this.verified,
      content: content ?? this.content,
      media: media ?? this.media,
      category: category ?? this.category,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      shares: shares ?? this.shares,
      bookmarks: bookmarks ?? this.bookmarks,
      views: views ?? this.views,
      hasLiked: hasLiked ?? this.hasLiked,
      hasBookmarked: hasBookmarked ?? this.hasBookmarked,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
      mentions: mentions ?? this.mentions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'sport': sport,
      'position': position,
      'verified': verified,
      'content': content,
      'media': media.map((m) => m.toMap()).toList(),
      'category': category.name,
      'likes': likes,
      'commentsCount': commentsCount,
      'shares': shares,
      'bookmarks': bookmarks,
      'views': views,
      'hasLiked': hasLiked,
      'hasBookmarked': hasBookmarked,
      'edited': edited,
      'deleted': deleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'mentions': mentions.map((m) => m.toMap()).toList(),
    };
  }

  static String? _resolveMediaType(String? stored, String? url) {
    if (stored != null) return stored;
    if (url == null || url.isEmpty) return null;
    if (url.contains('/video/upload/') || url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.webm')) {
      return 'video';
    }
    return 'image';
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    // Read media array
    final rawMedia = map['media'] as List?;
    List<MediaItem> mediaList = [];
    if (rawMedia != null && rawMedia.isNotEmpty) {
      mediaList = rawMedia.map((m) => MediaItem.fromMap(Map<String, dynamic>.from(m))).toList();
    } else {
      // Fallback to legacy single mediaUrl fields
      final singleUrl = map['mediaUrl'] as String?;
      if (singleUrl != null && singleUrl.isNotEmpty) {
        mediaList = [
          MediaItem(
            mediaUrl: singleUrl,
            mediaType: _resolveMediaType(map['mediaType'] as String?, singleUrl) ?? 'image',
            thumbnailUrl: map['thumbnailUrl'] as String?,
            publicId: map['publicId'] as String?,
          )
        ];
      }
    }

    // Read mentions
    final rawMentions = map['mentions'] as List?;
    final List<MentionModel> mentionsList = rawMentions != null
        ? rawMentions.map((m) => MentionModel.fromMap(Map<String, dynamic>.from(m))).toList()
        : const [];

    return PostModel(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'post',
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userAvatar: map['userAvatar'] as String? ?? '',
      sport: map['sport'] as String? ?? '',
      position: map['position'] as String? ?? '',
      verified: map['verified'] as bool? ?? false,
      content: map['content'] as String? ?? '',
      media: mediaList,
      category: PostCategory.values.firstWhere(
        (e) => e.name == (map['category'] as String? ?? 'general'),
        orElse: () => PostCategory.general,
      ),
      likes: map['likes'] as int? ?? 0,
      commentsCount: map['commentsCount'] as int? ?? 0,
      shares: map['shares'] as int? ?? 0,
      bookmarks: map['bookmarks'] as int? ?? 0,
      views: map['views'] as int? ?? 0,
      hasLiked: map['hasLiked'] as bool? ?? false,
      hasBookmarked: map['hasBookmarked'] as bool? ?? false,
      edited: map['edited'] as bool? ?? false,
      deleted: map['deleted'] as bool? ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : map['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : DateTime.now(),
      mentions: mentionsList,
    );
  }
}
