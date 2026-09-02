import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/messaging_access_service.dart';
import '../../../notifications/data/notification_service.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_room_model.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MessagingAccessService _messagingAccess = MessagingAccessService();

  String _getRoomId(String user1, String user2) {
    final list = [user1, user2]..sort();
    return list.join('_');
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String user1, String user2, {int? limit}) {
    final roomId = _getRoomId(user1, user2);
    return watchRoomMessages(roomId, limit: limit);
  }

  @override
  Future<List<ChatMessage>> getCachedRoomMessages(String roomId, {int? limit}) async {
    try {
      var query = _firestore
          .collection('chats')
          .doc(roomId)
          .collection('messages')
          .orderBy('timestamp', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get(const GetOptions(source: Source.cache));
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
      return messages.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<ChatMessage>> watchRoomMessages(String roomId, {int? limit}) {
    var query = _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots(includeMetadataChanges: true).map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
      return messages.reversed.toList();
    });
  }

  @override
  Future<List<ChatMessage>> getOlderRoomMessages(String roomId, DateTime beforeTimestamp, int limit) async {
    final snapshot = await _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfter([beforeTimestamp.toIso8601String()])
        .limit(limit)
        .get();

    final messages = snapshot.docs
        .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
        .toList();
    return messages.reversed.toList();
  }

  @override
  Stream<ChatRoom?> watchRoom(String roomId) {
    return _firestore.collection('chats').doc(roomId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ChatRoom.fromMap(snap.data()!, snap.id);
    });
  }

  @override
  Future<void> sendMessage(ChatMessage message) async {
    final roomId = _getRoomId(message.senderId, message.receiverId);
    final access = await _messagingAccess.check(
      senderId: message.senderId,
      receiverId: message.receiverId,
    );
    if (!access.allowed) {
      throw StateError(access.reason ?? 'This message cannot be sent.');
    }

    final roomRef = _firestore.collection('chats').doc(roomId);
    final messageRef = roomRef.collection('messages').doc(message.id);
    final batch = _firestore.batch();
    batch.set(
        roomRef,
        {
          'id': roomId,
          'participantIds': [message.senderId, message.receiverId],
          'lastMessage': message.content,
          'lastMessageTimestamp': message.timestamp.toIso8601String(),
          'unreadBy': FieldValue.arrayUnion([message.receiverId]),
          'requestFor':
              access.isRequest ? message.receiverId : FieldValue.delete(),
        },
        SetOptions(merge: true));
    batch.set(messageRef, message.toMap());
    await batch.commit();

    try {
      final senderSnap =
          await _firestore.collection('users').doc(message.senderId).get();
      final senderData = senderSnap.data() ?? const {};
      final preview = message.content.length > 60
          ? '${message.content.substring(0, 57)}...'
          : message.content;
      await NotificationService.instance.message(
        receiverId: message.receiverId,
        actor: NotificationActor(
          id: message.senderId,
          name: senderData['displayName'] ??
              senderData['name'] ??
              senderData['username'] ??
              'Someone',
          avatar: senderData['photoUrl'] ?? senderData['avatarUrl'] ?? '',
        ),
        messageId: message.id,
        preview: preview.isEmpty ? null : preview,
        isRequest: access.isRequest,
      );
    } catch (_) {}
  }

  @override
  Future<void> sendRoomMessage(String roomId, ChatMessage message) async {
    final roomRef = _firestore.collection('chats').doc(roomId);
    final roomSnap = await roomRef.get();
    final roomData = roomSnap.data() ?? {};
    final participantIds = List<String>.from(roomData['participantIds'] ?? [message.senderId, message.receiverId]);
    final otherParticipants = participantIds.where((id) => id != message.senderId).toList();

    final messageRef = roomRef.collection('messages').doc(message.id);
    final batch = _firestore.batch();
    batch.set(
      roomRef,
      {
        'id': roomId,
        'participantIds': participantIds,
        'lastMessage': message.content.isNotEmpty ? message.content : 'Shared content',
        'lastMessageTimestamp': message.timestamp.toIso8601String(),
        'unreadBy': FieldValue.arrayUnion(otherParticipants),
      },
      SetOptions(merge: true),
    );
    batch.set(messageRef, message.toMap());
    await batch.commit();
  }

  @override
  Future<String> createGroupRoom({
    required String name,
    required String adminId,
    required List<String> memberIds,
    String? iconUrl,
    String? themeId,
  }) async {
    final uniqueMembers = {adminId, ...memberIds}.toList();
    final roomId = 'group_${DateTime.now().millisecondsSinceEpoch}_$adminId';
    final now = DateTime.now();

    final groupRoom = ChatRoom(
      id: roomId,
      participantIds: uniqueMembers,
      lastMessage: 'Group created',
      lastMessageTimestamp: now,
      unreadBy: uniqueMembers.where((id) => id != adminId).toList(),
      type: 'group',
      name: name,
      iconUrl: iconUrl,
      adminId: adminId,
      adminIds: [adminId],
      themeId: themeId ?? 'gold',
      createdAt: now,
      updatedAt: now,
    );

    await _firestore.collection('chats').doc(roomId).set(groupRoom.toMap());
    return roomId;
  }

  @override
  Future<void> updateGroupTheme(String roomId, String themeId) async {
    await _firestore.collection('chats').doc(roomId).set({
      'themeId': themeId,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> addGroupMembers(String roomId, List<String> newMemberIds) async {
    await _firestore.collection('chats').doc(roomId).update({
      'participantIds': FieldValue.arrayUnion(newMemberIds),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> leaveGroup(String roomId, String userId) async {
    final docRef = _firestore.collection('chats').doc(roomId);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final participants = List<String>.from(data['participantIds'] ?? []);
    participants.remove(userId);

    if (participants.isEmpty) {
      await docRef.delete();
    } else {
      final admins = List<String>.from(data['adminIds'] ?? []);
      admins.remove(userId);
      String? newAdminId = data['adminId'];
      if (newAdminId == userId) {
        newAdminId = admins.isNotEmpty ? admins.first : participants.first;
        if (!admins.contains(newAdminId)) {
          admins.add(newAdminId);
        }
      }
      await docRef.update({
        'participantIds': participants,
        'adminIds': admins,
        'adminId': newAdminId,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> updateGroupDetails(String roomId, {String? name, String? iconUrl}) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (name != null && name.trim().isNotEmpty) updates['name'] = name.trim();
    if (iconUrl != null) updates['iconUrl'] = iconUrl;
    await _firestore.collection('chats').doc(roomId).update(updates);
  }

  @override
  Stream<List<ChatRoom>> watchChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map((doc) => ChatRoom.fromMap(doc.data(), doc.id))
          .toList();
      rooms.sort(
          (a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      return rooms;
    });
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    final messageRef = _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    await messageRef.delete();

    final messagesSnapshot = await _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (messagesSnapshot.docs.isNotEmpty) {
      final lastDoc = messagesSnapshot.docs.first;
      final data = lastDoc.data();
      final isUnsent = data['deletedAt'] != null;
      await _firestore.collection('chats').doc(roomId).update({
        'lastMessage': isUnsent ? 'Message unsent' : (data['content'] ?? ''),
        'lastMessageTimestamp':
            data['timestamp'] ?? DateTime.now().toIso8601String(),
      });
    } else {
      await _firestore.collection('chats').doc(roomId).update({
        'lastMessage': 'No messages',
        'lastMessageTimestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<void> toggleMessageReaction(
    String roomId,
    String messageId,
    String userId,
    String emoji,
  ) async {
    final docRef = _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final reactions = Map<String, String>.from(data['reactions'] ?? {});

    if (reactions[userId] == emoji) {
      reactions.remove(userId);
    } else {
      reactions[userId] = emoji;
    }

    await docRef.update({'reactions': reactions});
  }

  @override
  Future<void> markRoomAsRead(String roomId, String userId) async {
    final settings = await _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('preferences')
        .get();
    final messaging = Map<String, dynamic>.from(
      settings.data()?['messaging'] ?? const {},
    );
    final data = <String, dynamic>{
      'unreadBy': FieldValue.arrayRemove([userId]),
    };
    if ((messaging['readReceipts'] as bool?) ?? true) {
      data['readBy'] = FieldValue.arrayUnion([userId]);
    }
    await _firestore
        .collection('chats')
        .doc(roomId)
        .set(data, SetOptions(merge: true));
  }
}
