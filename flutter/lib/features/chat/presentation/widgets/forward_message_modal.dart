import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/chat_message.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/chat_list_controller.dart';
import '../controllers/chat_controller.dart';

class ForwardMessageModal extends ConsumerStatefulWidget {
  final ChatMessage message;
  final String myId;

  const ForwardMessageModal({
    super.key,
    required this.message,
    required this.myId,
  });

  static Future<void> show(BuildContext context, ChatMessage message, String myId) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) => ForwardMessageModal(
        message: message,
        myId: myId,
      ),
    );
  }

  @override
  ConsumerState<ForwardMessageModal> createState() => _ForwardMessageModalState();
}

class _ForwardMessageModalState extends ConsumerState<ForwardMessageModal> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTargetIds = {}; // can be user IDs or group room IDs
  bool _isSending = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleForward() async {
    if (_selectedTargetIds.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final msg = widget.message;
    final repo = ref.read(chatRepositoryProvider);

    try {
      for (final targetId in _selectedTargetIds) {
        final isGroup = targetId.startsWith('group_');
        final roomId = isGroup ? targetId : ([widget.myId, targetId]..sort()).join('_');

        final forwardedMessage = ChatMessage(
          id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${widget.myId}',
          senderId: widget.myId,
          receiverId: isGroup ? '' : targetId,
          content: msg.content,
          timestamp: DateTime.now(),
          type: msg.type,
          referencedPostId: msg.referencedPostId,
          referencedReelId: msg.referencedReelId,
          referencedUserId: msg.referencedUserId,
          referencedEventId: msg.referencedEventId,
          gifProvider: msg.gifProvider,
          gifUrl: msg.gifUrl,
          gifId: msg.gifId,
          storyId: msg.storyId,
          storyMediaUrl: msg.storyMediaUrl,
          isForwarded: true,
          messageState: 'sent',
        );

        if (isGroup) {
          await repo.sendRoomMessage(roomId, forwardedMessage);
        } else {
          await repo.sendMessage(forwardedMessage);
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message forwarded to ${_selectedTargetIds.length} chat(s).'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to forward message: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRooms = ref.watch(chatListProvider);
    final profilesAsync = ref.watch(profileListProvider);
    final profiles = profilesAsync.maybeWhen(data: (l) => l, orElse: () => <ProfileModel>[]);

    // Combine recent chat rooms and all profiles for forwarding destinations
    final targetItems = <_ForwardTargetItem>[];

    for (final room in chatRooms) {
      if (room.isMessageRequestFor(widget.myId)) continue;
      if (room.isGroup) {
        targetItems.add(_ForwardTargetItem(
          id: room.id,
          name: room.name ?? 'Group Chat',
          subtitle: '${room.participantIds.length} members',
          avatarUrl: room.iconUrl ?? '',
          isGroup: true,
        ));
      } else {
        final otherId = room.participantIds.firstWhere((id) => id != widget.myId, orElse: () => '');
        final profile = profiles.where((p) => p.id == otherId).firstOrNull;
        targetItems.add(_ForwardTargetItem(
          id: otherId,
          name: profile?.name ?? 'Athlete',
          subtitle: profile != null ? '@${profile.username} • ${profile.sport}' : 'Direct Chat',
          avatarUrl: profile?.avatarUrl ?? '',
          isGroup: false,
          isVerified: profile?.verified ?? false,
        ));
      }
    }

    // Also add profiles that might not have an existing chat room yet
    final existingIds = targetItems.map((e) => e.id).toSet();
    for (final p in profiles) {
      if (p.id != widget.myId && !existingIds.contains(p.id)) {
        targetItems.add(_ForwardTargetItem(
          id: p.id,
          name: p.name,
          subtitle: '@${p.username} • ${p.sport}',
          avatarUrl: p.avatarUrl,
          isGroup: false,
          isVerified: p.verified,
        ));
      }
    }

    final filteredTargets = targetItems.where((t) {
      if (_searchQuery.isEmpty) return true;
      return t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: EdgeInsets.only(
          top: 16,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Forward Message',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Message Preview Box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: AppTheme.primaryColor, width: 3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_all_rounded, color: AppTheme.primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message.content.isNotEmpty
                          ? widget.message.content
                          : (widget.message.type == 'gif' ? 'GIF Message' : 'Media Message'),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: const InputDecoration(
                  hintText: 'Search chats & athletes...',
                  hintStyle: TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: Icon(Icons.search, color: Colors.white38, size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Target List
            Expanded(
              child: filteredTargets.isEmpty
                  ? const Center(
                      child: Text('No contacts found', style: TextStyle(color: Colors.white38, fontSize: 13)),
                    )
                  : ListView.builder(
                      itemCount: filteredTargets.length,
                      itemBuilder: (context, index) {
                        final target = filteredTargets[index];
                        final isSelected = _selectedTargetIds.contains(target.id);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundImage: (target.avatarUrl.isNotEmpty &&
                                    (target.avatarUrl.startsWith('http://') || target.avatarUrl.startsWith('https://')))
                                ? NetworkImage(target.avatarUrl)
                                : null,
                            backgroundColor: target.isGroup
                                ? AppTheme.primaryColor.withValues(alpha: 0.2)
                                : Colors.white10,
                            child: (target.avatarUrl.isEmpty ||
                                    (!target.avatarUrl.startsWith('http://') && !target.avatarUrl.startsWith('https://')))
                                ? Icon(
                                    target.isGroup ? Icons.groups_rounded : Icons.person,
                                    size: 18,
                                    color: target.isGroup ? AppTheme.primaryColor : Colors.white54,
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  target.name,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (target.isVerified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, color: Colors.blue, size: 13),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            target.subtitle,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : Colors.white30,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.black)
                                : null,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedTargetIds.remove(target.id);
                              } else {
                                _selectedTargetIds.add(target.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // Send / Forward Button
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedTargetIds.isNotEmpty ? AppTheme.primaryColor : const Color(0xFF1E293B),
                  foregroundColor: _selectedTargetIds.isNotEmpty ? Colors.black : Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: (_selectedTargetIds.isNotEmpty && !_isSending) ? _handleForward : null,
                child: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        _selectedTargetIds.isNotEmpty ? 'Forward (${_selectedTargetIds.length})' : 'Select destinations',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForwardTargetItem {
  final String id;
  final String name;
  final String subtitle;
  final String avatarUrl;
  final bool isGroup;
  final bool isVerified;

  const _ForwardTargetItem({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.isGroup,
    this.isVerified = false,
  });
}
