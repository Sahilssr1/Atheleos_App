import '../models/chat_message.dart';
import '../models/chat_room_model.dart';

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchMessages(String user1, String user2);
  Future<void> sendMessage(ChatMessage message);
  Stream<List<ChatRoom>> watchChats(String userId);
  Future<void> deleteMessage(String roomId, String messageId);
  Future<void> toggleMessageReaction(String roomId, String messageId, String userId, String emoji);
  Future<void> markRoomAsRead(String roomId, String userId);
}
