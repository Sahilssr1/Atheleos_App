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
      likedList = rawLikedBy.map((e) => e.toString()).toList();
    }

    final rawMentions = map['mentions'] as List?;
    final List<MentionModel> mentionsList = rawMentions != null
        ? rawMentions.map((m) => MentionModel.fromMap(Map<String, dynamic>.from(m))).toList()
        : const [];

    DateTime resolvedDate = DateTime.now();
    final rawCreated = map['createdAt'];
    if (rawCreated != null) {
      if (rawCreated is DateTime) {
        resolvedDate = rawCreated;
      } else if (rawCreated is Timestamp) {
        resolvedDate = rawCreated.toDate();
      } else if (rawCreated.runtimeType.toString().contains('Timestamp')) {
        try {
          resolvedDate = (rawCreated as dynamic).toDate();
        } catch (_) {}
      } else if (rawCreated is int) {
        resolvedDate = DateTime.fromMillisecondsSinceEpoch(rawCreated);
      } else if (rawCreated is String) {
        resolvedDate = DateTime.tryParse(rawCreated) ?? DateTime.now();
      }
    }

    final rawName = map['username'] ?? map['userName'] ?? map['fullName'] ?? map['name'] ?? map['displayName'] ?? map['userFullName'];
    final rawAvatar = map['profileImage'] ?? map['userAvatar'] ?? map['avatarUrl'] ?? map['photoUrl'] ?? map['avatar_url'] ?? '';

    return CommentModel(
      commentId: id,
      postId: (map['postId'] ?? '').toString(),
      userId: (map['userId'] ?? map['uid'] ?? '').toString(),
      username: (rawName != null && rawName.toString().trim().isNotEmpty) ? rawName.toString().trim() : 'Athlete',
      profileImage: rawAvatar.toString(),
      verified: map['verified'] == true || map['isVerified'] == true,
      text: (map['text'] ?? map['content'] ?? '').toString(),
      createdAt: resolvedDate,
      likesCount: (map['likesCount'] as int?) ?? (map['likes'] as int?) ?? likedList.length,
      replyCount: (map['replyCount'] as int?) ?? 0,
      edited: map['edited'] == true,
      parentId: map['parentId']?.toString(),
      likedBy: likedList,
      mentions: mentionsList,
    );
  }
}
