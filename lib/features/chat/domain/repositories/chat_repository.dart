import 'package:cloud_firestore/cloud_firestore.dart';

abstract class ChatRepository {
  Stream<QuerySnapshot> getMessages(String roomId, {int limit = 50});
  Stream<DocumentSnapshot> getRoomStream(String roomId);
  Stream<DocumentSnapshot> getUserStream(String uid);

  Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required String text,
    String type = 'text',
    String? mediaUrl,
    Map<String, dynamic>? replyMessage,
    bool isViewOnce = false,
    bool isForwarded = false,
  });

  Future<void> markAsSeen(String roomId, String messageId);
  Future<void> toggleStarMessage(
      String roomId, String messageId, String uid, bool isStarred);
  Future<void> markViewOnceOpened(String roomId, String messageId);
  Future<void> setTypingStatus(String roomId, String uid, bool isTyping);
  Future<void> setRecordingStatus(String roomId, String uid, bool isRecording);
  Future<void> deleteMessage(String roomId, String messageId,
      {required bool forEveryone, String uid = ''});

  Future<void> toggleReaction(
      String roomId, String messageId, String uid, String emoji);

  Future<void> editMessage(String roomId, String messageId, String newText);

  Future<void> togglePinMessage(
      String roomId, String messageId, bool isPinned);

  Future<void> forwardMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> data,
  });

  /// Deletes all messages in the room and resets room metadata.
  Future<void> clearChat(String roomId);
}
