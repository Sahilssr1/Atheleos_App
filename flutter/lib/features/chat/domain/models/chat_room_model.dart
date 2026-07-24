class ChatRoom {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final List<String> unreadBy; // User IDs who haven't read the last message

  const ChatRoom({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    this.unreadBy = const [],
  });

  ChatRoom copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    List<String>? unreadBy,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadBy: unreadBy ?? this.unreadBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp.toIso8601String(),
      'unreadBy': unreadBy,
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String id) {
    final rawParticipants = map['participantIds'];
    final participantIds = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : <String>[];

    final rawUnread = map['unreadBy'];
    final unreadBy = rawUnread is List
        ? rawUnread.map((e) => e.toString()).toList()
        : <String>[];

    return ChatRoom(
      id: id,
      participantIds: participantIds,
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: map['lastMessageTimestamp'] != null
          ? DateTime.tryParse(map['lastMessageTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadBy: unreadBy,
    );
  }
}
