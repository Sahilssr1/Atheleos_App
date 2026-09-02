class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final bool verified;
  final String mediaUrl;
  final List<String> likes;
  final List<String> viewedBy;
  final DateTime createdAt;
  final String? caption;
  final String visibility;

  const StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.verified,
    required this.mediaUrl,
    this.likes = const [],
    this.viewedBy = const [],
    required this.createdAt,
    this.caption,
    this.visibility = 'public',
  });

  bool get isViewed => false; // kept for backwards compatibility if needed, but we'll check viewedBy list

  StoryModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    bool? verified,
    String? mediaUrl,
    List<String>? likes,
    List<String>? viewedBy,
    DateTime? createdAt,
    String? caption,
    String? visibility,
  }) {
    return StoryModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      verified: verified ?? this.verified,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      likes: likes ?? this.likes,
      viewedBy: viewedBy ?? this.viewedBy,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      visibility: visibility ?? this.visibility,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'verified': verified,
      'mediaUrl': mediaUrl,
      'likes': likes,
      'viewedBy': viewedBy,
      'createdAt': createdAt.toIso8601String(),
      'caption': caption,
      'visibility': visibility,
    };
  }

  factory StoryModel.fromMap(Map<String, dynamic> map, String id) {
    // Parse likes safely
    List<String> likesList = [];
    final rawLikes = map['likes'];
    if (rawLikes is List) {
      likesList = rawLikes.map((e) => e.toString()).toList();
    }

    // Parse viewedBy safely
    List<String> viewedByList = [];
    final rawViewedBy = map['viewedBy'];
    if (rawViewedBy is List) {
      viewedByList = rawViewedBy.map((e) => e.toString()).toList();
    }

    // Parse createdAt safely (Timestamp, int, String, etc.)
    DateTime parsedDate = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated != null) {
      if (rawCreated is DateTime) {
        parsedDate = rawCreated;
      } else if (rawCreated.runtimeType.toString().contains('Timestamp')) {
        try {
          parsedDate = (rawCreated as dynamic).toDate();
        } catch (_) {}
      } else if (rawCreated is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
      } else if (rawCreated is String) {
        parsedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
      }
    }

    final rawName = map['userName'] ?? map['username'] ?? map['fullName'] ?? map['name'] ?? map['displayName'] ?? map['userFullName'];
    final rawAvatar = map['userAvatar'] ?? map['avatarUrl'] ?? map['photoUrl'] ?? map['avatar_url'] ?? map['userPhotoUrl'] ?? '';

    return StoryModel(
      id: id,
      userId: (map['userId'] ?? map['uid'] ?? map['authorId'] ?? '').toString(),
      userName: (rawName != null && rawName.toString().trim().isNotEmpty) ? rawName.toString().trim() : 'Athlete',
      userAvatar: rawAvatar.toString(),
      verified: map['verified'] == true || map['isVerified'] == true,
      mediaUrl: (map['mediaUrl'] ?? map['url'] ?? map['imageUrl'] ?? map['videoUrl'] ?? '').toString(),
      likes: likesList,
      viewedBy: viewedByList,
      createdAt: parsedDate,
      caption: map['caption']?.toString() ?? map['content']?.toString(),
      visibility: (map['visibility'] ?? 'public').toString(),
    );
  }
}
