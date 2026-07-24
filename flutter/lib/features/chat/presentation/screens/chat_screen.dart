import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/chat_message.dart';
import '../controllers/chat_controller.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String receiverId;

  const ChatScreen({super.key, this.receiverId = 'coach_1'});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ref.read(chatProvider(widget.receiverId).notifier).sendMessage(text);
    _messageController.clear();
    _chatFocusNode.unfocus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.receiverId));
    final receiverProfileAsync = ref.watch(userProvider(widget.receiverId));
    final myId = ref.watch(loggedInUserIdProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
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
        title: receiverProfileAsync.when(
          loading: () => const Text('Loading...', style: TextStyle(color: Colors.white70, fontSize: 14)),
          error: (err, stack) => const Text('Direct Message', style: TextStyle(color: Colors.white, fontSize: 14)),
          data: (profile) {
            final name = profile?.name ?? 'Coach/Athlete';
            final role = profile?.role ?? 'Atheleos User';
            final avatarUrl = profile?.avatarUrl ?? 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200&h=200';
            return GestureDetector(
              onTap: () {
                context.push('/profile/${widget.receiverId}');
              },
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(avatarUrl),
                    radius: 17,
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
                          style: GoogleFonts.inter(color: AppTheme.primaryColor, fontSize: 9),
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
      body: Column(
        children: [
          // Message stream list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isOwn = msg.senderId == myId;
                final hour = msg.timestamp.hour > 12 ? msg.timestamp.hour - 12 : (msg.timestamp.hour == 0 ? 12 : msg.timestamp.hour);
                final minute = msg.timestamp.minute.toString().padLeft(2, '0');
                final period = msg.timestamp.hour >= 12 ? 'PM' : 'AM';
                final formattedTime = '$hour:$minute $period';                return Align(
                  alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onDoubleTap: () {
                      ref.read(chatProvider(widget.receiverId).notifier).toggleReaction(msg.id, '❤️');
                    },
                    onLongPress: () {
                      _showReactionAndOptionsBottomSheet(context, msg, isOwn);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isOwn ? AppTheme.primaryColor : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: isOwn ? const Radius.circular(12) : Radius.zero,
                          bottomRight: isOwn ? Radius.zero : const Radius.circular(12),
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Story reply thumbnail preview (like Instagram!)
                          if (msg.storyMediaUrl != null && msg.storyMediaUrl!.isNotEmpty) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
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
                                  style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                          MentionText(
                            text: msg.content,
                            style: TextStyle(
                              fontSize: 13,
                              color: isOwn ? Colors.black : Colors.white,
                              height: 1.4,
                            ),
                            mentionStyle: TextStyle(
                              color: isOwn ? Colors.blue.shade900 : AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          
                          // Message Reaction pill display
                          if (msg.reactions.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: msg.reactions.entries.map((entry) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white10, width: 0.5),
                                  ),
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              formattedTime,
                              style: TextStyle(
                                fontSize: 9,
                                color: isOwn ? Colors.black54 : Colors.white38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Message input field
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MentionAutocompleteOverlay(
                      controller: _messageController,
                      focusNode: _chatFocusNode,
                      child: TextField(
                        controller: _messageController,
                        focusNode: _chatFocusNode,
                        onSubmitted: (_) => _sendMessage(),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Type your recruiting query...',
                          hintStyle: const TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReactionAndOptionsBottomSheet(BuildContext context, ChatMessage msg, bool isOwn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final chatNotifier = ref.read(chatProvider(widget.receiverId).notifier);
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
                        color: hasReacted ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
                        shape: BoxShape.circle,
                        border: hasReacted ? Border.all(color: AppTheme.primaryColor, width: 1.5) : null,
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
              if (isOwn)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: const Text('Unsend message', style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    // Confirm Dialog
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

