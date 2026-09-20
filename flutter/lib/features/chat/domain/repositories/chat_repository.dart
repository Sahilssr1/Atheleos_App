import '../models/chat_message.dart';
import '../models/chat_room_model.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String user1, String user2, {int? limit});
  Stream<List<ChatMessage>> watchRoomMessages(String roomId, {int? limit});
  Future<List<ChatMessage>> getCachedRoomMessages(String roomId, {int? limit});
  Future<List<ChatMessage>> getOlderRoomMessages(String roomId, DateTime beforeTimestamp, int limit);
  Future<void> sendMessage(ChatMessage message);
  Future<void> sendRoomMessage(String roomId, ChatMessage message);
  Stream<List<ChatRoom>> watchChats(String userId);
  Stream<ChatRoom?> watchRoom(String roomId);
  Future<String> createGroupRoom({
    required String name,
    required String adminId,
    required List<String> memberIds,
    String? iconUrl,
    String? themeId,
  });
  Future<void> updateGroupTheme(String roomId, String themeId);
  Future<void> addGroupMembers(String roomId, List<String> newMemberIds);
  Future<void> leaveGroup(String roomId, String userId);
  Future<void> updateGroupDetails(String roomId, {String? name, String? iconUrl});
  Future<void> deleteMessage(String roomId, String messageId);
  Future<void> toggleMessageReaction(String roomId, String messageId, String userId, String emoji);
  Future<void> markRoomAsRead(String roomId, String userId);
  Future<void> acceptMessageRequest(String roomId, String userId);
}
