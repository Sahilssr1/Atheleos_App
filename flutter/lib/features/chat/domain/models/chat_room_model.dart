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
  final String? initiatorId; // User who initiated the conversation
  final List<String> repliedUserIds; // User IDs who have replied/sent at least 1 message
  final String? lastSenderId; // User ID who sent the latest message
  final String? requestFor; // Explicit target user ID for pending message requests
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
    this.initiatorId,
    this.repliedUserIds = const [],
    this.lastSenderId,
    this.requestFor,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isGroup => type == 'group' || id.startsWith('group_');

  /// Returns true if this conversation is an unreplied incoming message request for [userId].
  ///
  /// Criteria:
  /// 1. Must NOT be a group chat.
  /// 2. User must be a participant.
  /// 3. User is NOT the one who initiated the conversation.
  /// 4. User has NOT replied yet (not in [repliedUserIds]).
  /// 5. Another participant has sent messages (or room was marked as requestFor [userId]).
  bool isMessageRequestFor(String userId) {
    if (isGroup) return false;
    if (!participantIds.contains(userId)) return false;
    if (initiatorId != null && initiatorId == userId) return false;
    if (repliedUserIds.contains(userId)) return false;
    if (repliedUserIds.isNotEmpty && !repliedUserIds.contains(userId)) return true;
    if (requestFor != null && requestFor == userId) return true;
    return false;
  }

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
    String? initiatorId,
    List<String>? repliedUserIds,
    String? lastSenderId,
    String? requestFor,
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
      initiatorId: initiatorId ?? this.initiatorId,
      repliedUserIds: repliedUserIds ?? this.repliedUserIds,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      requestFor: requestFor ?? this.requestFor,
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
      if (initiatorId != null) 'initiatorId': initiatorId,
      'repliedUserIds': repliedUserIds,
      if (lastSenderId != null) 'lastSenderId': lastSenderId,
      if (requestFor != null) 'requestFor': requestFor,
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

    final rawReplied = map['repliedUserIds'];
    final repliedUserIds = rawReplied is List
        ? rawReplied.map((e) => e.toString()).toList()
        : <String>[];

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
      initiatorId: map['initiatorId'] as String?,
      repliedUserIds: repliedUserIds,
      lastSenderId: map['lastSenderId'] as String?,
      requestFor: map['requestFor'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
