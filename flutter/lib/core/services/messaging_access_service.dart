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
      final senderRef = _firestore.collection('users').doc(senderId);
      final results = await Future.wait([
        receiverRef.collection('settings').doc('preferences').get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        receiverRef.collection('blocked_users').doc(senderId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        senderRef.collection('blocked_users').doc(receiverId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        receiverRef.collection('followers').doc(senderId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
        senderRef.collection('followers').doc(receiverId).get().then<DocumentSnapshot<Map<String, dynamic>>?>((d) => d).catchError((_) => null),
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

      // Sender follows Receiver
      final senderFollowsReceiver = results[3]?.exists ?? false;
      // Receiver follows Sender back
      final receiverFollowsSender = results[4]?.exists ?? false;
      // Mutual follow: both follow each other back
      final isMutualFollow = senderFollowsReceiver && receiverFollowsSender;

      final roomSnap = results[5];
      final roomData = roomSnap?.data();
      final rawReplied = roomData?['repliedUserIds'];
      final repliedList = rawReplied is List ? rawReplied.map((e) => e.toString()).toList() : <String>[];
      final receiverAlreadyReplied = repliedList.contains(receiverId);

      // Falls directly in normal chat list if mutual followers or if receiver already replied
      final isRequest = !isMutualFollow && !receiverAlreadyReplied;

      if (allowedSenders == 'nobody') {
        return const MessagingAccessResult(
          allowed: false,
          reason: 'This user is not accepting messages.',
        );
      }
      if (allowedSenders == 'followers') {
        if (!senderFollowsReceiver && !allowRequests) {
          return const MessagingAccessResult(
            allowed: false,
            reason: 'Only followers can message this user.',
          );
        }
        return MessagingAccessResult(
          allowed: true,
          isRequest: isRequest,
        );
      }

      return MessagingAccessResult(
        allowed: true,
        isRequest: isRequest,
      );
    } catch (_) {
      // Allow delivery if check encounters network errors
      return const MessagingAccessResult(allowed: true);
    }
  }
}
