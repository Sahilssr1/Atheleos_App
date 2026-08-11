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
  Stream<List<ChatMessage>> watchMessages(String user1, String user2) {
    final roomId = _getRoomId(user1, user2);
    return _firestore
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
          .toList();
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

    // Emit a message notification through the central pipeline (handles the
    // receiver's directMessages preference, de-duplication and deep-linking).
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
    } catch (_) {
      // Never let notification failures block message delivery.
    }
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
      // Sort client-side to ensure newest are first without needing compound index
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

    // Delete the message
    await messageRef.delete();

    // Query for the new last message
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
      await _firestore.collection('chats').doc(roomId).update({
        'lastMessage': data['content'] ?? '',
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
