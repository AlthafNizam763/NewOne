import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/push_notification_service.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(FirebaseFirestore.instance);
});

final chatMessagesProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).getMessages(roomId);
});

final roomStreamProvider =
    StreamProvider.family<DocumentSnapshot, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).getRoomStream(roomId);
});

final userProfileProvider =
    StreamProvider.family<DocumentSnapshot, String>((ref, uid) {
  return ref.watch(chatRepositoryProvider).getUserStream(uid);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String? _roomId;
  String? _myUid;
  String? _partnerUid;
  String? _partnerUsername;

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmoji = false;
  bool _isUploading = false;
  bool _isViewOnce = false;
  Map<String, dynamic>? _replyMessage;

  bool _notifyWhenOnline = false;
  bool _wasPartnerOnline = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription? _partnerSub;

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _initChat(user.uid);
      }
    });
  }

  void _initChat(String uid) async {
    try {
      _myUid = uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      if (doc.exists && mounted) {
        final partnerUid = doc.data()?['partnerUid'];
        if (partnerUid != null) {
          final partnerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(partnerUid)
              .get();

          setState(() {
            _partnerUid = partnerUid;
            _partnerUsername = partnerDoc.data()?['username'];
            _roomId = _myUid!.compareTo(partnerUid) < 0
                ? '${_myUid}_$partnerUid'
                : '${partnerUid}_$_myUid';
          });

          _partnerSub?.cancel();
          _partnerSub = FirebaseFirestore.instance
              .collection('users')
              .doc(_partnerUid)
              .snapshots()
              .listen((snap) {
            if (!snap.exists) return;
            final data = snap.data()!;
            final isOnline = data['isOnline'] == true;

            if (_notifyWhenOnline && !_wasPartnerOnline && isOnline) {
              ref
                  .read(pushNotificationServiceProvider)
                  .showOnlineNotification(data['username'] ?? 'Partner');
              if (mounted) {
                setState(() => _notifyWhenOnline = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        '${data['username'] ?? 'Partner'} is now online!')));
              }
            }
            _wasPartnerOnline = isOnline;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Partner not found in database!')));
            setState(() => _partnerUsername = 'Error: No Partner');
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User document not found!')));
          setState(() => _partnerUsername = 'Error: No Profile');
        }
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading chat: $e')));
        setState(() => _partnerUsername = 'Error Loading');
      }
    }
  }

  void _onTextChanged(String text) {
    if (_roomId == null || _myUid == null) return;

    if (!_isTyping && text.isNotEmpty) {
      _isTyping = true;
      ref.read(chatRepositoryProvider).setTypingStatus(_roomId!, _myUid!, true);
    }

    if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();

    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _isTyping = false;
        ref
            .read(chatRepositoryProvider)
            .setTypingStatus(_roomId!, _myUid!, false);
      }
    });
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty ||
        _roomId == null ||
        _myUid == null ||
        _partnerUid == null) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    _onTextChanged(''); // Reset typing

    final replyMap = _replyMessage;
    setState(() => _replyMessage = null);

    ref
        .read(chatRepositoryProvider)
        .sendMessage(
          roomId: _roomId!,
          senderId: _myUid!,
          receiverId: _partnerUid!,
          text: text,
          type: 'text',
          replyMessage: replyMap,
        )
        .catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    });
  }

  void _markAsSeenIfNeeded(Map<String, dynamic> data, String msgId) {
    if (data['receiver'] == _myUid && data['seen'] == false) {
      ref.read(chatRepositoryProvider).markAsSeen(_roomId!, msgId);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _authSub?.cancel();
    _partnerSub?.cancel();
    _audioRecorder.dispose();
    if (_roomId != null && _myUid != null) {
      ref
          .read(chatRepositoryProvider)
          .setTypingStatus(_roomId!, _myUid!, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: _buildAppBar(),
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.darkBackgroundGradient),
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            if (_isUploading)
              const LinearProgressIndicator(color: AppColors.primaryDark),
            _buildMessageComposer(),
            if (_showEmoji)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    _msgCtrl.text = _msgCtrl.text + emoji.emoji;
                    _onTextChanged(_msgCtrl.text);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surfaceDark,
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 75,
      leading: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.arrow_back, size: 24),
            const SizedBox(width: 2),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.elevatedDark,
              backgroundImage: AvatarUtil.getPartnerAvatarProvider(
                  FirebaseAuth.instance.currentUser?.email),
            ),
          ],
        ),
      ),
      title: InkWell(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_partnerUsername ?? 'Loading...',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              _buildPartnerStatus(),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {}),
        IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_outlined),
            onPressed: () {}),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'clear') {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared locally')));
            } else if (val == 'block') {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('User blocked')));
            } else if (val == 'notify') {
              setState(() => _notifyWhenOnline = !_notifyWhenOnline);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
                value: 'view_contact', child: Text('View contact')),
            const PopupMenuItem(
                value: 'media', child: Text('Media, links, and docs')),
            const PopupMenuItem(value: 'search', child: Text('Search')),
            PopupMenuItem(
                value: 'notify',
                child: Text(_notifyWhenOnline
                    ? 'Disable online alert'
                    : 'Enable online alert')),
            const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            const PopupMenuItem(value: 'block', child: Text('Block')),
          ],
        ),
      ],
    );
  }

  Widget _buildPartnerStatus() {
    if (_partnerUid == null || _roomId == null) return const SizedBox.shrink();

    return ref.watch(roomStreamProvider(_roomId!)).when(
          data: (roomDoc) {
            final roomData = roomDoc.data() as Map<String, dynamic>?;
            final isTyping = roomData?['typing_$_partnerUid'] ?? false;

            if (isTyping) {
              return const Text('typing...',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryGlow,
                      fontWeight: FontWeight.w700));
            }

            return ref.watch(userProfileProvider(_partnerUid!)).when(
                  data: (userDoc) {
                    final userData = userDoc.data() as Map<String, dynamic>?;
                    final isOnline = userData?['isOnline'] ?? false;
                    if (isOnline) {
                      return const Text('online',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary));
                    } else {
                      return const SizedBox.shrink();
                    }
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  Widget _buildMessageList() {
    if (_roomId == null)
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGlow));

    return ref.watch(chatMessagesProvider(_roomId!)).when(
          data: (snapshot) {
            final docs = snapshot.docs;
            if (docs.isEmpty) {
              return const Center(
                  child: Text('Send a message to start chatting',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            return ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              reverse: true, // Latest at the bottom
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final msgId = docs[index].id;

                _markAsSeenIfNeeded(data, msgId);

                final isMe = data['sender'] == _myUid;
                final prevData = index < docs.length - 1
                    ? docs[index + 1].data() as Map<String, dynamic>
                    : null;

                // Show date separator if day changed
                bool showDate = false;
                if (prevData != null &&
                    data['createdAt'] != null &&
                    prevData['createdAt'] != null) {
                  final currDate = (data['createdAt'] as Timestamp).toDate();
                  final prevDate =
                      (prevData['createdAt'] as Timestamp).toDate();
                  if (currDate.day != prevDate.day ||
                      currDate.month != prevDate.month ||
                      currDate.year != prevDate.year) {
                    showDate = true;
                  }
                } else if (index == docs.length - 1) {
                  showDate = true;
                }

                return Column(
                  children: [
                    if (showDate && data['createdAt'] != null)
                      _buildDateSeparator(
                          (data['createdAt'] as Timestamp).toDate()),
                    _buildMessageBubble(data, isMe, msgId,
                        showTail: index == 0 ||
                            prevData?['sender'] != data['sender']),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark)),
          error: (err, st) => Center(
              child: Text('Error: $err',
                  style: const TextStyle(color: Colors.white))),
        );
  }

  Widget _buildDateSeparator(DateTime date) {
    final today = DateTime.now();
    String dateStr;
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      dateStr = 'TODAY';
    } else if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day - 1) {
      dateStr = 'YESTERDAY';
    } else {
      dateStr = DateFormat('dd/MM/yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedDark,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Text(dateStr,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, String msgId,
      {bool showTail = true}) {
    final text = data['text'] ?? '';
    final isDeleted = data['isDeleted'] ?? false;
    final time = data['createdAt'] != null
        ? DateFormat('HH:mm').format((data['createdAt'] as Timestamp).toDate())
        : '';
    final seen = data['seen'] ?? false;
    final delivered = data['delivered'] ?? false;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          _showMessageOptions(data, msgId, isMe);
        },
        child: Dismissible(
          key: Key(msgId),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            setState(() => _replyMessage = data);
            return false;
          },
          background: const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 16.0),
              child: Icon(Icons.reply, color: AppColors.textSecondary),
            ),
          ),
          child: Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8),
            margin: EdgeInsets.only(
              bottom: showTail ? 8 : 2,
              left: isMe ? 60 : (showTail ? 16 : 24),
              right: isMe ? (showTail ? 16 : 24) : 60,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.primaryDark.withValues(alpha: 0.92)
                  : AppColors.elevatedDark,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 1,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (data['replyMessage'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                          left: BorderSide(
                              color:
                                  isMe ? Colors.white70 : AppColors.primaryGlow,
                              width: 3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['replyMessage']['sender'] == _myUid
                              ? 'You'
                              : (_partnerUsername ?? 'Partner'),
                          style: TextStyle(
                              color:
                                  isMe ? Colors.white : AppColors.primaryGlow,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data['replyMessage']['text'] ?? 'Photo',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isMe
                                  ? Colors.white70
                                  : AppColors.textSecondary,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                if (data['type'] == 'document' && data['mediaUrl'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insert_drive_file,
                            color: AppColors.primaryGlow, size: 30),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            text.replaceFirst('Document: ', ''),
                            style: TextStyle(
                                color: isMe
                                    ? const Color(0xFF06211D)
                                    : Colors.white,
                                decoration: TextDecoration.underline),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data['type'] == 'location' && data['text'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            color: AppColors.success, size: 30),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            text.split('\n').first,
                            style: TextStyle(
                                color: isMe
                                    ? const Color(0xFF06211D)
                                    : Colors.white,
                                fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data['type'] == 'audio' && data['mediaUrl'] != null)
                  _AudioPlayerBubble(url: data['mediaUrl']),
                if (data['type'] == 'image')
                  if (data['isViewOnce'] == true)
                    _buildViewOnceMedia(data, isMe, msgId)
                  else if (data['mediaUrl'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(data['mediaUrl'],
                            height: 200, width: 200, fit: BoxFit.cover),
                      ),
                    ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  alignment: WrapAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0, bottom: 0.0),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: isMe
                              ? const Color(0xFF06211D)
                              : (isDeleted
                                  ? Colors.white54
                                  : const Color(0xFFE9EDEF)),
                          fontSize: 16,
                          fontStyle:
                              isDeleted ? FontStyle.italic : FontStyle.normal,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time,
                            style: TextStyle(
                                color: isMe
                                    ? const Color(0xFF17433D)
                                    : AppColors.textSecondary,
                                fontSize: 11)),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            seen
                                ? Icons.done_all
                                : (delivered ? Icons.done_all : Icons.done),
                            size: 16,
                            color: seen
                                ? AppColors.secondaryDark
                                : (isMe
                                    ? const Color(0xFF17433D)
                                    : AppColors.textSecondary),
                          ),
                        ]
                      ],
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> data, String msgId, bool isMe) {
    showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surfaceDark,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.reply, color: Colors.white),
                  title: const Text('Reply',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    context.pop();
                    setState(() => _replyMessage = data);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white),
                  title:
                      const Text('Copy', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    context.pop();
                    Clipboard.setData(ClipboardData(text: data['text'] ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
                ListTile(
                  leading: Icon(
                      (data['starredBy'] as List?)?.contains(_myUid) ?? false
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber),
                  title: Text(
                      (data['starredBy'] as List?)?.contains(_myUid) ?? false
                          ? 'Unstar'
                          : 'Star',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    context.pop();
                    final isStarred =
                        (data['starredBy'] as List?)?.contains(_myUid) ?? false;
                    ref.read(chatRepositoryProvider).toggleStarMessage(
                        _roomId!, msgId, _myUid!, !isStarred);
                  },
                ),
                if (isMe && !(data['isDeleted'] ?? false))
                  ListTile(
                    leading: const Icon(Icons.delete_outline,
                        color: AppColors.error),
                    title: const Text('Delete for everyone',
                        style: TextStyle(color: AppColors.error)),
                    onTap: () {
                      ref
                          .read(chatRepositoryProvider)
                          .deleteMessage(_roomId!, msgId, forEveryone: true);
                      context.pop();
                    },
                  ),
                ListTile(
                  leading:
                      const Icon(Icons.delete, color: AppColors.textSecondary),
                  title: const Text('Delete for me',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    ref
                        .read(chatRepositoryProvider)
                        .deleteMessage(_roomId!, msgId, forEveryone: false);
                    context.pop();
                  },
                ),
              ],
            ),
          );
        });
  }

  Widget _buildViewOnceMedia(
      Map<String, dynamic> data, bool isMe, String msgId) {
    final opened = data['viewOnceOpened'] ?? false;
    final mediaUrl = data['mediaUrl'];

    return GestureDetector(
      onTap: () async {
        if (opened || mediaUrl == null) return;

        await showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              fit: StackFit.expand,
              children: [
                InteractiveViewer(
                  child: Image.network(mediaUrl, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 24),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!isMe) {
          ref.read(chatRepositoryProvider).markViewOnceOpened(_roomId!, msgId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: opened
                  ? AppColors.textSecondary
                  : AppColors.primaryGlow.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              opened ? Icons.drafts_outlined : Icons.looks_one,
              color: opened ? AppColors.textSecondary : AppColors.primaryGlow,
            ),
            const SizedBox(width: 8),
            Text(
              opened ? 'Opened' : 'Photo',
              style: TextStyle(
                color: opened ? AppColors.textSecondary : AppColors.primaryGlow,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
          .copyWith(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.elevatedDark,
                borderRadius: BorderRadius.circular(8),
                border: const Border(
                    left: BorderSide(color: AppColors.primaryDark, width: 4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _replyMessage!['sender'] == _myUid
                              ? 'You'
                              : (_partnerUsername ?? 'Partner'),
                          style: const TextStyle(
                              color: AppColors.primaryGlow,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _replyMessage!['text'] ?? 'Photo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                    onPressed: () => setState(() => _replyMessage = null),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.elevatedDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineDark),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: IconButton(
                          icon: Icon(
                              _showEmoji
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              color: AppColors.textSecondary,
                              size: 26),
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() => _showEmoji = !_showEmoji);
                          },
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          onChanged: _onTextChanged,
                          onTap: () => setState(() => _showEmoji = false),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          minLines: 1,
                          maxLines: 6,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Message',
                            hintStyle: TextStyle(
                                color: AppColors.textSecondary, fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file,
                                  color: AppColors.textSecondary, size: 24),
                              onPressed: _showAttachmentMenu,
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _msgCtrl,
                              builder: (context, value, child) {
                                if (value.text.trim().isEmpty) {
                                  return IconButton(
                                    icon: const Icon(Icons.camera_alt,
                                        color: AppColors.textSecondary,
                                        size: 24),
                                    onPressed: () =>
                                        _pickAndSendImage(ImageSource.camera),
                                  );
                                }
                                return const SizedBox(width: 8);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2.0),
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _msgCtrl,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText
                            ? _sendMessage
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Hold to record voice note')));
                              },
                        onLongPress: hasText ? null : _startRecording,
                        onLongPressEnd:
                            hasText ? null : (_) => _stopRecordingAndSend(),
                        child: Center(
                          child: Icon(
                            hasText
                                ? Icons.send
                                : (_isRecording
                                    ? Icons.stop_circle
                                    : Icons.mic),
                            color: Color(0xFF06211D),
                            size: _isRecording ? 32 : 24,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.outlineDark),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 28,
          runSpacing: 24,
          children: [
            _buildAttachIcon(Icons.insert_drive_file, AppColors.primaryDark,
                'Document', _pickAndSendDocument),
            _buildAttachIcon(
                Icons.camera_alt,
                AppColors.secondaryDark,
                'Camera',
                () => _pickAndSendImage(ImageSource.camera, popMenu: true)),
            _buildAttachIcon(Icons.image, AppColors.success, 'Gallery',
                () => _pickAndSendImage(ImageSource.gallery, popMenu: true)),
            _buildAttachIcon(Icons.headset, AppColors.accent, 'Audio', () {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio picker coming soon')));
            }),
            _buildAttachIcon(Icons.location_on, AppColors.primaryDark,
                'Location', _pickAndSendLocation),
            _buildAttachIcon(Icons.person, AppColors.primaryDark, 'Contact',
                () {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Contact sharing coming soon')));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachIcon(
      IconData icon, Color bgColor, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: bgColor,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source,
      {bool popMenu = false}) async {
    if (popMenu) context.pop();
    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null &&
          _roomId != null &&
          _myUid != null &&
          _partnerUid != null) {
        setState(() => _isUploading = true);

        final refStorage = FirebaseStorage.instance.ref().child(
            'chats/$_roomId/${DateTime.now().millisecondsSinceEpoch}.jpg');

        if (kIsWeb) {
          final bytes = await pickedFile.readAsBytes();
          await refStorage.putData(bytes);
        } else {
          final file = File(pickedFile.path);
          await refStorage.putFile(file);
        }

        final url = await refStorage.getDownloadURL();

        final replyMap = _replyMessage;
        setState(() {
          _isUploading = false;
          _isViewOnce = false; // Reset after use
          _replyMessage = null;
        });

        await ref.read(chatRepositoryProvider).sendMessage(
              roomId: _roomId!,
              senderId: _myUid!,
              receiverId: _partnerUid!,
              text: _isViewOnce ? 'Photo' : 'Image',
              type: 'image',
              mediaUrl: url,
              replyMessage: replyMap,
              isViewOnce: _isViewOnce,
            );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _pickAndSendDocument() async {
    context.pop();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'zip', 'xls', 'csv'],
        withData: kIsWeb,
      );

      if (result != null &&
          _roomId != null &&
          _myUid != null &&
          _partnerUid != null) {
        setState(() => _isUploading = true);

        final fileName = result.files.single.name;
        final refStorage = FirebaseStorage.instance.ref().child(
            'chats/$_roomId/${DateTime.now().millisecondsSinceEpoch}_$fileName');

        if (kIsWeb) {
          final fileBytes = result.files.single.bytes;
          await refStorage.putData(fileBytes!);
        } else {
          final filePath = result.files.single.path;
          await refStorage.putFile(File(filePath!));
        }

        final url = await refStorage.getDownloadURL();

        await ref.read(chatRepositoryProvider).sendMessage(
              roomId: _roomId!,
              senderId: _myUid!,
              receiverId: _partnerUid!,
              text: 'Document: $fileName',
              type: 'document',
              mediaUrl: url,
            );

        setState(() => _isUploading = false);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _pickAndSendLocation() async {
    context.pop();
    try {
      setState(() => _isUploading = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isUploading = false);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location services are disabled.')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isUploading = false);
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Location permissions are denied')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isUploading = false);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final url =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final replyMap = _replyMessage;
      setState(() {
        _isUploading = false;
        _isViewOnce = false;
        _replyMessage = null;
      });

      await ref.read(chatRepositoryProvider).sendMessage(
            roomId: _roomId!,
            senderId: _myUid!,
            receiverId: _partnerUid!,
            text: 'Location shared\n$url',
            type: 'location',
            replyMessage: replyMap,
          );
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null &&
          _roomId != null &&
          _myUid != null &&
          _partnerUid != null) {
        setState(() => _isUploading = true);

        final file = File(path);
        final refStorage = FirebaseStorage.instance.ref().child(
            'chats/$_roomId/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await refStorage.putFile(file);

        final url = await refStorage.getDownloadURL();

        final replyMap = _replyMessage;
        setState(() {
          _isUploading = false;
          _replyMessage = null;
        });

        await ref.read(chatRepositoryProvider).sendMessage(
              roomId: _roomId!,
              senderId: _myUid!,
              receiverId: _partnerUid!,
              text: 'Voice note',
              type: 'audio',
              mediaUrl: url,
              replyMessage: replyMap,
            );
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isUploading = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to send audio: $e')));
    }
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  const _AudioPlayerBubble({required this.url});

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.setSourceUrl(widget.url);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });

    _player.onDurationChanged.listen((newDuration) {
      if (mounted) setState(() => _duration = newDuration);
    });

    _player.onPositionChanged.listen((newPosition) {
      if (mounted) setState(() => _position = newPosition);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[700],
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play(UrlSource(widget.url));
              }
            },
            child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF8696A0), size: 32),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: _duration.inSeconds > 0
                      ? _position.inSeconds / _duration.inSeconds
                      : 0.0,
                  backgroundColor: Colors.white24,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF53BDEB)),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                    Text(_formatDuration(_duration),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
