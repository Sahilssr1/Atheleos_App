class MentionModel {
  final String uid;
  final String username;

  const MentionModel({
    required this.uid,
    required this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
    };
  }

  factory MentionModel.fromMap(Map<String, dynamic> map) {
    return MentionModel(
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentionModel &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          username == other.username;

  @override
  int get hashCode => uid.hashCode ^ username.hashCode;
}
