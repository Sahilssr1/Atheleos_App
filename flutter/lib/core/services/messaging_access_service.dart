import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingAccessResult {
  final bool allowed;
  final bool isRequest;
  final String? reason;

  const MessagingAccessResult({
    required this.allowed,
    this.isRequest = false,
    this.reason,
  });
}

class MessagingAccessService {
  final FirebaseFirestore _firestore;

  MessagingAccessService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<MessagingAccessResult> check({
    required String senderId,
    required String receiverId,
  }) async {
    if (senderId.isEmpty || receiverId.isEmpty || senderId == receiverId) {
      return const MessagingAccessResult(
        allowed: false,
        reason: 'This conversation cannot be started.',
      );
    }

    final roomIds = [senderId, receiverId]..sort();
    final roomId = roomIds.join('_');
    final receiverRef = _firestore.collection('users').doc(receiverId);
    final results = await Future.wait([
      receiverRef.collection('settings').doc('preferences').get(),
      receiverRef.collection('blocked_users').doc(senderId).get(),
      _firestore
          .collection('users')
          .doc(senderId)
          .collection('blocked_users')
          .doc(receiverId)
          .get(),
      receiverRef.collection('followers').doc(senderId).get(),
      _firestore.collection('chats').doc(roomId).get(),
    ]);

    if (results[1].exists || results[2].exists) {
      return const MessagingAccessResult(
        allowed: false,
        reason: 'Messaging is unavailable for this account.',
      );
    }

    final settingsData = results[0].data() ?? const <String, dynamic>{};
    final messaging =
        Map<String, dynamic>.from(settingsData['messaging'] ?? const {});
    final allowedSenders = messaging['allowedSenders'] as String? ?? 'everyone';
    final allowRequests = messaging['allowMessageRequests'] as bool? ?? true;
    final followsReceiver = results[3].exists;
    final roomExists = results[4].exists;

    if (allowedSenders == 'nobody') {
      return const MessagingAccessResult(
        allowed: false,
        reason: 'This user is not accepting messages.',
      );
    }
    if (roomExists || followsReceiver || allowedSenders == 'everyone') {
      return MessagingAccessResult(
        allowed: true,
        isRequest: !roomExists && !followsReceiver && allowRequests,
      );
    }
    if (allowedSenders == 'followers' && allowRequests) {
      return const MessagingAccessResult(allowed: true, isRequest: true);
    }
    return const MessagingAccessResult(
      allowed: false,
      reason: 'Only followers can message this user.',
    );
  }
}
