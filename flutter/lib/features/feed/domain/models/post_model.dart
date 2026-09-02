import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    this.edited = false,
    this.deleted = false,
    required this.createdAt,
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
      'likeCount': likes,
      'commentsCount': commentsCount,
      'commentCount': commentsCount,
      'shares': shares,
      'bookmarks': bookmarks,
      'bookmarkCount': bookmarks,
      'bookmarkedBy': <String>[],
      'views': views,
      'hasLiked': hasLiked,
      'hasBookmarked': hasBookmarked,
      'edited': edited,
      'deleted': deleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'mentions': mentions.map((m) => m.toMap()).toList(),
    };
  }

  static int _parseInt(dynamic val, [int fallback = 0]) {
    if (val == null) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? fallback;
    return fallback;
  }

  static String? _resolveMediaType(String? stored, String? url) {
    if (stored != null) return stored;
    if (url == null || url.isEmpty) return null;
    if (url.contains('/video/upload/') || url.endsWith('.mp4') || url.endsWith('.mov') || url.endsWith('.webm')) {
      return 'video';
    }
    return 'image';
  }

  factory PostModel.fromMap(Map<String, dynamic> map, {String? currentUserId}) {
    // Read media array
    final rawMedia = map['media'] as List?;
    List<MediaItem> mediaList = [];
    if (rawMedia != null && rawMedia.isNotEmpty) {
      mediaList = rawMedia.map((m) => MediaItem.fromMap(Map<String, dynamic>.from(m))).toList();
    } else {
      // Fallback to legacy single mediaUrl fields or root image/video fields
      final singleUrl = (map['mediaUrl'] ?? map['url'] ?? map['imageUrl'] ?? map['videoUrl']) as String?;
      if (singleUrl != null && singleUrl.isNotEmpty) {
        mediaList = [
          MediaItem(
            mediaUrl: singleUrl,
            mediaType: _resolveMediaType((map['mediaType'] ?? map['media_type']) as String?, singleUrl) ?? 'image',
            thumbnailUrl: (map['thumbnailUrl'] ?? map['thumbUrl'] ?? map['thumbnail_url']) as String?,
            publicId: (map['publicId'] ?? map['public_id'] ?? map['id']) as String?,
          )
        ];
      }
    }

    // Read mentions
    final rawMentions = map['mentions'] as List?;
    final List<MentionModel> mentionsList = rawMentions != null
        ? rawMentions.map((m) => MentionModel.fromMap(Map<String, dynamic>.from(m))).toList()
        : const [];

    // Author fields with rich fallback for mobile and web schemas
    final rawName = map['userName'] ?? map['username'] ?? map['fullName'] ?? map['name'] ?? map['displayName'] ?? map['userFullName'];
    final String resolvedUserName = (rawName != null && rawName.toString().trim().isNotEmpty)
        ? rawName.toString().trim()
        : 'Athlete';

    final rawAvatar = map['userAvatar'] ?? map['avatarUrl'] ?? map['photoUrl'] ?? map['avatar_url'] ?? map['userPhotoUrl'] ?? '';
    final String resolvedAvatar = rawAvatar.toString();

    final rawContent = map['content'] ?? map['caption'] ?? map['text'] ?? map['title'] ?? '';

    // Bookmarks calculation
    final rawBookmarkedBy = map['bookmarkedBy'];
    final List<String> bookmarkedByList = rawBookmarkedBy is List
        ? rawBookmarkedBy.map((e) => e.toString()).toList()
        : <String>[];

    final int resolvedLikes = _parseInt(
      map['likes'] ?? map['likeCount'],
      0,
    );

    final int resolvedComments = _parseInt(
      map['commentsCount'] ?? map['commentCount'],
      0,
    );

    final int resolvedBookmarks = _parseInt(
      map['bookmarks'] ?? map['bookmarkCount'],
      bookmarkedByList.length,
    );

    final int resolvedShares = _parseInt(map['shares'], 0);
    final int resolvedViews = _parseInt(map['views'], 0);

    final effectiveUid = (currentUserId != null && currentUserId.isNotEmpty)
        ? currentUserId
        : FirebaseAuth.instance.currentUser?.uid;

    final bool resolvedHasLiked = map['hasLiked'] == true;

    final bool resolvedHasBookmarked = (effectiveUid != null && effectiveUid.isNotEmpty && bookmarkedByList.contains(effectiveUid))
        || (map['hasBookmarked'] == true);

    // Parse createdAt safely
    DateTime resolvedCreatedAt = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated != null) {
      if (rawCreated is DateTime) {
        resolvedCreatedAt = rawCreated;
      } else if (rawCreated is Timestamp) {
        resolvedCreatedAt = rawCreated.toDate();
      } else if (rawCreated.runtimeType.toString().contains('Timestamp')) {
        try {
          resolvedCreatedAt = (rawCreated as dynamic).toDate();
        } catch (_) {}
      } else if (rawCreated is int) {
        resolvedCreatedAt = DateTime.fromMillisecondsSinceEpoch(rawCreated);
      } else if (rawCreated is String) {
        resolvedCreatedAt = DateTime.tryParse(rawCreated) ?? DateTime.now();
      }
    }

    return PostModel(
      id: map['id']?.toString() ?? '',
      type: (map['type'] ?? 'post').toString(),
      userId: (map['userId'] ?? map['uid'] ?? map['authorId'] ?? '').toString(),
      userName: resolvedUserName,
      userAvatar: resolvedAvatar,
      sport: (map['sport'] ?? map['sportCategory'] ?? 'Athletic').toString(),
      position: (map['position'] ?? map['primaryPosition'] ?? 'Athlete').toString(),
      verified: map['verified'] == true || map['isVerified'] == true,
      content: rawContent.toString(),
      media: mediaList,
      category: PostCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == (map['category']?.toString().toLowerCase() ?? 'general'),
        orElse: () => PostCategory.general,
      ),
      likes: resolvedLikes,
      commentsCount: resolvedComments,
      shares: resolvedShares,
      bookmarks: resolvedBookmarks,
      views: resolvedViews,
      hasLiked: resolvedHasLiked,
      hasBookmarked: resolvedHasBookmarked,
      edited: map['edited'] == true,
      deleted: map['deleted'] == true,
      createdAt: resolvedCreatedAt,
      mentions: mentionsList,
    );
  }
}
