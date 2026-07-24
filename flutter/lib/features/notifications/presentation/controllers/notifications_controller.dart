import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/data/dummy/notifications_dummy.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

class NotificationsNotifier extends StateNotifier<List<DummyNotification>> {
  final String _userId;
  StreamSubscription? _subscription;

  NotificationsNotifier(this._userId) : super([]) {
    _listenToNotifications();
  }

  void _listenToNotifications() {
    _subscription?.cancel();
    if (_userId.isEmpty) {
      state = dummyNotifications;
      return;
    }

    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        state = dummyNotifications;
      } else {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          final createdAt = data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.now();
          final duration = DateTime.now().difference(createdAt);

          String timeAgo = 'Just now';
          if (duration.inDays > 0) {
            timeAgo = '${duration.inDays}d ago';
          } else if (duration.inHours > 0) {
            timeAgo = '${duration.inHours}h ago';
          } else if (duration.inMinutes > 0) {
            timeAgo = '${duration.inMinutes}m ago';
          }

          return DummyNotification(
            id: doc.id,
            senderId: data['senderId'] as String? ?? 'user_1',
            senderName: data['senderName'] as String? ?? 'Tyler Brooks',
            senderAvatar: data['senderAvatar'] as String? ?? '',
            text: data['text'] as String? ?? '',
            type: data['type'] as String? ?? 'mention',
            timestamp: timeAgo,
            read: data['read'] as bool? ?? false,
            targetId: data['targetId'] as String?,
          );
        }).toList();
        state = list;
      }
    }, onError: (err) {
      state = dummyNotifications;
    });
  }

  Future<void> markAllAsRead() async {
    if (_userId.isEmpty) {
      state = state.map((notif) => notif.copyWith(read: true)).toList();
      return;
    }

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> markAsRead(String id) async {
    if (_userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .collection('notifications')
        .doc(id)
        .update({'read': true});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<DummyNotification>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return NotificationsNotifier(userId);
});
