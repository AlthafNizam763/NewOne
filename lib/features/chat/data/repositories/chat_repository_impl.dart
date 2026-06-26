import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepositoryImpl(this._firestore);

  @override
  Stream<QuerySnapshot> getMessages(String roomId, {int limit = 50}) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  @override
  Stream<DocumentSnapshot> getRoomStream(String roomId) {
    return _firestore.collection('chat_rooms').doc(roomId).snapshots();
  }

  @override
  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  @override
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
  }) async {
    final ref = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc();

    final msg = {
      'id': ref.id,
      'sender': senderId,
      'receiver': receiverId,
      'text': text,
      'type': type,
      'mediaUrl': mediaUrl,
      'replyMessage': replyMessage,
      'isViewOnce': isViewOnce,
      'viewOnceOpened': false,
      'seen': false,
      'delivered': true,
      'createdAt': FieldValue.serverTimestamp(),
      'isDeleted': false,
      'isEdited': false,
      'isPinned': false,
      'isForwarded': isForwarded,
      'reactions': <String, String>{},
    };

    final batch = _firestore.batch();
    batch.set(ref, msg);

    batch.set(
        _firestore.collection('chat_rooms').doc(roomId),
        {
          'lastMessage': type == 'text' ? text : '[$type]',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCount_$receiverId': FieldValue.increment(1),
          'totalMessages': FieldValue.increment(1),
          if (type != 'text') 'totalMedia': FieldValue.increment(1),
          'typing_$senderId': false, // Stop typing when sending
        },
        SetOptions(merge: true));

    await batch.commit();
  }

  @override
  Future<void> markAsSeen(String roomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'seen': true});
  }

  @override
  Future<void> toggleStarMessage(
      String roomId, String messageId, String uid, bool isStarred) async {
    final ref = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    if (isStarred) {
      await ref.update({
        'starredBy': FieldValue.arrayUnion([uid])
      });
    } else {
      await ref.update({
        'starredBy': FieldValue.arrayRemove([uid])
      });
    }
  }

  @override
  Future<void> markViewOnceOpened(String roomId, String messageId) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({
      'viewOnceOpened': true,
      'mediaUrl': null, // Delete the URL from DB so it cannot be accessed again
    });
  }

  @override
  Future<void> setTypingStatus(String roomId, String uid, bool isTyping) async {
    await _firestore.collection('chat_rooms').doc(roomId).update({
      'typing_$uid': isTyping,
    });
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId,
      {required bool forEveryone}) async {
    final ref = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    if (forEveryone) {
      await ref.update({
        'isDeleted': true,
        'text': 'This message was deleted',
        'type': 'system'
      });
    } else {
      // For me logic could involve hiding it locally or maintaining a deletedBy array
      await ref.update({
        'deletedBy': FieldValue.arrayUnion(['me']),
      });
    }
  }

  @override
  Future<void> toggleReaction(
      String roomId, String messageId, String uid, String emoji) async {
    final ref = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);

    final snap = await ref.get();
    final existing =
        (snap.data()?['reactions'] as Map<String, dynamic>?) ?? {};
    final updated = Map<String, dynamic>.from(existing);

    if (updated[uid] == emoji) {
      updated.remove(uid);
    } else {
      updated[uid] = emoji;
    }

    await ref.update({'reactions': updated});
  }

  @override
  Future<void> editMessage(
      String roomId, String messageId, String newText) async {
    await _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId)
        .update({'text': newText, 'isEdited': true});
  }

  @override
  Future<void> togglePinMessage(
      String roomId, String messageId, bool isPinned) async {
    final batch = _firestore.batch();
    final msgRef = _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .doc(messageId);
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);

    batch.update(msgRef, {'isPinned': isPinned});
    batch.set(
      roomRef,
      {
        'pinnedMessageIds': isPinned
            ? FieldValue.arrayUnion([messageId])
            : FieldValue.arrayRemove([messageId]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  @override
  Future<void> forwardMessage({
    required String roomId,
    required String senderId,
    required String receiverId,
    required Map<String, dynamic> data,
  }) async {
    await sendMessage(
      roomId: roomId,
      senderId: senderId,
      receiverId: receiverId,
      text: data['text'] ?? '',
      type: data['type'] ?? 'text',
      mediaUrl: data['mediaUrl'],
      isForwarded: true,
    );
  }
}
