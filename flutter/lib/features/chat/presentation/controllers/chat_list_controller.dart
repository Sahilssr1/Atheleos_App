import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/chat_room_model.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatListNotifier extends StateNotifier<List<ChatRoom>> {
  final ChatRepository _repository;
  final String _userId;
  StreamSubscription? _subscription;

  ChatListNotifier(this._repository, this._userId) : super([]) {
    _loadCache();
    _subscribe();
  }

  void _loadCache() {
    try {
      final cached = CacheManager().loadChatList();
      if (cached.isNotEmpty) {
        state = cached.map((e) => ChatRoom.fromMap(e, e['id'] ?? '')).toList();
      }
    } catch (_) {}
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchChats(_userId).listen((rooms) {
      state = rooms;
      CacheManager().saveChatList(rooms.map((r) => r.toMap()).toList());
    });
  }

  Future<void> deleteChatRoom(String roomId) async {
    // Optimistically update local state
    state = state.where((room) => room.id != roomId).toList();
    // Delete from Firestore
    await FirebaseFirestore.instance.collection('chats').doc(roomId).delete();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Chat List provider
final chatListProvider = StateNotifierProvider<ChatListNotifier, List<ChatRoom>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final userId = ref.watch(loggedInUserIdProvider);
  return ChatListNotifier(repo, userId);
});
