import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/chat/domain/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatMessage Idempotency & Discrete State Machine', () {
    test('Preserves separate localState and deliveryState across transitions', () {
      final msg = ChatMessage(
        id: 'msg_1720000000000_user1',
        senderId: 'user1',
        receiverId: 'user2',
        content: 'GIF',
        timestamp: DateTime(2026, 8, 26, 12, 0),
        type: 'gif',
        gifUrl: 'https://media.tenor.com/test.gif',
        localState: 'UPLOADING',
        deliveryState: null,
        messageState: 'sending',
      );

      expect(msg.isSending, isTrue);
      expect(msg.isSent, isFalse);
      expect(msg.isFailed, isFalse);

      // Transition to SENT upon Firestore confirmation
      final sentMsg = msg.copyWith(
        localState: 'SENT',
        deliveryState: 'SENT',
        messageState: 'sent',
      );

      expect(sentMsg.isSending, isFalse);
      expect(sentMsg.isSent, isTrue);
      expect(sentMsg.id, equals(msg.id)); // ID MUST NOT CHANGE

      // Progression to DELIVERED and READ
      final readMsg = sentMsg.copyWith(
        deliveryState: 'READ',
        messageState: 'seen',
      );

      expect(readMsg.isSeen, isTrue);
      expect(readMsg.id, equals(msg.id));
    });

    test('Reconciles server snapshots with local optimistic messages without duplication', () {
      final optimisticMsg1 = ChatMessage(
        id: 'msg_001',
        senderId: 'user1',
        receiverId: 'user2',
        content: 'Optimistic GIF 1',
        timestamp: DateTime(2026, 8, 26, 12, 0),
        localState: 'UPLOADING',
        messageState: 'sending',
      );

      final optimisticMsg2 = ChatMessage(
        id: 'msg_002',
        senderId: 'user1',
        receiverId: 'user2',
        content: 'Optimistic GIF 2',
        timestamp: DateTime(2026, 8, 26, 12, 1),
        localState: 'UPLOADING',
        messageState: 'sending',
      );

      final initialLocalState = [optimisticMsg1, optimisticMsg2];

      // Server snapshot arrives containing msg_001 confirmed as written
      final serverMessages = [
        ChatMessage(
          id: 'msg_001',
          senderId: 'user1',
          receiverId: 'user2',
          content: 'Optimistic GIF 1',
          timestamp: DateTime(2026, 8, 26, 12, 0),
          localState: 'SENT',
          messageState: 'sent',
        ),
      ];

      final serverIds = serverMessages.map((m) => m.id).toSet();
      final pendingOptimistic = initialLocalState.where((m) => !serverIds.contains(m.id)).toList();

      final combined = [...serverMessages, ...pendingOptimistic];
      combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // Result MUST have exactly 2 messages, zero duplicates!
      expect(combined.length, equals(2));
      expect(combined[0].id, equals('msg_001'));
      expect(combined[0].messageState, equals('sent'));
      expect(combined[1].id, equals('msg_002'));
      expect(combined[1].messageState, equals('sending'));
    });

    test('Serialization round-trip preserves all rich media fields and states', () {
      final msg = ChatMessage(
        id: 'msg_123',
        senderId: 'u1',
        receiverId: 'u2',
        content: 'Great dunk',
        timestamp: DateTime(2026, 8, 26, 15, 30),
        type: 'gif',
        gifProvider: 'tenor',
        gifUrl: 'https://media.tenor.com/dunk.gif',
        gifId: 'tenor_dunk_99',
        localState: 'SENT',
        deliveryState: 'DELIVERED',
        messageState: 'delivered',
        isForwarded: true,
      );

      final map = msg.toMap();
      final reconstructed = ChatMessage.fromMap(map, 'msg_123');

      expect(reconstructed.id, equals('msg_123'));
      expect(reconstructed.type, equals('gif'));
      expect(reconstructed.gifProvider, equals('tenor'));
      expect(reconstructed.gifUrl, equals('https://media.tenor.com/dunk.gif'));
      expect(reconstructed.localState, equals('SENT'));
      expect(reconstructed.deliveryState, equals('DELIVERED'));
      expect(reconstructed.isForwarded, isTrue);
    });
  });
}
