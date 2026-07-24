import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/mention_model.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String userId;
  final String username;
  final String profileImage;
  final bool verified;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final int replyCount;
  final bool edited;
  final String? parentId; 
  final List<String> likedBy; 
  final List<MentionModel> mentions;

  const CommentModel({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.username,
    required this.profileImage,
    required this.verified,
    required this.text,
    required this.createdAt,
    this.likesCount = 0,
    this.replyCount = 0,
    this.edited = false,
    this.parentId,
    this.likedBy = const [],
    this.mentions = const [],
  });

  CommentModel copyWith({
    String? commentId,
    String? postId,
    String? userId,
    String? username,
    String? profileImage,
    bool? verified,
    String? text,
    DateTime? createdAt,
    int? likesCount,
    int? replyCount,
    bool? edited,
    String? parentId,
    List<String>? likedBy,
    List<MentionModel>? mentions,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      profileImage: profileImage ?? this.profileImage,
      verified: verified ?? this.verified,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      replyCount: replyCount ?? this.replyCount,
      edited: edited ?? this.edited,
      parentId: parentId ?? this.parentId,
      likedBy: likedBy ?? this.likedBy,
      mentions: mentions ?? this.mentions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'userId': userId,
      'username': username,
      'profileImage': profileImage,
      'verified': verified,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'replyCount': replyCount,
      'edited': edited,
      'parentId': parentId,
      'likedBy': likedBy,
      'mentions': mentions.map((m) => m.toMap()).toList(),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    final rawLikedBy = map['likedBy'];
    List<String> likedList = [];
    if (rawLikedBy is List) {
      likedList = List<String>.from(rawLikedBy);
    }

    final rawMentions = map['mentions'] as List?;
    final List<MentionModel> mentionsList = rawMentions != null
        ? rawMentions.map((m) => MentionModel.fromMap(Map<String, dynamic>.from(m))).toList()
        : const [];
    
    return CommentModel(
      commentId: id,
      postId: map['postId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      username: map['username'] as String? ?? '',
      profileImage: map['profileImage'] as String? ?? '',
      verified: map['verified'] as bool? ?? false,
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int? ?? DateTime.now().millisecondsSinceEpoch),
      likesCount: map['likesCount'] as int? ?? 0,
      replyCount: map['replyCount'] as int? ?? 0,
      edited: map['edited'] as bool? ?? false,
      parentId: map['parentId'] as String?,
      likedBy: likedList,
      mentions: mentionsList,
    );
  }
}
