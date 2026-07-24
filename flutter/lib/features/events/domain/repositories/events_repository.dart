import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_model.dart';

abstract class EventsRepository {
  Stream<List<EventModel>> streamEvents();
  Stream<bool> watchJoinedStatus(String eventId, String userId);
  Stream<bool> watchBookmarkedStatus(String eventId, String userId);
  Future<void> createEvent(EventModel event);
  Future<void> joinEvent(String eventId, String userId, Map<String, dynamic> participantDetails);
  Future<void> leaveEvent(String eventId, String userId);
  Future<void> toggleBookmark(String eventId, String userId, bool shouldBookmark);
  Stream<List<String>> streamParticipantsAvatars(String eventId);
}

class EventsRepositoryImpl implements EventsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Stream<List<EventModel>> streamEvents() {
    return _firestore
        .collection('events')
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Stream<bool> watchJoinedStatus(String eventId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Stream<bool> watchBookmarkedStatus(String eventId, String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarked_events')
        .doc(eventId)
        .snapshots()
        .map((snapshot) => snapshot.exists);
  }

  @override
  Future<void> createEvent(EventModel event) async {
    await _firestore.collection('events').doc(event.eventId).set(event.toMap());
  }

  @override
  Future<void> joinEvent(String eventId, String userId, Map<String, dynamic> participantDetails) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final participantRef = eventRef.collection('participants').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists) {
        throw Exception("Event does not exist!");
      }

      final data = eventSnapshot.data()!;
      final currentParticipants = data['currentParticipants'] as int? ?? 0;
      final maxParticipants = data['maxParticipants'] as int? ?? 100;

      if (currentParticipants >= maxParticipants) {
        throw Exception("This event is fully registered!");
      }

      // Add to participants subcollection
      transaction.set(participantRef, {
        ...participantDetails,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Increment participant count in main event document
      transaction.update(eventRef, {
        'currentParticipants': currentParticipants + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> leaveEvent(String eventId, String userId) async {
    final eventRef = _firestore.collection('events').doc(eventId);
    final participantRef = eventRef.collection('participants').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      final participantSnapshot = await transaction.get(participantRef);

      if (!eventSnapshot.exists) {
        throw Exception("Event does not exist!");
      }
      if (!participantSnapshot.exists) {
        return; // User wasn't joined, nothing to do
      }

      final data = eventSnapshot.data()!;
      final currentParticipants = data['currentParticipants'] as int? ?? 0;

      // Delete from subcollection
      transaction.delete(participantRef);

      // Decrement count
      transaction.update(eventRef, {
        'currentParticipants': currentParticipants > 0 ? currentParticipants - 1 : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> toggleBookmark(String eventId, String userId, bool shouldBookmark) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('bookmarked_events')
        .doc(eventId);

    if (shouldBookmark) {
      await docRef.set({
        'eventId': eventId,
        'bookmarkedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.delete();
    }
  }

  @override
  Stream<List<String>> streamParticipantsAvatars(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('participants')
        .orderBy('joinedAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => doc.data()['avatarUrl'] as String? ?? '')
          .where((avatar) => avatar.isNotEmpty)
          .toList();
    });
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepositoryImpl();
});
