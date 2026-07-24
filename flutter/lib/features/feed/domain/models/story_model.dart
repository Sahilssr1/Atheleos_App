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
    return StoryModel(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'] ?? '',
      verified: map['verified'] ?? false,
      mediaUrl: map['mediaUrl'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      caption: map['caption'],
      visibility: map['visibility'] ?? 'public',
    );
  }
}
