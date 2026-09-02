class ChatRoom {
  final String id;
  final List<String> participantIds;
  final String lastMessage;
  final DateTime lastMessageTimestamp;
  final List<String> unreadBy; // User IDs who haven't read the last message
  final String type; // 'one-to-one', 'group'
  final String? name; // Group name
  final String? iconUrl; // Group avatar
  final String? adminId; // Creator / primary admin
  final List<String> adminIds; // All admin IDs
  final String? themeId; // Shared group theme ID
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatRoom({
    required this.id,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageTimestamp,
    this.unreadBy = const [],
    this.type = 'one-to-one',
    this.name,
    this.iconUrl,
    this.adminId,
    this.adminIds = const [],
    this.themeId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isGroup => type == 'group' || id.startsWith('group_');

  ChatRoom copyWith({
    String? id,
    List<String>? participantIds,
    String? lastMessage,
    DateTime? lastMessageTimestamp,
    List<String>? unreadBy,
    String? type,
    String? name,
    String? iconUrl,
    String? adminId,
    List<String>? adminIds,
    String? themeId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      unreadBy: unreadBy ?? this.unreadBy,
      type: type ?? this.type,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      adminId: adminId ?? this.adminId,
      adminIds: adminIds ?? this.adminIds,
      themeId: themeId ?? this.themeId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTimestamp': lastMessageTimestamp.toIso8601String(),
      'unreadBy': unreadBy,
      'type': type,
      if (name != null) 'name': name,
      if (iconUrl != null) 'iconUrl': iconUrl,
      if (adminId != null) 'adminId': adminId,
      'adminIds': adminIds,
      if (themeId != null) 'themeId': themeId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
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

    final rawAdmins = map['adminIds'];
    final adminIds = rawAdmins is List
        ? rawAdmins.map((e) => e.toString()).toList()
        : (map['adminId'] != null ? [map['adminId'].toString()] : <String>[]);

    return ChatRoom(
      id: id,
      participantIds: participantIds,
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTimestamp: map['lastMessageTimestamp'] != null
          ? DateTime.tryParse(map['lastMessageTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      unreadBy: unreadBy,
      type: map['type'] ?? (id.startsWith('group_') ? 'group' : 'one-to-one'),
      name: map['name'] as String?,
      iconUrl: map['iconUrl'] as String?,
      adminId: map['adminId'] as String?,
      adminIds: adminIds,
      themeId: map['themeId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
