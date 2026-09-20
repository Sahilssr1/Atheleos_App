import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/expandable_caption.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../profile/presentation/controllers/settings_controller.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../clips/presentation/screens/clips_screen.dart' show ReelsViewerScreen;
import '../../domain/models/chat_message.dart';
import '../controllers/chat_controller.dart';
import '../controllers/chat_theme_controller.dart';
import 'shared_content_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? receiverId;
  final String? roomId;

  const ChatScreen({
    super.key,
    this.receiverId,
    this.roomId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final DateTime _creationTime = DateTime.now();
  ChatMessage? _replyingToMessage;
  String? _highlightedMessageId;

  String _resolveRoomId(String myId) {
    if (widget.roomId != null && widget.roomId!.isNotEmpty) {
      return widget.roomId!;
    }
    final rId = widget.receiverId ?? 'coach_1';
    final list = [myId, rId]..sort();
    return list.join('_');
  }

  String get _effectiveReceiverId {
    final myId = ref.read(loggedInUserIdProvider);
    if (widget.receiverId != null && widget.receiverId!.isNotEmpty) {
      return widget.receiverId!;
    }
    if (widget.roomId != null && widget.roomId!.isNotEmpty && !widget.roomId!.startsWith('group_')) {
      final parts = widget.roomId!.split('_');
      if (parts.length == 2) {
        return parts.first == myId ? parts.last : parts.first;
      }
    }
    return '';
  }

  String _getReplyAuthorName(ChatMessage msg, String myId, String receiverName) {
    if (msg.senderId == myId) {
      return 'You';
    }
    final senderProfile = ref.read(userProvider(msg.senderId)).valueOrNull;
    if (senderProfile != null && senderProfile.name.isNotEmpty) {
      return senderProfile.name;
    }
    return receiverName.isNotEmpty ? receiverName : 'Athlete';
  }

  String _getReplyContentSnippet(ChatMessage msg) {
    if (msg.type == 'shared_reel' || (msg.referencedReelId != null && msg.referencedReelId!.isNotEmpty)) {
      return '🎥 Reel';
    }
    if (msg.type == 'shared_post' || (msg.referencedPostId != null && msg.referencedPostId!.isNotEmpty)) {
      return '🖼️ Post';
    }
    if (msg.type == 'shared_profile' || (msg.referencedUserId != null && msg.referencedUserId!.isNotEmpty)) {
      return '👤 Profile';
    }
    if (msg.type == 'shared_event' || (msg.referencedEventId != null && msg.referencedEventId!.isNotEmpty)) {
      return '📅 Event';
    }
    if (msg.storyMediaUrl != null && msg.storyMediaUrl!.isNotEmpty) {
      return '📸 Story Reply';
    }
    return msg.content.isNotEmpty ? msg.content : 'Message';
  }

  void _onSwipeReply(ChatMessage msg) {
    setState(() {
      _replyingToMessage = msg;
    });
    _chatFocusNode.requestFocus();
  }

  final Map<String, GlobalKey> _messageKeys = {};

  void _scrollToAndHighlightMessage(String targetMessageId, String roomId) async {
    final messages = ref.read(roomChatProvider(roomId));
    final targetIndex = messages.indexWhere((m) => m.id == targetMessageId);
    if (targetIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message not found in recent history'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // Phase 1: If target is at the very beginning of chat (index 0 or 1), jump directly to maxScrollExtent!
    double targetOffset = 0.0;
    if (targetIndex <= 1) {
      targetOffset = _scrollController.position.maxScrollExtent;
    } else {
      // Calculate realistic accumulated heights taking reel cards, post cards, profile cards into account
      double accumulatedOffset = 0.0;
      for (int i = messages.length - 1; i > targetIndex; i--) {
        final m = messages[i];
        if (m.type == 'shared_reel' || (m.referencedReelId != null && m.referencedReelId!.isNotEmpty)) {
          accumulatedOffset += 450.0;
        } else if (m.type == 'shared_post' || (m.referencedPostId != null && m.referencedPostId!.isNotEmpty)) {
          accumulatedOffset += 380.0;
        } else if (m.type == 'shared_profile' || (m.referencedUserId != null && m.referencedUserId!.isNotEmpty)) {
          accumulatedOffset += 270.0;
        } else if (m.type == 'shared_event' || (m.referencedEventId != null && m.referencedEventId!.isNotEmpty)) {
          accumulatedOffset += 380.0;
        } else if (m.replyToContent != null && m.replyToContent!.isNotEmpty) {
          accumulatedOffset += 115.0;
        } else {
          final lineCount = (m.content.length / 28).ceil().clamp(1, 6);
          accumulatedOffset += 60.0 + (lineCount * 18.0);
        }
      }
      targetOffset = accumulatedOffset.clamp(0.0, _scrollController.position.maxScrollExtent);
    }

    // Scroll smoothly to estimated neighborhood
    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );

    // Phase 2: Micro-adjust with Scrollable.ensureVisible if key is present
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetKey = _messageKeys[targetMessageId];
      if (targetKey?.currentContext != null) {
        Scrollable.ensureVisible(
          targetKey!.currentContext!,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });

    // Phase 3: Trigger glowing blinking highlight on the target bubble
    setState(() {
      _highlightedMessageId = targetMessageId;
    });

    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _highlightedMessageId == targetMessageId) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final myId = ref.read(loggedInUserIdProvider);
    final roomId = _resolveRoomId(myId);
    final receiverProfile = ref.read(userProvider(_effectiveReceiverId)).valueOrNull;
    final receiverName = receiverProfile?.name ?? 'User';

    String? replyToId;
    String? replyToName;
    String? replyToText;

    if (_replyingToMessage != null) {
      replyToId = _replyingToMessage!.id;
      replyToName = _getReplyAuthorName(_replyingToMessage!, myId, receiverName);
      replyToText = _getReplyContentSnippet(_replyingToMessage!);
    }

    ref.read(roomChatProvider(roomId).notifier).sendMessage(
      text,
      replyToMessageId: replyToId,
      replyToSenderName: replyToName,
      replyToContent: replyToText,
    );

    _messageController.clear();
    setState(() {
      _replyingToMessage = null;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(loggedInUserIdProvider);
    final roomId = _resolveRoomId(myId);
    final isGroup = roomId.startsWith('group_');
    final receiverId = _effectiveReceiverId;

    final messages = ref.watch(roomChatProvider(roomId));
    final currentTheme = ref.watch(chatThemeProvider(roomId));

    // Group vs 1-to-1 Room details resolution
    final roomDetailsAsync = ref.watch(chatRoomDetailsProvider(roomId));
    final roomDetails = roomDetailsAsync.valueOrNull;
    final isMessageRequest = !isGroup && roomDetails != null && roomDetails.isMessageRequestFor(myId);
    final receiverProfileAsync = !isGroup && receiverId.isNotEmpty ? ref.watch(userProvider(receiverId)) : null;
    final allProfiles = ref.watch(profileListProvider).valueOrNull ?? [];
    ProfileModel? fallbackProfile;
    try {
      fallbackProfile = allProfiles.firstWhere((p) => p.id == receiverId || p.username == receiverId);
    } catch (_) {}
    final effectiveProfile = receiverProfileAsync?.valueOrNull ?? fallbackProfile;
    final receiverName = (effectiveProfile?.name.isNotEmpty == true)
        ? effectiveProfile!.name
        : (effectiveProfile?.username.isNotEmpty == true ? '@${effectiveProfile!.username}' : 'Athlete');

    final blockedList = ref.watch(blockedUsersStreamProvider).valueOrNull ?? [];
    final isBlocked = !isGroup && receiverId.isNotEmpty && blockedList.contains(receiverId);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: currentTheme.backgroundGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: AppBar(
                backgroundColor: currentTheme.appBarColor.withValues(alpha: 0.72),
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
                title: isGroup
                    ? (roomDetailsAsync?.when(
                        loading: () => const Text('Loading group...', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        error: (_, __) => const Text('Group Chat', style: TextStyle(color: Colors.white, fontSize: 14)),
                        data: (room) {
                          final groupName = room?.name?.isNotEmpty == true ? room!.name! : 'Group Chat';
                          final memberCount = room?.participantIds.length ?? 0;
                          final iconUrl = room?.iconUrl ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SharedContentScreen(
                                    roomId: roomId,
                                    receiverId: '',
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: (iconUrl.isNotEmpty && (iconUrl.startsWith('http://') || iconUrl.startsWith('https://')))
                                      ? NetworkImage(iconUrl)
                                      : null,
                                  radius: 17,
                                  backgroundColor: currentTheme.accentColor.withValues(alpha: 0.2),
                                  child: (iconUrl.isEmpty || (!iconUrl.startsWith('http://') && !iconUrl.startsWith('https://')))
                                      ? Icon(Icons.groups_rounded, size: 18, color: currentTheme.accentColor)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        groupName,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$memberCount members • Active now',
                                        style: GoogleFonts.inter(color: currentTheme.accentColor, fontSize: 9),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ) ?? const SizedBox.shrink())
                    : Builder(
                        builder: (context) {
                          final profile = effectiveProfile;
                          final name = (profile?.name.isNotEmpty == true)
                              ? profile!.name
                              : (profile?.username.isNotEmpty == true ? '@${profile!.username}' : 'Athlete');
                          final role = (profile?.role.isNotEmpty == true) ? profile!.role : 'Athlete';
                          final avatarUrl = profile?.avatarUrl ?? '';

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SharedContentScreen(
                                    roomId: roomId,
                                    receiverId: receiverId,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  onBackgroundImageError: (_, __) {},
                                  radius: 17,
                                  backgroundColor: Colors.white10,
                                  child: (avatarUrl.isEmpty || (!avatarUrl.startsWith('http://') && !avatarUrl.startsWith('https://')))
                                      ? const Icon(Icons.person, size: 18, color: Colors.white54)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '$role • Active now',
                                        style: GoogleFonts.inter(color: currentTheme.accentColor, fontSize: 9),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Message stream list with Loading and Empty States (REVERSE: TRUE FOR INSTANT BOTTOM PINNING)
            Expanded(
              child: messages.isEmpty
                  ? (ref.watch(chatRoomLoadingProvider(roomId))
                      ? _ChatScreenShimmerLoading(accentColor: currentTheme.accentColor)
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.white24),
                              SizedBox(height: 12),
                              Text(
                                'No messages yet',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Send a message to start chatting.',
                                style: TextStyle(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ))
                  : Builder(
                      builder: (context) {
                        final isLoadingMore = ref.watch(roomChatLoadingMoreProvider(roomId));
                        return ListView.builder(
                          controller: _scrollController,
                          reverse: true, // Opens at latest message automatically
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: messages.length + (isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Top batch loading indicator
                            if (index == messages.length) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: currentTheme.accentColor,
                                    ),
                                  ),
                                ),
                              );
                            }
                        final msg = messages[messages.length - 1 - index];
                        final isOwn = msg.senderId == myId;
                        final hour = msg.timestamp.hour > 12 ? msg.timestamp.hour - 12 : (msg.timestamp.hour == 0 ? 12 : msg.timestamp.hour);
                        final minute = msg.timestamp.minute.toString().padLeft(2, '0');
                        final period = msg.timestamp.hour >= 12 ? 'PM' : 'AM';
                        final formattedTime = '$hour:$minute $period';

                        final isSharedReel = msg.type == 'shared_reel' || (msg.referencedReelId != null && msg.referencedReelId!.isNotEmpty);
                        final isSharedPost = msg.type == 'shared_post' || (msg.referencedPostId != null && msg.referencedPostId!.isNotEmpty);
                        final isSharedProfile = msg.type == 'shared_profile' || (msg.referencedUserId != null && msg.referencedUserId!.isNotEmpty);
                        final isSharedEvent = msg.type == 'shared_event' || (msg.referencedEventId != null && msg.referencedEventId!.isNotEmpty);
                        final hasCustomCard = isSharedReel || isSharedPost || isSharedProfile || isSharedEvent;
                        final isHighlighted = msg.id == _highlightedMessageId;

                        // 1. STANDALONE CUSTOM CARDS (SHARED REEL, POST, PROFILE, EVENT) WITH SWIPE-TO-REPLY
                        final itemKey = _messageKeys.putIfAbsent(msg.id, () => GlobalKey());
                        if (hasCustomCard) {
                          return KeyedSubtree(
                            key: itemKey,
                            child: _AnimatedMessageBubble(
                              key: ValueKey(msg.id),
                              messageTimestamp: msg.timestamp,
                              creationTime: _creationTime,
                              isOwn: isOwn,
                              child: _SwipeToReplyWrapper(
                              isOwn: isOwn,
                              accentColor: currentTheme.accentColor,
                              onReply: () => _onSwipeReply(msg),
                              child: Align(
                                alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onDoubleTap: () {
                                      ref.read(roomChatProvider(roomId).notifier).toggleReaction(msg.id, '❤️');
                                    },
                                    onLongPress: () {
                                      _showReactionAndOptionsBottomSheet(context, msg, isOwn, roomId);
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 300),
                                      decoration: isHighlighted
                                          ? BoxDecoration(
                                              borderRadius: BorderRadius.circular(18),
                                              border: Border.all(color: currentTheme.accentColor, width: 2),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: currentTheme.accentColor.withValues(alpha: 0.4),
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            )
                                          : null,
                                      child: Column(
                                        crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isGroup && !isOwn)
                                            _SenderNameHeader(senderId: msg.senderId, accentColor: currentTheme.accentColor),
                                          if (isSharedReel)
                                            _SharedReelCard(
                                              reelId: msg.referencedReelId ?? '',
                                              isOwn: isOwn,
                                              formattedTime: formattedTime,
                                              messageState: msg.messageState,
                                              accentColor: currentTheme.accentColor,
                                            )
                                          else if (isSharedPost)
                                            _SharedPostCard(
                                              postId: msg.referencedPostId ?? '',
                                              isOwn: isOwn,
                                              formattedTime: formattedTime,
                                              messageState: msg.messageState,
                                              accentColor: currentTheme.accentColor,
                                            )
                                          else if (isSharedProfile)
                                            _SharedProfileCard(
                                              userId: msg.referencedUserId ?? '',
                                              isOwn: isOwn,
                                              formattedTime: formattedTime,
                                              messageState: msg.messageState,
                                              accentColor: currentTheme.accentColor,
                                            )
                                          else if (isSharedEvent)
                                            _SharedEventCard(
                                              eventId: msg.referencedEventId ?? '',
                                              isOwn: isOwn,
                                              formattedTime: formattedTime,
                                              messageState: msg.messageState,
                                              accentColor: currentTheme.accentColor,
                                            ),
                                          // Custom user note if provided (different from default)
                                          if (msg.content.isNotEmpty &&
                                              msg.content != 'Shared a reel' &&
                                              msg.content != 'Shared a post' &&
                                              msg.content != 'Shared a profile' &&
                                              msg.content != 'Shared an event')
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: isOwn
                                                    ? LinearGradient(
                                                        colors: currentTheme.bubbleGradient,
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      )
                                                    : null,
                                                color: isOwn ? null : currentTheme.receivedBubbleColor,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isOwn
                                                      ? currentTheme.accentColor.withValues(alpha: 0.25)
                                                      : Colors.white.withValues(alpha: 0.08),
                                                  width: 1,
                                                ),
                                              ),
                                              child: MentionText(
                                                text: msg.content,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: isOwn ? currentTheme.ownTextColor : Colors.white,
                                                ),
                                                mentionStyle: TextStyle(
                                                  color: isOwn ? Colors.blue.shade900 : currentTheme.accentColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                        }

                        // 2. STANDARD TEXT MESSAGE BUBBLE WITH SWIPE-TO-REPLY
                        return KeyedSubtree(
                          key: itemKey,
                          child: _AnimatedMessageBubble(
                            key: ValueKey(msg.id),
                            messageTimestamp: msg.timestamp,
                            creationTime: _creationTime,
                            isOwn: isOwn,
                            child: _SwipeToReplyWrapper(
                            isOwn: isOwn,
                            accentColor: currentTheme.accentColor,
                            onReply: () => _onSwipeReply(msg),
                            child: Align(
                              alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                              child: GestureDetector(
                                onDoubleTap: () {
                                  ref.read(roomChatProvider(roomId).notifier).toggleReaction(msg.id, '❤️');
                                },
                                onLongPress: () {
                                  _showReactionAndOptionsBottomSheet(context, msg, isOwn, roomId);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: isOwn
                                        ? LinearGradient(
                                            colors: currentTheme.bubbleGradient,
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isOwn ? null : currentTheme.receivedBubbleColor,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: isOwn ? const Radius.circular(16) : const Radius.circular(4),
                                      bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(16),
                                    ),
                                    border: Border.all(
                                      color: isHighlighted
                                          ? currentTheme.accentColor
                                          : (isOwn
                                              ? currentTheme.accentColor.withValues(alpha: 0.25)
                                              : Colors.white.withValues(alpha: 0.08)),
                                      width: isHighlighted ? 2 : 1,
                                    ),
                                    boxShadow: [
                                      if (isHighlighted)
                                        BoxShadow(
                                          color: currentTheme.accentColor.withValues(alpha: 0.5),
                                          blurRadius: 14,
                                          spreadRadius: 2,
                                        )
                                      else if (isOwn)
                                        BoxShadow(
                                          color: currentTheme.bubbleGradient.first.withValues(alpha: 0.18),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                    ],
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Sender Name in Group Chat
                                      if (isGroup && !isOwn)
                                        _SenderNameHeader(senderId: msg.senderId, accentColor: currentTheme.accentColor),

                                      // Quoted Reply Banner (Tapping jumps to & highlights original message!)
                                      if (msg.replyToContent != null && msg.replyToContent!.isNotEmpty) ...[
                                        GestureDetector(
                                          onTap: () {
                                            if (msg.replyToMessageId != null) {
                                              _scrollToAndHighlightMessage(msg.replyToMessageId!, roomId);
                                            }
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 5),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.25),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border(
                                                left: BorderSide(color: currentTheme.accentColor, width: 3),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  msg.replyToSenderName ?? 'Reply',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                    color: currentTheme.accentColor,
                                                  ),
                                                ),
                                                Text(
                                                  msg.replyToContent!,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Story Reply Preview
                                      if (msg.storyMediaUrl != null && msg.storyMediaUrl!.isNotEmpty) ...[
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          height: 120,
                                          width: 90,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: NetworkImage(msg.storyMediaUrl!),
                                              fit: BoxFit.cover,
                                            ),
                                            border: Border.all(color: Colors.white12),
                                          ),
                                          alignment: Alignment.topLeft,
                                          padding: const EdgeInsets.all(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Story Reply',
                                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Text Content
                                      MentionText(
                                        text: msg.content,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          color: isOwn ? currentTheme.ownTextColor : Colors.white,
                                          height: 1.35,
                                        ),
                                        mentionStyle: TextStyle(
                                          color: isOwn ? Colors.blue.shade900 : currentTheme.accentColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                        ),
                                      ),

                                      // Reactions
                                      if (msg.reactions.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            children: msg.reactions.entries.map((entry) {
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.35),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  entry.value,
                                                  style: const TextStyle(fontSize: 10),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],

                                      // Timestamp & Status (Snug fit with no spacer)
                                      const SizedBox(height: 3),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: isOwn
                                                  ? (currentTheme.ownTextColor == Colors.black ? Colors.black54 : Colors.white60)
                                                  : Colors.white38,
                                            ),
                                          ),
                                          if (isOwn) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              msg.messageState == 'sending'
                                                  ? 'sending...'
                                                  : (msg.messageState == 'failed' ? 'failed' : 'sent'),
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: msg.messageState == 'failed'
                                                    ? Colors.redAccent
                                                    : (currentTheme.ownTextColor == Colors.black ? Colors.black45 : Colors.white60),
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                      },
                        );
                      },
                    ),
            ),

            // Reply Preview Bar (when replying to a message)
            if (_replyingToMessage != null)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3.5,
                      height: 36,
                      decoration: BoxDecoration(
                        color: currentTheme.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.reply_rounded, color: currentTheme.accentColor, size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'Replying to ${_getReplyAuthorName(_replyingToMessage!, myId, receiverName)}',
                                style: TextStyle(
                                  color: currentTheme.accentColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getReplyContentSnippet(_replyingToMessage!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _replyingToMessage = null;
                        });
                      },
                    ),
                  ],
                ),
              ),

            // Message Request Action Banner
            if (isMessageRequest)
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mark_email_unread_outlined, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Message Request from $receiverName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Replying to this conversation will accept it and move it to your main Chats list. They won\'t know you\'ve seen it until you reply.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Block Button
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: Text('Block $receiverName?', style: const TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'They will not be able to message or find your profile.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Block', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                await SettingsActions(myId).blockUser(receiverId);
                                await FirebaseFirestore.instance.collection('chats').doc(roomId).delete();
                                if (context.canPop()) {
                                  context.pop();
                                }
                              }
                            },
                            child: const Text('Block', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete Button
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white70,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text('Delete Message Request?', style: TextStyle(color: Colors.white)),
                                  content: const Text(
                                    'This request will be removed from your inbox.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                await FirebaseFirestore.instance.collection('chats').doc(roomId).delete();
                                if (context.canPop()) {
                                  context.pop();
                                }
                              }
                            },
                            child: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Accept Button
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await ref.read(chatRepositoryProvider).acceptMessageRequest(roomId, myId);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Message request accepted! Moved to your Chats.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            child: const Text('Accept', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Message input field OR Blocked Account Notice
            if (isBlocked)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'You have blocked this account. You cannot send messages.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MentionAutocompleteOverlay(
                          controller: _messageController,
                          focusNode: _chatFocusNode,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _chatFocusNode,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.newline,
                                  minLines: 1,
                                  maxLines: 5,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Type your message...',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: currentTheme.accentColor.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(color: currentTheme.accentColor.withValues(alpha: 0.35), width: 1),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.send_rounded, color: currentTheme.accentColor, size: 20),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionAndOptionsBottomSheet(BuildContext context, ChatMessage msg, bool isOwn, String roomId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final chatNotifier = ref.read(roomChatProvider(roomId).notifier);
        final currentTheme = ref.read(chatThemeProvider(roomId));
        final emojis = ['❤️', '👍', '🔥', '😂', '😮', '😢'];

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji Quick Reactions Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: emojis.map((emoji) {
                  final hasReacted = msg.reactions.values.contains(emoji);
                  return GestureDetector(
                    onTap: () {
                      chatNotifier.toggleReaction(msg.id, emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasReacted ? currentTheme.accentColor.withValues(alpha: 0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: hasReacted ? Border.all(color: currentTheme.accentColor, width: 1.5) : null,
                      ),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10, height: 1),
              const SizedBox(height: 10),

              // Options
              ListTile(
                leading: Icon(Icons.reply_rounded, color: currentTheme.accentColor),
                title: const Text('Reply', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _onSwipeReply(msg);
                },
              ),
              if (isOwn)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Unsend message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const Text('Unsend message?', style: TextStyle(color: Colors.white)),
                        content: const Text(
                          'This will remove the message for everyone in this chat.',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Unsend', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await chatNotifier.unsendMessage(msg.id);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                title: const Text('Copy text', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: msg.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SenderNameHeader extends ConsumerWidget {
  final String senderId;
  final Color accentColor;

  const _SenderNameHeader({required this.senderId, required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProvider(senderId));
    final name = profileAsync.valueOrNull?.name;
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3, left: 2),
      child: Text(
        name,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.bold,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

// === SWIPE-TO-REPLY INTERACTIVE GESTURE WRAPPER ===

class _SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isOwn;
  final Color accentColor;

  const _SwipeToReplyWrapper({
    required this.child,
    required this.onReply,
    required this.isOwn,
    required this.accentColor,
  });

  @override
  State<_SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<_SwipeToReplyWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;
  static const double _triggerThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0.0, 75.0);
      if (_dragOffset >= _triggerThreshold && !_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.mediumImpact();
      } else if (_dragOffset < _triggerThreshold) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= _triggerThreshold) {
      widget.onReply();
    }
    final start = _dragOffset;
    final animation = Tween<double>(begin: start, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.reset();
    animation.addListener(() {
      setState(() {
        _dragOffset = animation.value;
      });
    });
    _controller.forward().then((_) {
      _hasTriggeredHaptic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerThreshold).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      children: [
        // Reply icon behind the bubble
        if (_dragOffset > 5)
          Positioned(
            left: (_dragOffset * 0.4) - 20,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + (0.4 * progress),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.accentColor.withValues(alpha: 0.5), width: 1),
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color: widget.accentColor,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),

        // Message content being dragged
        Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            behavior: HitTestBehavior.translucent,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

// === INSTAGRAM-STYLE SHARED CONTENT CARDS ===

class _SharedReelCard extends ConsumerWidget {
  final String reelId;
  final bool isOwn;
  final String formattedTime;
  final String messageState;
  final Color accentColor;

  const _SharedReelCard({
    required this.reelId,
    required this.isOwn,
    required this.formattedTime,
    required this.messageState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostDetailsProvider(reelId));
    final cardWidth = MediaQuery.of(context).size.width * 0.68;

    return postAsync.when(
      loading: () => Container(
        width: cardWidth.clamp(220.0, 260.0),
        height: 260,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
          ),
        ),
      ),
      error: (_, __) => Container(
        width: cardWidth.clamp(220.0, 260.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: const Center(
          child: Text('Reel unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Container(
            width: cardWidth.clamp(220.0, 260.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: const Center(
              child: Text('Reel unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          );
        }

        final mediaUrl = post.media.isNotEmpty ? (post.media.first.thumbnailUrl ?? post.media.first.mediaUrl) : '';
        final authorName = post.userName.isNotEmpty ? post.userName : 'Athlete';
        final authorAvatar = post.userAvatar;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReelsViewerScreen(clips: [post], initialIndex: 0),
              ),
            );
          },
          child: Container(
            width: cardWidth.clamp(220.0, 260.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: authorAvatar,
                        radius: 12,
                        name: authorName,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          authorName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.video_library_rounded, size: 14, color: accentColor),
                    ],
                  ),
                ),

                // Reel Video Thumbnail with Centered Play Button
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: 9 / 12,
                      child: mediaUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: mediaUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.black26),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.black26,
                                child: const Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 36),
                              ),
                            )
                          : Container(
                              color: Colors.black26,
                              child: const Icon(Icons.movie_creation_outlined, color: Colors.white24, size: 36),
                            ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),

                // Caption
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: ExpandableCaption(
                      text: post.content,
                      mentions: post.mentions,
                      trimLength: 70,
                      trimLines: 2,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      actionStyle: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),

                // Footer: Watch Reel Action & Timestamp
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Row(
                    children: [
                      Text(
                        'Watch Reel',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: accentColor),
                      const Spacer(),
                      Text(
                        formattedTime,
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        Text(
                          messageState == 'sending'
                              ? 'sending...'
                              : (messageState == 'failed' ? 'failed' : 'sent'),
                          style: TextStyle(
                            fontSize: 8,
                            color: messageState == 'failed' ? Colors.redAccent : Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SharedPostCard extends ConsumerWidget {
  final String postId;
  final bool isOwn;
  final String formattedTime;
  final String messageState;
  final Color accentColor;

  const _SharedPostCard({
    required this.postId,
    required this.isOwn,
    required this.formattedTime,
    required this.messageState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(sharedPostDetailsProvider(postId));
    final cardWidth = MediaQuery.of(context).size.width * 0.68;

    return postAsync.when(
      loading: () => Container(
        width: cardWidth.clamp(220.0, 260.0),
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
          ),
        ),
      ),
      error: (_, __) => Container(
        width: cardWidth.clamp(220.0, 260.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: const Center(
          child: Text('Post unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ),
      data: (post) {
        if (post == null) {
          return Container(
            width: cardWidth.clamp(220.0, 260.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: const Center(
              child: Text('Post unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          );
        }

        final firstMedia = post.media.isNotEmpty ? post.media.first : null;
        final isVideo = post.hasVideo || (firstMedia?.isVideo ?? false);
        final authorName = post.userName.isNotEmpty ? post.userName : 'Athlete';
        final authorAvatar = post.userAvatar;

        String mediaUrl = '';
        if (firstMedia != null) {
          if (firstMedia.thumbnailUrl != null && firstMedia.thumbnailUrl!.isNotEmpty) {
            mediaUrl = firstMedia.thumbnailUrl!;
          } else if (!isVideo) {
            mediaUrl = firstMedia.mediaUrl;
          } else if (firstMedia.mediaUrl.contains('/video/upload/')) {
            mediaUrl = firstMedia.mediaUrl
                .replaceAll('/video/upload/', '/video/upload/so_0/')
                .replaceAll(RegExp(r'\.(mp4|mov|webm)$', caseSensitive: false), '.jpg');
          }
        }

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReelsViewerScreen(clips: [post], initialIndex: 0),
                ),
              );
            } else {
              context.push('/post/${post.id}');
            }
          },
          child: Container(
            width: cardWidth.clamp(220.0, 260.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Creator Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      AppAvatar(
                        imageUrl: authorAvatar,
                        radius: 12,
                        name: authorName,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          authorName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isVideo ? Icons.video_library_rounded : Icons.feed_rounded,
                        size: 14,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),

                // Post Media Thumbnail (with play button overlay if video)
                if (mediaUrl.isNotEmpty || isVideo)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: isVideo ? 9 / 12 : 1.0,
                        child: mediaUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: mediaUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: Colors.black26),
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.black26,
                                  child: Icon(
                                    isVideo ? Icons.movie_creation_outlined : Icons.image_outlined,
                                    color: Colors.white24,
                                    size: 36,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.black26,
                                child: Icon(
                                  isVideo ? Icons.movie_creation_outlined : Icons.image_outlined,
                                  color: Colors.white24,
                                  size: 36,
                                ),
                              ),
                      ),
                      if (isVideo)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white24, width: 1),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                    ],
                  ),

                // Caption
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: ExpandableCaption(
                      text: post.content,
                      mentions: post.mentions,
                      trimLength: 70,
                      trimLines: 2,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                      actionStyle: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),

                // Footer: View Post & Timestamp
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                  child: Row(
                    children: [
                      Text(
                        isVideo ? 'Watch Reel' : 'View Post',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: accentColor),
                      const Spacer(),
                      Text(
                        formattedTime,
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        Text(
                          messageState == 'sending'
                              ? 'sending...'
                              : (messageState == 'failed' ? 'failed' : 'sent'),
                          style: TextStyle(
                            fontSize: 8,
                            color: messageState == 'failed' ? Colors.redAccent : Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SharedProfileCard extends ConsumerWidget {
  final String userId;
  final bool isOwn;
  final String formattedTime;
  final String messageState;
  final Color accentColor;

  const _SharedProfileCard({
    required this.userId,
    required this.isOwn,
    required this.formattedTime,
    required this.messageState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProvider(userId));
    final cardWidth = MediaQuery.of(context).size.width * 0.68;

    return profileAsync.maybeWhen(
      data: (profile) {
        if (profile == null) {
          return Container(
            width: cardWidth.clamp(220.0, 260.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Profile unavailable', style: TextStyle(color: Colors.white38, fontSize: 11)),
            ),
          );
        }

        final name = profile.name.isNotEmpty ? profile.name : 'Athlete';
        final username = profile.username.isNotEmpty ? '@${profile.username}' : '';
        final avatarUrl = profile.avatarUrl;
        final role = profile.role.isNotEmpty ? profile.role : 'Athlete';
        final sport = profile.sport.isNotEmpty ? profile.sport : '';

        return GestureDetector(
          onTap: () {
            context.push('/profile/$userId');
          },
          child: Container(
            width: cardWidth.clamp(220.0, 260.0),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  imageUrl: avatarUrl,
                  radius: 28,
                  name: name,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (username.isNotEmpty)
                  Text(
                    username,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    sport.isNotEmpty ? '$role • $sport' : role,
                    style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'View Profile',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      formattedTime,
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 4),
                      Text(
                        messageState == 'sending'
                            ? 'sending...'
                            : (messageState == 'failed' ? 'failed' : 'sent'),
                        style: TextStyle(
                          fontSize: 8,
                          color: messageState == 'failed' ? Colors.redAccent : Colors.white38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => Container(
        width: cardWidth.clamp(220.0, 260.0),
        height: 100,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
          ),
        ),
      ),
    );
  }
}

class _SharedEventCard extends ConsumerWidget {
  final String eventId;
  final bool isOwn;
  final String formattedTime;
  final String messageState;
  final Color accentColor;

  const _SharedEventCard({
    required this.eventId,
    required this.isOwn,
    required this.formattedTime,
    required this.messageState,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(sharedEventDetailsProvider(eventId));
    final cardWidth = MediaQuery.of(context).size.width * 0.72;

    return eventAsync.when(
      loading: () => Container(
        width: cardWidth.clamp(230.0, 275.0),
        height: 240,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
          ),
        ),
      ),
      error: (_, __) => Container(
        width: cardWidth.clamp(230.0, 275.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: const Center(
          child: Text('Event unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ),
      ),
      data: (event) {
        if (event == null) {
          return Container(
            width: cardWidth.clamp(230.0, 275.0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: const Center(
              child: Text('Event unavailable', style: TextStyle(color: Colors.white38, fontSize: 12)),
            ),
          );
        }

        final bannerUrl = event.bannerThumbnailUrl.isNotEmpty
            ? event.bannerThumbnailUrl
            : event.bannerUrl;
        final organizerAvatar = event.organizerAvatar;
        final organizerName = event.organizerName.isNotEmpty ? event.organizerName : 'Organizer';

        return GestureDetector(
          onTap: () {
            context.push('/events/${event.eventId}');
          },
          child: Container(
            width: cardWidth.clamp(230.0, 275.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOwn ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Organizer Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: (organizerAvatar.isNotEmpty && organizerAvatar.startsWith('http'))
                            ? NetworkImage(organizerAvatar)
                            : null,
                        backgroundColor: Colors.white10,
                        child: (organizerAvatar.isEmpty || !organizerAvatar.startsWith('http'))
                            ? const Icon(Icons.event_seat_rounded, size: 13, color: Colors.white54)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                organizerName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (event.verifiedOrganizer) ...[
                              const SizedBox(width: 3),
                              const Icon(Icons.verified, color: Colors.blue, size: 11),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 10, color: accentColor),
                            const SizedBox(width: 3),
                            Text(
                              event.sport.toUpperCase(),
                              style: TextStyle(color: accentColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Event Banner with Badges
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: bannerUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: bannerUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: Colors.black26),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFF1E293B),
                                child: const Center(
                                  child: Icon(Icons.sports_rounded, color: Colors.white24, size: 36),
                                ),
                              ),
                            )
                          : Container(
                              color: const Color(0xFF1E293B),
                              child: const Center(
                                child: Icon(Icons.sports_rounded, color: Colors.white24, size: 36),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.competitionLevel.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: event.eventStatus == 'Registration Open'
                              ? Colors.green
                              : (event.eventStatus == 'Upcoming' ? Colors.blue : Colors.red),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.eventStatus.toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),

                // 3. Title & Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 11, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            '${event.startDate.month}/${event.startDate.day}/${event.startDate.year}${event.startTime.isNotEmpty ? " • ${event.startTime}" : ""}',
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: Colors.white38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${event.venue}, ${event.city}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          ),
                          Text(
                            event.isFree ? 'FREE' : '\$${event.entryFee.toStringAsFixed(0)}',
                            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 4. Footer Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Row(
                    children: [
                      Text(
                        'View Event',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: accentColor),
                      const Spacer(),
                      Text(
                        formattedTime,
                        style: const TextStyle(fontSize: 9, color: Colors.white38),
                      ),
                      if (isOwn) ...[
                        const SizedBox(width: 4),
                        Text(
                          messageState == 'sending'
                              ? 'sending...'
                              : (messageState == 'failed' ? 'failed' : 'sent'),
                          style: TextStyle(
                            fontSize: 8,
                            color: messageState == 'failed' ? Colors.redAccent : Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// === SPRINGY SLIDE-IN, SCALE-IN, AND FADE-IN ANIMATION FOR MESSAGES ===

class _AnimatedMessageBubble extends StatefulWidget {
  final Widget child;
  final DateTime messageTimestamp;
  final DateTime creationTime;
  final bool isOwn;

  const _AnimatedMessageBubble({
    required Key key,
    required this.child,
    required this.messageTimestamp,
    required this.creationTime,
    required this.isOwn,
  }) : super(key: key);

  @override
  State<_AnimatedMessageBubble> createState() => _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends State<_AnimatedMessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    final shouldAnimate = widget.messageTimestamp.isAfter(widget.creationTime.subtract(const Duration(seconds: 2)));

    _controller = AnimationController(
      vsync: this,
      duration: shouldAnimate ? const Duration(milliseconds: 350) : Duration.zero,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.22),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.isOwn ? Alignment.centerRight : Alignment.centerLeft,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ChatScreenShimmerLoading extends StatefulWidget {
  final Color accentColor;
  const _ChatScreenShimmerLoading({required this.accentColor});

  @override
  State<_ChatScreenShimmerLoading> createState() => _ChatScreenShimmerLoadingState();
}

class _ChatScreenShimmerLoadingState extends State<_ChatScreenShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Opacity(
          opacity: _anim.value,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            reverse: true,
            children: [
              // Low-opacity professional note for first-time loading
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 20, left: 24, right: 24),
                  child: Text(
                    'Loading conversation for the first time may take some time...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              // Received bubble
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 190,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              // Sent bubble
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 140,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
              // Received media card
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 220,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Sent bubble
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  width: 170,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.22),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
