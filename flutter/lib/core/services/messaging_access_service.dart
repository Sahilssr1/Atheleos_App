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

    try {
      final roomIds = [senderId, receiverId]..sort();
      final roomId = roomIds.join('_');
      final receiverRef = _firestore.collection('users').doc(receiverId);
      final results = await Future.wait([
        receiverRef.collection('settings').doc('preferences').get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        receiverRef.collection('blocked_users').doc(senderId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        _firestore
            .collection('users')
            .doc(senderId)
            .collection('blocked_users')
            .doc(receiverId)
            .get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        receiverRef.collection('followers').doc(senderId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        _firestore.collection('chats').doc(roomId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
      ]);

      final blocked1 = results[1]?.exists ?? false;
      final blocked2 = results[2]?.exists ?? false;
      if (blocked1 || blocked2) {
        return const MessagingAccessResult(
          allowed: false,
          reason: 'Messaging is unavailable for this account.',
        );
      }

      final settingsData = results[0]?.data() ?? const <String, dynamic>{};
      final messaging =
          Map<String, dynamic>.from(settingsData['messaging'] ?? const {});
      final allowedSenders = messaging['allowedSenders'] as String? ?? 'everyone';
      final allowRequests = messaging['allowMessageRequests'] as bool? ?? true;
      final followsReceiver = results[3]?.exists ?? false;
      final roomExists = results[4]?.exists ?? false;

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
    } catch (_) {
      // Allow delivery if check encounters network errors
      return const MessagingAccessResult(allowed: true);
    }
  }
}
