class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final String? storyMediaUrl;
  final String? storyId;
  final Map<String, String> reactions; // key: userId, value: emoji character

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.storyMediaUrl,
    this.storyId,
    this.reactions = const {},
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    DateTime? timestamp,
    String? storyMediaUrl,
    String? storyId,
    Map<String, String>? reactions,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      storyMediaUrl: storyMediaUrl ?? this.storyMediaUrl,
      storyId: storyId ?? this.storyId,
      reactions: reactions ?? this.reactions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'storyMediaUrl': storyMediaUrl,
      'storyId': storyId,
      'reactions': reactions,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    // Safely parse reactions map
    final rawReactions = map['reactions'];
    final parsedReactions = <String, String>{};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        parsedReactions[key.toString()] = value.toString();
      });
    }

    return ChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      storyMediaUrl: map['storyMediaUrl'],
      storyId: map['storyId'],
      reactions: parsedReactions,
    );
  }
}
