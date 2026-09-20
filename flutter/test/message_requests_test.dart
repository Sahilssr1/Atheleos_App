import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/chat/domain/models/chat_room_model.dart';

void main() {
  group('Message Requests Logic in ChatRoom', () {
    test('Unreplied incoming conversation is a message request for the recipient', () {
      final room = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Hey Bob, are you going to the game?',
        lastMessageTimestamp: DateTime.now(),
        initiatorId: 'alice',
        repliedUserIds: ['alice'],
        lastSenderId: 'alice',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Alice sent it -> NOT a request for Alice
      expect(room.isMessageRequestFor('alice'), isFalse);

      // Bob received it and has NOT replied -> IS a request for Bob
      expect(room.isMessageRequestFor('bob'), isTrue);

      // Non-participant -> NOT a request
      expect(room.isMessageRequestFor('charlie'), isFalse);
    });

    test('Once recipient replies, conversation is no longer a message request', () {
      final roomAfterReply = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Yeah, I will be there!',
        lastMessageTimestamp: DateTime.now(),
        initiatorId: 'alice',
        repliedUserIds: ['alice', 'bob'],
        lastSenderId: 'bob',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Both have replied -> neither sees it as a request
      expect(roomAfterReply.isMessageRequestFor('alice'), isFalse);
      expect(roomAfterReply.isMessageRequestFor('bob'), isFalse);
    });

    test('Multiple messages sent by initiator before reply still remain a request for recipient', () {
      final roomWithMultipleMessages = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Hey? Did you see my last message?',
        lastMessageTimestamp: DateTime.now(),
        initiatorId: 'alice',
        repliedUserIds: ['alice'],
        lastSenderId: 'alice',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(roomWithMultipleMessages.isMessageRequestFor('alice'), isFalse);
      expect(roomWithMultipleMessages.isMessageRequestFor('bob'), isTrue);
    });

    test('Group conversations are never message requests', () {
      final groupRoom = ChatRoom(
        id: 'group_123',
        participantIds: ['alice', 'bob', 'charlie'],
        lastMessage: 'Welcome to the team!',
        lastMessageTimestamp: DateTime.now(),
        type: 'group',
        initiatorId: 'alice',
        repliedUserIds: ['alice'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(groupRoom.isMessageRequestFor('bob'), isFalse);
      expect(groupRoom.isMessageRequestFor('charlie'), isFalse);
      expect(groupRoom.isMessageRequestFor('alice'), isFalse);
    });

    test('Legacy rooms without repliedUserIds or requestFor default to normal chats', () {
      final legacyRoom = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Hello',
        lastMessageTimestamp: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(legacyRoom.isMessageRequestFor('alice'), isFalse);
      expect(legacyRoom.isMessageRequestFor('bob'), isFalse);
    });

    test('ChatRoom serialization preserves all message request fields', () {
      final original = ChatRoom(
        id: 'user1_user2',
        participantIds: ['user1', 'user2'],
        lastMessage: 'Check this out',
        lastMessageTimestamp: DateTime.parse('2026-09-17T12:00:00.000Z'),
        unreadBy: ['user2'],
        initiatorId: 'user1',
        repliedUserIds: ['user1'],
        lastSenderId: 'user1',
        requestFor: 'user2',
        createdAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
        updatedAt: DateTime.parse('2026-09-17T12:00:00.000Z'),
      );

      final map = original.toMap();
      expect(map['initiatorId'], equals('user1'));
      expect(map['repliedUserIds'], equals(['user1']));
      expect(map['lastSenderId'], equals('user1'));
      expect(map['requestFor'], equals('user2'));

      final restored = ChatRoom.fromMap(map, original.id);
      expect(restored.initiatorId, equals('user1'));
      expect(restored.repliedUserIds, equals(['user1']));
      expect(restored.lastSenderId, equals('user1'));
      expect(restored.requestFor, equals('user2'));
      expect(restored.isMessageRequestFor('user2'), isTrue);
      expect(restored.isMessageRequestFor('user1'), isFalse);
    });

    test('When sender and receiver mutually follow each other, conversation goes directly to normal chats', () {
      // Alice follows Bob AND Bob follows Alice back -> repliedUserIds contains both
      final mutualRoom = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Hey Bob, great to connect!',
        lastMessageTimestamp: DateTime.now(),
        initiatorId: 'alice',
        repliedUserIds: ['alice', 'bob'], // Marked directly as accepted
        lastSenderId: 'alice',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Neither user sees this as a request: falls directly into normal message list
      expect(mutualRoom.isMessageRequestFor('alice'), isFalse);
      expect(mutualRoom.isMessageRequestFor('bob'), isFalse);
    });

    test('When only sender follows receiver, conversation is placed into message requests for receiver', () {
      // Alice follows Bob, but Bob has NOT followed Alice back -> only Alice in repliedUserIds
      final singleFollowRoom = ChatRoom(
        id: 'alice_bob',
        participantIds: ['alice', 'bob'],
        lastMessage: 'Hey Bob!',
        lastMessageTimestamp: DateTime.now(),
        initiatorId: 'alice',
        repliedUserIds: ['alice'],
        lastSenderId: 'alice',
        requestFor: 'bob',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Alice sent it -> normal chat for Alice
      expect(singleFollowRoom.isMessageRequestFor('alice'), isFalse);

      // Bob has NOT followed Alice back and has NOT replied -> IS a message request for Bob
      expect(singleFollowRoom.isMessageRequestFor('bob'), isTrue);
    });
  });
}
