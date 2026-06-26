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
import '../../../../config/theme.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/avatar_util.dart';
import '../../../../core/widgets/app_chrome.dart';
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

const _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String? _roomId;
  String? _myUid;
  String? _partnerUid;
  String? _partnerUsername;

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmoji = false;
  bool _isUploading = false;
  Map<String, dynamic>? _replyMessage;
  String? _editingMessageId;

  bool _isSearching = false;
  String _searchQuery = '';

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
          if (!mounted) return;

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
    if (_msgCtrl.text.trim().isEmpty || _roomId == null || _myUid == null || _partnerUid == null) {
      return;
    }

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    _onTextChanged(''); // Reset typing

    if (_editingMessageId != null) {
      final editId = _editingMessageId!;
      setState(() => _editingMessageId = null);
      ref
          .read(chatRepositoryProvider)
          .editMessage(_roomId!, editId, text)
          .catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to edit: $e')));
        }
      });
      return;
    }

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

  void _startEdit(Map<String, dynamic> data, String msgId) {
    setState(() {
      _editingMessageId = msgId;
      _replyMessage = null;
      _msgCtrl.text = data['text'] ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingMessageId = null;
      _msgCtrl.clear();
    });
  }

  Future<void> _forwardMessage(Map<String, dynamic> data) async {
    if (_roomId == null || _myUid == null || _partnerUid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forward message'),
        content: Text(
            'Forward this message to ${_partnerUsername ?? 'your partner'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Forward')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(chatRepositoryProvider).forwardMessage(
          roomId: _roomId!,
          senderId: _myUid!,
          receiverId: _partnerUid!,
          data: data,
        );
  }

  void _markAsSeenIfNeeded(Map<String, dynamic> data, String msgId) {
    if (data['receiver'] == _myUid && data['seen'] == false) {
      ref.read(chatRepositoryProvider).markAsSeen(_roomId!, msgId);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _searchCtrl.dispose();
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
      appBar: _buildAppBar(),
      body: AppBackground(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            _buildPinnedBanner(),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildMessageList(),
            ),
            if (_isUploading)
              const LinearProgressIndicator(color: AppColors.primaryDark),
            if (!_isSearching) _buildMessageComposer(),
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
    if (_isSearching) {
      return AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() {
            _isSearching = false;
            _searchCtrl.clear();
            _searchQuery = '';
          }),
        ),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Search messages',
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      );
    }

    return AppBar(
      elevation: 0,
      titleSpacing: 0,
      leadingWidth: 75,
      leading: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(AppGlass.radiusPill),
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
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              _buildPartnerStatus(),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
            tooltip: 'Video call',
            icon: const Icon(Icons.videocam_rounded),
            onPressed: () {}),
        IconButton(
            tooltip: 'Voice call',
            icon: const Icon(Icons.call_rounded),
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
            } else if (val == 'search') {
              setState(() => _isSearching = true);
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
                      fontWeight: FontWeight.w600));
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

  Widget _buildPinnedBanner() {
    if (_roomId == null) return const SizedBox.shrink();

    return ref.watch(roomStreamProvider(_roomId!)).when(
          data: (roomDoc) {
            final pinnedIds =
                (roomDoc.data() as Map<String, dynamic>?)?['pinnedMessageIds']
                        as List? ??
                    [];
            if (pinnedIds.isEmpty) return const SizedBox.shrink();
            final lastPinnedId = pinnedIds.last as String;

            return ref.watch(chatMessagesProvider(_roomId!)).when(
                  data: (snap) {
                    final match = snap.docs.where((d) => d.id == lastPinnedId);
                    final text = match.isNotEmpty
                        ? ((match.first.data()
                                as Map<String, dynamic>)['text'] ??
                            'Media message')
                        : 'Pinned message';

                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                        border: Border.all(color: AppColors.borderStrong),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.push_pin_rounded,
                              size: 18, color: AppColors.primaryGlow),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pinnedIds.length > 1
                                      ? 'Pinned message (${pinnedIds.length})'
                                      : 'Pinned message',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryGlow),
                                ),
                                Text(text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Unpin',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => ref
                                .read(chatRepositoryProvider)
                                .togglePinMessage(_roomId!, lastPinnedId, false),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  Widget _buildSearchResults() {
    if (_roomId == null) return const SizedBox.shrink();
    final query = _searchQuery.trim().toLowerCase();

    return ref.watch(chatMessagesProvider(_roomId!)).when(
          data: (snapshot) {
            if (query.isEmpty) {
              return const Center(
                  child: Text('Type to search messages in this chat',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            final matches = snapshot.docs.where((d) {
              final text =
                  ((d.data() as Map<String, dynamic>)['text'] ?? '').toString();
              return text.toLowerCase().contains(query);
            }).toList();

            if (matches.isEmpty) {
              return const Center(
                  child: Text('No messages found',
                      style: TextStyle(color: AppColors.textSecondary)));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final data = matches[index].data() as Map<String, dynamic>;
                final isMe = data['sender'] == _myUid;
                final time = data['createdAt'] != null
                    ? DateFormat('MMM d, HH:mm')
                        .format((data['createdAt'] as Timestamp).toDate())
                    : '';
                return ListTile(
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.elevatedDark,
                    backgroundImage: isMe
                        ? AvatarUtil.getAvatarProvider(
                            FirebaseAuth.instance.currentUser?.email)
                        : AvatarUtil.getPartnerAvatarProvider(
                            FirebaseAuth.instance.currentUser?.email),
                  ),
                  title: Text(data['text'] ?? '',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle:
                      Text('${isMe ? 'You' : (_partnerUsername ?? 'Partner')} · $time'),
                  onTap: () => setState(() {
                    _isSearching = false;
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        );
  }

  Widget _buildMessageList() {
    if (_roomId == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryGlow));
    }

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
      dateStr = 'Today';
    } else if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day - 1) {
      dateStr = 'Yesterday';
    } else {
      dateStr = DateFormat('dd/MM/yyyy').format(date);
    }

    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.elevatedDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppGlass.radiusPill),
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Text(dateStr,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe, String msgId,
      {bool showTail = true}) {
    final text = data['text'] ?? '';
    final isDeleted = data['isDeleted'] ?? false;
    final isEdited = data['isEdited'] == true;
    final isPinned = data['isPinned'] == true;
    final isForwarded = data['isForwarded'] == true;
    final reactions = (data['reactions'] as Map<String, dynamic>?) ?? {};
    final time = data['createdAt'] != null
        ? DateFormat('HH:mm').format((data['createdAt'] as Timestamp).toDate())
        : '';
    final seen = data['seen'] ?? false;
    final delivered = data['delivered'] ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMe
        ? (isDark ? AppColors.myBubbleDark : AppColors.myBubbleLight)
        : (isDark ? AppColors.partnerBubbleDark : AppColors.partnerBubbleLight);
    final bubbleTextColor = isDark ? AppColors.textPrimary : AppColors.textOnLight;
    final bubbleMutedColor =
        isDark ? AppColors.textSecondary : AppColors.textMutedLight;
    final nestedFillColor = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.06);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showMessageOptions(data, msgId, isMe),
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
                  bottom: showTail ? 4 : 3,
                  left: isMe ? 60 : (showTail ? 16 : 24),
                  right: isMe ? (showTail ? 16 : 24) : 60,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(AppGlass.radius),
                  border: Border.all(color: AppColors.borderStrong),
                  boxShadow: AppGlass.softShadow(
                      blur: 16, offset: const Offset(0, 6)),
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (isForwarded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.forward_rounded,
                                size: 14, color: bubbleMutedColor),
                            const SizedBox(width: 4),
                            Text('Forwarded',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: bubbleMutedColor)),
                          ],
                        ),
                      ),
                    if (data['replyMessage'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: nestedFillColor,
                          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                          border: const Border(
                              left: BorderSide(
                                  color: AppColors.primaryGlow, width: 3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['replyMessage']['sender'] == _myUid
                                  ? 'You'
                                  : (_partnerUsername ?? 'Partner'),
                              style: const TextStyle(
                                  color: AppColors.primaryGlow,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data['replyMessage']['text'] ?? 'Photo',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: bubbleMutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    if (data['type'] == 'document' && data['mediaUrl'] != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: nestedFillColor,
                          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.insert_drive_file_rounded,
                                color: bubbleTextColor, size: 30),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                text.replaceFirst('Document: ', ''),
                                style: TextStyle(
                                    color: bubbleTextColor,
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
                          color: nestedFillColor,
                          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: bubbleTextColor, size: 30),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                text.split('\n').first,
                                style: TextStyle(
                                    color: bubbleTextColor,
                                    fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (data['type'] == 'audio' && data['mediaUrl'] != null)
                      _AudioPlayerBubble(
                        url: data['mediaUrl'],
                        foreground: bubbleTextColor,
                        muted: bubbleMutedColor,
                      ),
                    if (data['type'] == 'image')
                      if (data['isViewOnce'] == true)
                        _buildViewOnceMedia(data, isMe, msgId)
                      else if (data['mediaUrl'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
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
                              color: isDeleted ? bubbleMutedColor : bubbleTextColor,
                              fontSize: 16,
                              fontStyle:
                                  isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPinned)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.push_pin_rounded,
                                    size: 12, color: bubbleMutedColor),
                              ),
                            if (isEdited && !isDeleted)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text('edited',
                                    style: TextStyle(
                                        color: bubbleMutedColor, fontSize: 11)),
                              ),
                            Text(time,
                                style:
                                    TextStyle(color: bubbleMutedColor, fontSize: 11)),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                seen
                                    ? Icons.done_all_rounded
                                    : (delivered ? Icons.done_all_rounded : Icons.done_rounded),
                                size: 16,
                                color: seen
                                    ? AppColors.primaryGlow
                                    : bubbleMutedColor,
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
          if (reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: showTail ? 10 : 3,
                left: isMe ? 0 : 24,
                right: isMe ? 24 : 0,
              ),
              child: _ReactionChips(
                reactions: reactions,
                myUid: _myUid,
                onTap: (emoji) => ref
                    .read(chatRepositoryProvider)
                    .toggleReaction(_roomId!, msgId, _myUid!, emoji),
              ),
            ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> data, String msgId, bool isMe) {
    final isStarred = (data['starredBy'] as List?)?.contains(_myUid) ?? false;
    final isPinned = data['isPinned'] == true;
    final isDeleted = data['isDeleted'] ?? false;
    final canEdit = isMe && !isDeleted && (data['type'] ?? 'text') == 'text';

    showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final emoji in _quickReactions)
                        GestureDetector(
                          onTap: () {
                            context.pop();
                            ref.read(chatRepositoryProvider).toggleReaction(
                                _roomId!, msgId, _myUid!, emoji);
                          },
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Reply'),
                  onTap: () {
                    context.pop();
                    setState(() => _replyMessage = data);
                  },
                ),
                if (canEdit)
                  ListTile(
                    leading: const Icon(Icons.edit_rounded),
                    title: const Text('Edit'),
                    onTap: () {
                      context.pop();
                      _startEdit(data, msgId);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.forward_rounded),
                  title: const Text('Forward'),
                  onTap: () {
                    context.pop();
                    _forwardMessage(data);
                  },
                ),
                ListTile(
                  leading: Icon(
                      isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                  title: Text(isPinned ? 'Unpin' : 'Pin'),
                  onTap: () {
                    context.pop();
                    ref
                        .read(chatRepositoryProvider)
                        .togglePinMessage(_roomId!, msgId, !isPinned);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copy'),
                  onTap: () {
                    context.pop();
                    Clipboard.setData(ClipboardData(text: data['text'] ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')));
                  },
                ),
                ListTile(
                  leading: Icon(isStarred ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber),
                  title: Text(isStarred ? 'Unstar' : 'Star'),
                  onTap: () {
                    context.pop();
                    ref.read(chatRepositoryProvider).toggleStarMessage(
                        _roomId!, msgId, _myUid!, !isStarred);
                  },
                ),
                if (isMe && !isDeleted)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded,
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
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('Delete for me'),
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
                      decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.borderStrong)),
                      child: const Icon(Icons.close,
                          color: AppColors.textPrimary, size: 24),
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
          color: AppColors.backgroundDark.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
          border: Border.all(
              color: opened ? AppColors.textSecondary : AppColors.primaryGlow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              opened ? Icons.drafts_outlined : Icons.looks_one_rounded,
              color: opened ? AppColors.textSecondary : AppColors.primaryGlow,
            ),
            const SizedBox(width: 8),
            Text(
              opened ? 'Opened' : 'Photo · View once',
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
          if (_editingMessageId != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.elevatedDark,
                borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                border: Border.all(color: AppColors.primaryDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.primaryGlow),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Editing message',
                        style: TextStyle(
                            color: AppColors.primaryGlow,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: _cancelEdit,
                  ),
                ],
              ),
            )
          else if (_replyMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.elevatedDark,
                borderRadius: BorderRadius.circular(AppGlass.radiusSmall),
                border: const Border(
                  top: BorderSide(color: AppColors.borderStrong),
                  right: BorderSide(color: AppColors.borderStrong),
                  bottom: BorderSide(color: AppColors.borderStrong),
                  left: BorderSide(color: AppColors.primaryDark, width: 4),
                ),
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
                    borderRadius: BorderRadius.circular(AppGlass.radiusPill),
                    border: Border.all(color: AppColors.borderStrong),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: IconButton(
                          icon: Icon(
                              _showEmoji
                                  ? Icons.keyboard_rounded
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
                              color: AppColors.textPrimary, fontSize: 16),
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
                              icon: const Icon(Icons.attach_file_rounded,
                                  color: AppColors.textSecondary, size: 24),
                              onPressed: _showAttachmentMenu,
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _msgCtrl,
                              builder: (context, value, child) {
                                if (value.text.trim().isEmpty) {
                                  return IconButton(
                                    icon: const Icon(Icons.camera_alt_rounded,
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
                  decoration: BoxDecoration(
                    gradient: _isRecording ? null : AppColors.primaryGradient,
                    color: _isRecording ? AppColors.error : null,
                    shape: BoxShape.circle,
                    boxShadow: AppGlass.softShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.35),
                        blur: 16,
                        offset: const Offset(0, 6)),
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
                                ? (_editingMessageId != null
                                    ? Icons.check_rounded
                                    : Icons.send_rounded)
                                : (_isRecording
                                    ? Icons.stop_circle_rounded
                                    : Icons.mic_rounded),
                            color: Colors.white,
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
          borderRadius: BorderRadius.circular(AppGlass.radius),
          border: Border.all(color: AppColors.borderStrong),
          boxShadow: AppGlass.softShadow(),
        ),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 28,
          runSpacing: 24,
          children: [
            _buildAttachIcon(Icons.insert_drive_file_rounded, AppColors.primaryDark,
                'Document', _pickAndSendDocument),
            _buildAttachIcon(
                Icons.camera_alt_rounded,
                AppColors.secondaryDark,
                'Camera',
                () => _pickAndSendImage(ImageSource.camera, popMenu: true)),
            _buildAttachIcon(Icons.image_rounded, AppColors.success, 'Gallery',
                () => _pickAndSendImage(ImageSource.gallery, popMenu: true)),
            _buildAttachIcon(
                Icons.bolt_rounded,
                AppColors.accent,
                'View once',
                () => _pickAndSendImage(ImageSource.gallery,
                    popMenu: true, viewOnce: true)),
            _buildAttachIcon(Icons.headset_rounded, AppColors.accent, 'Audio', () {
              context.pop();
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio picker coming soon')));
            }),
            _buildAttachIcon(Icons.location_on_rounded, AppColors.primaryDark,
                'Location', _pickAndSendLocation),
            _buildAttachIcon(Icons.person_rounded, AppColors.primaryDark, 'Contact',
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
      borderRadius: BorderRadius.circular(AppGlass.radiusPill),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: AppGlass.softShadow(
                  color: bgColor.withValues(alpha: 0.4),
                  blur: 14,
                  offset: const Offset(0, 6)),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source,
      {bool popMenu = false, bool viewOnce = false}) async {
    if (popMenu) context.pop();
    try {
      final picker = ImagePicker();
      final pickedFile =
          await picker.pickImage(source: source, imageQuality: 70);
      if (!mounted) return;
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
        if (!mounted) return;

        final replyMap = _replyMessage;
        setState(() {
          _isUploading = false;
          _replyMessage = null;
        });

        await ref.read(chatRepositoryProvider).sendMessage(
              roomId: _roomId!,
              senderId: _myUid!,
              receiverId: _partnerUid!,
              text: viewOnce ? 'Photo' : 'Image',
              type: 'image',
              mediaUrl: url,
              replyMessage: replyMap,
              isViewOnce: viewOnce,
            );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
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
      if (!mounted) return;

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
        if (!mounted) return;

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
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _pickAndSendLocation() async {
    context.pop();
    try {
      setState(() => _isUploading = true);

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;
      if (!serviceEnabled) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Location services are disabled.')));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!mounted) return;
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!mounted) return;
        if (permission == LocationPermission.denied) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied')));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions are permanently denied, we cannot request permissions.')));
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      final url =
          'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';

      final replyMap = _replyMessage;
      setState(() {
        _isUploading = false;
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
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!mounted) return;
      if (hasPermission) {
        final dir = await getTemporaryDirectory();
        final filePath =
            '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );
        if (!mounted) return;

        setState(() {
          _isRecording = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')));
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
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
        if (!mounted) return;

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
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send audio: $e')));
    }
  }
}

class _ReactionChips extends StatelessWidget {
  final Map<String, dynamic> reactions;
  final String? myUid;
  final ValueChanged<String> onTap;

  const _ReactionChips(
      {required this.reactions, required this.myUid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    var myEmoji = '';
    for (final entry in reactions.entries) {
      final emoji = entry.value as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (entry.key == myUid) myEmoji = emoji;
    }

    return Wrap(
      spacing: 6,
      children: counts.entries.map((entry) {
        final isMine = entry.key == myEmoji;
        return GestureDetector(
          onTap: () => onTap(entry.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMine
                  ? AppColors.primaryDark.withValues(alpha: 0.2)
                  : AppColors.elevatedDark,
              borderRadius: BorderRadius.circular(AppGlass.radiusPill),
              border: Border.all(
                  color: isMine ? AppColors.primaryDark : AppColors.borderStrong),
            ),
            child: Text('${entry.key} ${entry.value}',
                style: const TextStyle(fontSize: 12)),
          ),
        );
      }).toList(),
    );
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  final Color foreground;
  final Color muted;

  const _AudioPlayerBubble({
    required this.url,
    required this.foreground,
    required this.muted,
  });

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}

class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasStarted = false;
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

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _hasStarted = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else if (_hasStarted) {
      await _player.resume();
    } else {
      _hasStarted = true;
      await _player.play(UrlSource(widget.url));
    }
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.foreground,
                shape: BoxShape.circle,
              ),
              child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppColors.textDark, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds / _duration.inSeconds
                        : 0.0,
                    backgroundColor: widget.muted.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(widget.foreground),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position),
                        style: TextStyle(color: widget.muted, fontSize: 10)),
                    Text(_formatDuration(_duration),
                        style: TextStyle(color: widget.muted, fontSize: 10)),
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
