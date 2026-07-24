import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';

// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatRepository _repository;
  final String _senderId;
  final String _receiverId;
  StreamSubscription? _subscription;

  ChatNotifier(this._repository, this._senderId, this._receiverId) : super([]) {
    _loadCache();
    _subscribe();
    _markRead();
  }

  String get _roomId {
    final list = [_senderId, _receiverId]..sort();
    return list.join('_');
  }

  void _loadCache() {
    try {
      final cached = CacheManager().loadRoomMessages(_roomId);
      if (cached.isNotEmpty) {
        state = cached.map((e) => ChatMessage.fromMap(e, e['id'] ?? '')).toList();
      }
    } catch (_) {}
  }

  void _markRead() {
    _repository.markRoomAsRead(_roomId, _senderId);
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchMessages(_senderId, _receiverId).listen((messages) {
      state = messages;
      _markRead();
      // Cache messages asynchronously
      CacheManager().saveRoomMessages(_roomId, messages.map((m) => m.toMap()).toList());
    });
  }

  Future<void> sendMessage(String content, {String? storyId, String? storyMediaUrl}) async {
    if (content.trim().isEmpty) return;

    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}_$_senderId';
    final message = ChatMessage(
      id: id,
      senderId: _senderId,
      receiverId: _receiverId,
      content: content,
      timestamp: DateTime.now(),
      storyId: storyId,
      storyMediaUrl: storyMediaUrl,
    );

    await _repository.sendMessage(message);
  }

  Future<void> unsendMessage(String messageId) async {
    await _repository.deleteMessage(_roomId, messageId);
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    await _repository.toggleMessageReaction(_roomId, messageId, _senderId, emoji);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Chat family provider scoped by receiverId
final chatProvider = StateNotifierProvider.family<ChatNotifier, List<ChatMessage>, String>((ref, receiverId) {
  final repo = ref.watch(chatRepositoryProvider);
  final senderId = ref.read(loggedInUserIdProvider);
  return ChatNotifier(repo, senderId, receiverId);
});

