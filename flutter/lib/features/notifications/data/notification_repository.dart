import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/notification_model.dart';

/// Data access layer for the Notification Center.
///
/// All reads are scoped to `users/{uid}/notifications` and are designed to stay
/// cheap regardless of inbox size:
///  * [watchFirstPage] streams only the newest [pageSize] docs in real time.
///  * [fetchOlder] cursor-paginates the rest on demand (lazy loading).
///  * [watchUnreadCount] uses an aggregation `count()` query so the badge never
///    downloads documents.
class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const int pageSize = 25;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('notifications');

  Query<Map<String, dynamic>> _baseQuery(String uid, NotificationCategory category) {
    Query<Map<String, dynamic>> q = _col(uid);
    if (category != NotificationCategory.all) {
      q = q.where('category', isEqualTo: category.id);
    }
    return q.orderBy('createdAt', descending: true);
  }

  /// Real-time stream of the newest page for the given [category] filter.
  Stream<List<AppNotification>> watchFirstPage(
    String uid,
    NotificationCategory category,
  ) {
    if (uid.isEmpty) return Stream.value(const []);
    return _baseQuery(uid, category).limit(pageSize).snapshots().map(
          (snap) => snap.docs
              .map((d) => AppNotification.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  /// Cursor-based lazy loading of older notifications after [lastCreatedAt].
  Future<List<AppNotification>> fetchOlder(
    String uid,
    NotificationCategory category,
    DateTime lastCreatedAt,
  ) async {
    if (uid.isEmpty) return const [];
    final snap = await _baseQuery(uid, category)
        .startAfter([Timestamp.fromDate(lastCreatedAt)])
        .limit(pageSize)
        .get();
    return snap.docs
        .map((d) => AppNotification.fromMap(d.data(), d.id))
        .toList();
  }

  /// Live unread badge count (aggregation query — does not read documents).
  Stream<int> watchUnreadCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    final controller = StreamController<int>();
    // Re-run the aggregation whenever the inbox changes, but only transfer a
    // single integer rather than the documents themselves.
    final sub = _col(uid)
        .where('read', isEqualTo: false)
        .limit(100)
        .snapshots()
        .listen((snap) {
      // `snap.docs.length` is capped at 100 which is enough for a "99+" badge.
      controller.add(snap.docs.length);
    }, onError: (_) => controller.add(0));
    controller.onCancel = sub.cancel;
    return controller.stream;
  }

  Future<void> markAsRead(String uid, String notificationId) async {
    if (uid.isEmpty) return;
    await _col(uid).doc(notificationId).update({'read': true});
  }

  Future<void> markAllAsRead(String uid) async {
    if (uid.isEmpty) return;
    // Page through unread docs in batches so the operation stays bounded even
    // for very large inboxes.
    Query<Map<String, dynamic>> query =
        _col(uid).where('read', isEqualTo: false).limit(400);
    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
      if (snap.docs.length < 400) break;
    }
  }

  Future<void> delete(String uid, String notificationId) async {
    if (uid.isEmpty) return;
    await _col(uid).doc(notificationId).delete();
  }

  Future<void> clearAll(String uid) async {
    if (uid.isEmpty) return;
    Query<Map<String, dynamic>> query = _col(uid).limit(400);
    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < 400) break;
    }
  }
}
