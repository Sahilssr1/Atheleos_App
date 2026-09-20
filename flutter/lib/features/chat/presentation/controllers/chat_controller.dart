import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../events/domain/models/event_model.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_room_model.dart';
import '../../domain/models/media_attachment.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/services/media_upload_queue.dart';

// Provider for ChatRepository
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl();
});

// Tracks if room is loading initial messages from network (for cold start / fresh install UI)
final chatRoomLoadingProvider = StateProvider.family<bool, String>((ref, roomId) => true);

// Tracks if room is loading an older batch of messages during scroll
final roomChatLoadingMoreProvider = StateProvider.family<bool, String>((ref, roomId) => false);

class RoomChatNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatRepository _repository;
  final String _roomId;
  final String _senderId;
  final String? _receiverId;
  final Ref? _ref;
  StreamSubscription? _subscription;
  
  List<ChatMessage> _streamedMessages = [];
  List<ChatMessage> _paginatedMessages = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Stored pending attachment references for retry recovery
  final Map<String, NormalizedAttachment> _pendingAttachments = {};

  RoomChatNotifier(this._repository, this._roomId, this._senderId, [this._receiverId, this._ref]) : super([]) {
    _loadCache();
    _subscribe();
    _markRead();
  }

  void _notifyLoaded() {
    if (_ref != null) {
      Future.microtask(() {
        try {
          _ref!.read(chatRoomLoadingProvider(_roomId).notifier).state = false;
        } catch (_) {}
      });
    }
  }

  void _loadCache() async {
    // 1. Instant synchronous SharedPreferences cache restore (0ms)
    try {
      final cached = CacheManager().loadRoomMessages(_roomId);
      if (cached.isNotEmpty) {
        state = cached.map((e) => ChatMessage.fromMap(e, e['id'] ?? '')).toList();
        _notifyLoaded();
      }
    } catch (_) {}

    // 2. Fast local Firestore SQLite cache restore (<15ms)
    try {
      final localFirestoreCached = await _repository.getCachedRoomMessages(_roomId, limit: 15);
      if (localFirestoreCached.isNotEmpty && mounted) {
        _streamedMessages = localFirestoreCached;
        _updateState();
        _notifyLoaded();
      }
    } catch (_) {}
  }

  void _markRead() {
    _repository.markRoomAsRead(_roomId, _senderId);
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _repository.watchRoomMessages(_roomId, limit: 15).listen((serverMessages) {
      _notifyLoaded();

      _streamedMessages = serverMessages;
      _updateState();

      if (serverMessages.length < 15) {
        _hasMore = false;
      }

      _markRead();
    }, onError: (err) {
      debugPrint('[CHAT STREAM ERROR] $err');
      _notifyLoaded();
    });
  }

  void _updateState() {
    final serverIds = <String>{};
    final merged = <ChatMessage>[];

    // 1. Add streamed messages (latest batch of 15)
    for (final msg in _streamedMessages) {
      if (!serverIds.contains(msg.id)) {
        serverIds.add(msg.id);
        merged.add(msg);
      }
    }

    // 2. Add paginated messages
    for (final msg in _paginatedMessages) {
      if (!serverIds.contains(msg.id)) {
        serverIds.add(msg.id);
        merged.add(msg);
      }
    }

    // 3. Keep active optimistic/pending messages
    final pendingOptimistic = state.where((m) {
      return !serverIds.contains(m.id) && (m.isSending || m.isFailed);
    }).toList();

    final combined = [...merged, ...pendingOptimistic];
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    state = combined;

    // Cache the latest 50 messages
    try {
      final serverMessages = state.where((m) => !m.isSending && !m.isFailed).toList();
      final cacheSubset = serverMessages.length > 50
          ? serverMessages.sublist(serverMessages.length - 50)
          : serverMessages;
      CacheManager().saveRoomMessages(_roomId, cacheSubset.map((m) => m.toMap()).toList());
    } catch (_) {}
  }

  bool get hasMore => _hasMore;

  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    if (_ref != null) {
      try {
        _ref!.read(roomChatLoadingMoreProvider(_roomId).notifier).state = true;
      } catch (_) {}
    }

    // Find oldest sent message in current state
    ChatMessage? oldestSent;
    for (final msg in state) {
      if (!msg.isSending && !msg.isFailed) {
        oldestSent = msg;
        break;
      }
    }

    if (oldestSent == null) {
      _isLoadingMore = false;
      if (_ref != null) {
        try {
          _ref!.read(roomChatLoadingMoreProvider(_roomId).notifier).state = false;
        } catch (_) {}
      }
      return;
    }

    try {
      final olderMessages = await _repository.getOlderRoomMessages(
        _roomId,
        oldestSent.timestamp,
        15,
      );

      if (olderMessages.length < 15) {
        _hasMore = false;
      }

      // Add to paginated list (prepending them)
      _paginatedMessages = [...olderMessages, ..._paginatedMessages];

      // Deduplicate paginated messages
      final seenIds = <String>{};
      final uniquePaginated = <ChatMessage>[];
      for (final msg in _paginatedMessages) {
        if (!seenIds.contains(msg.id)) {
          seenIds.add(msg.id);
          uniquePaginated.add(msg);
        }
      }
      _paginatedMessages = uniquePaginated;

      _updateState();
    } catch (e) {
      debugPrint('[CHAT PAGINATION ERROR] $e');
    } finally {
      _isLoadingMore = false;
      if (_ref != null) {
        try {
          _ref!.read(roomChatLoadingMoreProvider(_roomId).notifier).state = false;
        } catch (_) {}
      }
    }
  }

  /// Sends standard text or rich referenced messages.
  Future<void> sendMessage(
    String content, {
    String? storyId,
    String? storyMediaUrl,
    String type = 'text',
    String? referencedPostId,
    String? referencedReelId,
    String? referencedUserId,
    String? referencedEventId,
    String? gifProvider,
    String? gifUrl,
    String? gifId,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
    bool isForwarded = false,
  }) async {
    if (content.trim().isEmpty &&
        referencedPostId == null &&
        referencedReelId == null &&
        referencedUserId == null &&
        referencedEventId == null &&
        gifUrl == null) {
      return;
    }

    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}_$_senderId';
    final message = ChatMessage(
      id: id,
      senderId: _senderId,
      receiverId: _receiverId ?? '',
      content: content,
      timestamp: DateTime.now(),
      storyId: storyId,
      storyMediaUrl: storyMediaUrl,
      type: type,
      referencedPostId: referencedPostId,
      referencedReelId: referencedReelId,
      referencedUserId: referencedUserId,
      referencedEventId: referencedEventId,
      gifProvider: gifProvider,
      gifUrl: gifUrl,
      gifId: gifId,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      isForwarded: isForwarded,
      localState: 'LOCAL_PENDING',
      messageState: 'sending',
    );

    final combined = [...state, message];
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = combined;

    try {
      final serverMessage = message.copyWith(localState: 'SENT', messageState: 'sent');
      if (_roomId.startsWith('group_')) {
        await _repository.sendRoomMessage(_roomId, serverMessage);
      } else if (_receiverId != null && _receiverId!.isNotEmpty) {
        await _repository.sendMessage(serverMessage);
      } else {
        await _repository.sendRoomMessage(_roomId, serverMessage);
      }
      state = state.map((m) => m.id == id ? serverMessage : m).toList();
    } catch (e, stack) {
      debugPrint('[CHAT ERROR] Failed to send message: $e\n$stack');
      state = state.map((m) => m.id == id ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
    }
  }

  /// Sends normalized media attachments asynchronously with instant 0ms optimistic UI rendering.
  Future<void> sendAttachment({
    required NormalizedAttachment attachment,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
    required MediaUploadService uploadService,
  }) async {
    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}_$_senderId';
    _pendingAttachments[id] = attachment;

    String localMediaUrl = attachment.remoteUrl ?? '';
    if (localMediaUrl.isEmpty && attachment.bytes != null) {
      localMediaUrl = 'data:${attachment.mimeType};base64,${base64Encode(attachment.bytes!)}';
    } else if (localMediaUrl.isEmpty && attachment.filePath != null) {
      localMediaUrl = attachment.filePath!;
    }

    final isGif = attachment.isGif;
    final optimisticMessage = ChatMessage(
      id: id,
      senderId: _senderId,
      receiverId: _receiverId ?? '',
      content: isGif ? 'GIF' : (attachment.isImage ? 'Photo' : 'Attachment'),
      timestamp: DateTime.now(),
      type: isGif ? 'gif' : (attachment.isImage ? 'image' : 'file'),
      gifUrl: localMediaUrl,
      gifProvider: attachment.source == AttachmentSource.gifProvider ? 'keyboard' : null,
      localFilePath: attachment.filePath,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      localState: attachment.remoteUrl != null ? 'READY_TO_SEND' : 'UPLOADING',
      messageState: 'sending',
    );

    final combined = [...state, optimisticMessage];
    combined.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = combined;

    // Direct Remote URL (e.g. keyboard GIF with HTTP/HTTPS URL)
    if (attachment.remoteUrl != null && attachment.remoteUrl!.isNotEmpty) {
      try {
        final serverMessage = optimisticMessage.copyWith(
          gifUrl: attachment.remoteUrl,
          localState: 'SENT',
          messageState: 'sent',
        );
        if (_roomId.startsWith('group_')) {
          await _repository.sendRoomMessage(_roomId, serverMessage);
        } else if (_receiverId != null && _receiverId!.isNotEmpty) {
          await _repository.sendMessage(serverMessage);
        } else {
          await _repository.sendRoomMessage(_roomId, serverMessage);
        }
        state = state.map((m) => m.id == id ? serverMessage : m).toList();
      } catch (e) {
        state = state.map((m) => m.id == id ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
      }
      return;
    }

    // Local binary or file upload via controlled upload queue
    MediaUploadQueue.instance.enqueue(
      messageId: id,
      attachment: attachment,
      uploadService: uploadService,
      onProgress: (progress) {
        state = state.map((m) => m.id == id ? m.copyWith(uploadProgress: progress) : m).toList();
      },
      onComplete: (remoteUrl) async {
        try {
          final serverMessage = optimisticMessage.copyWith(
            gifUrl: remoteUrl,
            localState: 'SENT',
            messageState: 'sent',
          );
          if (_roomId.startsWith('group_')) {
            await _repository.sendRoomMessage(_roomId, serverMessage);
          } else if (_receiverId != null && _receiverId!.isNotEmpty) {
            await _repository.sendMessage(serverMessage);
          } else {
            await _repository.sendRoomMessage(_roomId, serverMessage);
          }
          state = state.map((m) => m.id == id ? serverMessage : m).toList();
          _pendingAttachments.remove(id);
        } catch (e) {
          state = state.map((m) => m.id == id ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
        }
      },
      onError: (err) async {
        // Fallback: If upload service failed (e.g. Cloudflare endpoint error), send directly to Firestore as base64!
        try {
          String fallbackUrl = localMediaUrl;
          if (fallbackUrl.isEmpty && attachment.filePath != null) {
            final f = io.File(attachment.filePath!);
            if (await f.exists()) {
              final bytes = await f.readAsBytes();
              if (bytes.length < 800000) {
                final ext = attachment.isGif ? 'gif' : 'jpg';
                fallbackUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
              }
            }
          }

          if (fallbackUrl.isNotEmpty && (fallbackUrl.startsWith('data:') || fallbackUrl.startsWith('http'))) {
            final fallbackMessage = optimisticMessage.copyWith(
              gifUrl: fallbackUrl,
              localState: 'SENT',
              messageState: 'sent',
            );
            if (_roomId.startsWith('group_')) {
              await _repository.sendRoomMessage(_roomId, fallbackMessage);
            } else if (_receiverId != null && _receiverId!.isNotEmpty) {
              await _repository.sendMessage(fallbackMessage);
            } else {
              await _repository.sendRoomMessage(_roomId, fallbackMessage);
            }
            state = state.map((m) => m.id == id ? fallbackMessage : m).toList();
            _pendingAttachments.remove(id);
            return;
          }
        } catch (fallbackErr) {
          debugPrint('[CHAT FALLBACK ERROR] $fallbackErr');
        }

        state = state.map((m) => m.id == id ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
      },
    );
  }

  /// Retries sending a failed message idempotently without creating duplicate documents.
  Future<void> retryMessage(String messageId, MediaUploadService uploadService) async {
    final msgIndex = state.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;
    final msg = state[msgIndex];

    state = state.map((m) => m.id == messageId ? m.copyWith(localState: 'UPLOADING', messageState: 'sending') : m).toList();

    // Check if we have an attachment to retry uploading
    final pendingAtt = _pendingAttachments[messageId];
    if (pendingAtt != null) {
      MediaUploadQueue.instance.enqueue(
        messageId: messageId,
        attachment: pendingAtt,
        uploadService: uploadService,
        onProgress: (progress) {
          state = state.map((m) => m.id == messageId ? m.copyWith(uploadProgress: progress) : m).toList();
        },
        onComplete: (remoteUrl) async {
          final serverMessage = msg.copyWith(
            gifUrl: remoteUrl,
            localState: 'SENT',
            messageState: 'sent',
          );
          if (_roomId.startsWith('group_')) {
            await _repository.sendRoomMessage(_roomId, serverMessage);
          } else if (_receiverId != null && _receiverId!.isNotEmpty) {
            await _repository.sendMessage(serverMessage);
          } else {
            await _repository.sendRoomMessage(_roomId, serverMessage);
          }
          state = state.map((m) => m.id == messageId ? serverMessage : m).toList();
          _pendingAttachments.remove(messageId);
        },
        onError: (err) async {
          // Fallback direct write
          try {
            if (msg.gifUrl != null && (msg.gifUrl!.startsWith('data:') || msg.gifUrl!.startsWith('http'))) {
              final fallbackMessage = msg.copyWith(localState: 'SENT', messageState: 'sent');
              if (_roomId.startsWith('group_')) {
                await _repository.sendRoomMessage(_roomId, fallbackMessage);
              } else if (_receiverId != null && _receiverId!.isNotEmpty) {
                await _repository.sendMessage(fallbackMessage);
              } else {
                await _repository.sendRoomMessage(_roomId, fallbackMessage);
              }
              state = state.map((m) => m.id == messageId ? fallbackMessage : m).toList();
              _pendingAttachments.remove(messageId);
              return;
            }
          } catch (_) {}
          state = state.map((m) => m.id == messageId ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
        },
      );
      return;
    }

    // Otherwise resend directly
    try {
      final serverMessage = msg.copyWith(localState: 'SENT', messageState: 'sent');
      if (_roomId.startsWith('group_')) {
        await _repository.sendRoomMessage(_roomId, serverMessage);
      } else if (_receiverId != null && _receiverId!.isNotEmpty) {
        await _repository.sendMessage(serverMessage);
      } else {
        await _repository.sendRoomMessage(_roomId, serverMessage);
      }
      state = state.map((m) => m.id == messageId ? serverMessage : m).toList();
    } catch (e) {
      state = state.map((m) => m.id == messageId ? m.copyWith(localState: 'FAILED', messageState: 'failed') : m).toList();
    }
  }

  Future<void> unsendMessage(String messageId) async {
    MediaUploadQueue.instance.cancel(messageId);
    _pendingAttachments.remove(messageId);
    state = state.where((m) => m.id != messageId).toList();
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

// Chat family provider scoped by receiverId (for 1-to-1 chats)
final chatProvider = StateNotifierProvider.family<RoomChatNotifier, List<ChatMessage>, String>((ref, receiverId) {
  final repo = ref.watch(chatRepositoryProvider);
  final senderId = ref.watch(loggedInUserIdProvider);
  final list = [senderId, receiverId]..sort();
  final roomId = list.join('_');
  return RoomChatNotifier(repo, roomId, senderId, receiverId, ref);
});

// Chat family provider scoped by roomId (works for group chats and rooms)
final roomChatProvider = StateNotifierProvider.family<RoomChatNotifier, List<ChatMessage>, String>((ref, roomId) {
  final repo = ref.watch(chatRepositoryProvider);
  final senderId = ref.watch(loggedInUserIdProvider);
  return RoomChatNotifier(repo, roomId, senderId, null, ref);
});

// Stream provider for chat room metadata (including group info & theme)
final chatRoomDetailsProvider = StreamProvider.family<ChatRoom?, String>((ref, roomId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchRoom(roomId);
});

final sharedPostDetailsProvider = FutureProvider.family<PostModel?, String>((ref, postId) async {
  final doc = await FirebaseFirestore.instance.collection('posts').doc(postId).get();
  if (!doc.exists || doc.data() == null) return null;
  return PostModel.fromMap({'id': doc.id, ...doc.data()!});
});

final sharedEventDetailsProvider = FutureProvider.family<EventModel?, String>((ref, eventId) async {
  final doc = await FirebaseFirestore.instance.collection('events').doc(eventId).get();
  if (!doc.exists || doc.data() == null) return null;
  return EventModel.fromMap(doc.data()!, doc.id);
});
