import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/chat_controller.dart';

class ShareContentBottomSheet extends ConsumerStatefulWidget {
  final String? postId;
  final String? reelId;
  final String? userId; // for sharing a profile
  final String? eventId; // for sharing an event
  final String shareType; // 'post', 'reel', 'profile', 'event'

  const ShareContentBottomSheet({
    super.key,
    this.postId,
    this.reelId,
    this.userId,
    this.eventId,
    required this.shareType,
  });

  @override
  ConsumerState<ShareContentBottomSheet> createState() => _ShareContentBottomSheetState();
}

class _ShareContentBottomSheetState extends ConsumerState<ShareContentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedReceiverIds = {};
  final Set<String> _sentReceiverIds = {};
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _dispatchSendToUser(String receiverId, String commentText) {
    final notifier = ref.read(chatProvider(receiverId).notifier);
    final targetPostId = widget.postId ?? widget.reelId;
    final targetReelId = widget.reelId ?? widget.postId;
    final shareType = widget.shareType;
    final userId = widget.userId;
    final eventId = widget.eventId;

    if (shareType == 'post') {
      notifier.sendMessage(
        commentText.isEmpty ? 'Shared a post' : commentText,
        type: 'shared_post',
        referencedPostId: targetPostId,
      );
    } else if (shareType == 'reel') {
      notifier.sendMessage(
        commentText.isEmpty ? 'Shared a reel' : commentText,
        type: 'shared_reel',
        referencedReelId: targetReelId,
      );
    } else if (shareType == 'profile') {
      notifier.sendMessage(
        commentText.isEmpty ? 'Shared a profile' : commentText,
        type: 'shared_profile',
        referencedUserId: userId,
      );
    } else if (shareType == 'event') {
      notifier.sendMessage(
        commentText.isEmpty ? 'Shared an event' : commentText,
        type: 'shared_event',
        referencedEventId: eventId,
      );
    }
  }

  void _handleQuickSend(String receiverId, String receiverName) {
    if (_sentReceiverIds.contains(receiverId)) return;

    final commentText = _commentController.text.trim();
    _dispatchSendToUser(receiverId, commentText);

    setState(() {
      _sentReceiverIds.add(receiverId);
      _selectedReceiverIds.remove(receiverId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sent to $receiverName!'),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleBatchSend() {
    if (_selectedReceiverIds.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    final commentText = _commentController.text.trim();
    final receivers = List<String>.from(_selectedReceiverIds);

    // 1. Immediately dismiss modal to keep UX snappy
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shared with ${receivers.length} ${receivers.length == 1 ? "person" : "people"}!'),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );

    // 2. Dispatch in background
    for (final receiverId in receivers) {
      _dispatchSendToUser(receiverId, commentText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(profileListProvider);
    final myId = ref.watch(loggedInUserIdProvider);

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
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header title & share preview
            Row(
              children: [
                Text(
                  'Share to Chat',
                  style: GoogleFonts.outfit(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _buildContentBadge(),
              ],
            ),
            const SizedBox(height: 12),

            // Content preview strip
            _buildContentPreviewStrip(),
            const SizedBox(height: 12),

            // Instagram-style message input with attached comment hint
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _commentController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Write a message... (attached to shared item)',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                  prefixIcon: const Icon(Icons.mode_comment_outlined, color: AppTheme.primaryColor, size: 18),
                  suffixIcon: _commentController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                          onPressed: () {
                            setState(() => _commentController.clear());
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Search people field
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search followers & athletes...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),

            // Followers / People List
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                error: (err, _) => Center(
                  child: Text('Error loading contacts: $err', style: const TextStyle(color: Colors.redAccent)),
                ),
                data: (profiles) {
                  final list = profiles.where((p) => p.id != myId).toList();

                  // Sort: followed users first, then alphabetically
                  list.sort((a, b) {
                    if (a.isFollowing && !b.isFollowing) return -1;
                    if (!a.isFollowing && b.isFollowing) return 1;
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });

                  final filtered = list.where((p) {
                    if (_searchQuery.isEmpty) return true;
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        p.username.toLowerCase().contains(_searchQuery) ||
                        p.sport.toLowerCase().contains(_searchQuery) ||
                        p.role.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No connections found.' : 'No matches for "$_searchQuery"',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      final isSelected = _selectedReceiverIds.contains(profile.id);
                      final isSent = _sentReceiverIds.contains(profile.id);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: (profile.avatarUrl.isNotEmpty &&
                                      (profile.avatarUrl.startsWith('http://') || profile.avatarUrl.startsWith('https://')))
                                  ? NetworkImage(profile.avatarUrl)
                                  : null,
                              backgroundColor: Colors.white10,
                              child: (profile.avatarUrl.isEmpty ||
                                      (!profile.avatarUrl.startsWith('http://') && !profile.avatarUrl.startsWith('https://')))
                                  ? const Icon(Icons.person, size: 20, color: Colors.white54)
                                  : null,
                            ),
                            if (profile.isFollowing)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star, size: 8, color: Colors.black),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, color: Colors.blue, size: 13),
                            ],
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            if (profile.isFollowing) ...[
                              Text(
                                'Following • ',
                                style: TextStyle(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            Flexible(
                              child: Text(
                                '${profile.role} • ${profile.sport}',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Quick Send Button (Instagram Style)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSent
                                    ? Colors.white12
                                    : (isSelected ? Colors.white24 : AppTheme.primaryColor),
                                foregroundColor: isSent ? Colors.white54 : (isSelected ? Colors.white : Colors.black),
                                minimumSize: const Size(60, 30),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              onPressed: isSent
                                  ? null
                                  : () => _handleQuickSend(profile.id, profile.name),
                              child: Text(
                                isSent ? 'Sent' : 'Send',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Multi-select Checkbox
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedReceiverIds.remove(profile.id);
                                  } else {
                                    _selectedReceiverIds.add(profile.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryColor : Colors.white24,
                                    width: 1.5,
                                  ),
                                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedReceiverIds.remove(profile.id);
                            } else {
                              _selectedReceiverIds.add(profile.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Batch Send Button (when multiple selected)
            if (_selectedReceiverIds.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleBatchSend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Send to ${_selectedReceiverIds.length} ${_selectedReceiverIds.length == 1 ? "person" : "people"}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBadge() {
    IconData icon;
    String label;
    Color color = AppTheme.primaryColor;

    switch (widget.shareType) {
      case 'event':
        icon = Icons.calendar_month_rounded;
        label = 'Event';
        break;
      case 'reel':
        icon = Icons.video_library_rounded;
        label = 'Reel';
        break;
      case 'profile':
        icon = Icons.person_rounded;
        label = 'Profile';
        break;
      case 'post':
      default:
        icon = Icons.feed_rounded;
        label = 'Post';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreviewStrip() {
    if (widget.shareType == 'event' && widget.eventId != null) {
      final eventAsync = ref.watch(sharedEventDetailsProvider(widget.eventId!));
      return eventAsync.maybeWhen(
        data: (event) {
          if (event == null) return const SizedBox.shrink();
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.white10,
                    child: (event.bannerThumbnailUrl.isNotEmpty || event.bannerUrl.isNotEmpty)
                        ? Image.network(
                            event.bannerThumbnailUrl.isNotEmpty ? event.bannerThumbnailUrl : event.bannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.event, color: Colors.white38, size: 20),
                          )
                        : const Icon(Icons.event, color: Colors.white38, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${event.sport} • ${event.venue}, ${event.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      );
    }

    if ((widget.shareType == 'post' || widget.shareType == 'reel') && (widget.postId != null || widget.reelId != null)) {
      final targetId = widget.postId ?? widget.reelId!;
      final postAsync = ref.watch(sharedPostDetailsProvider(targetId));
      return postAsync.maybeWhen(
        data: (post) {
          if (post == null) return const SizedBox.shrink();
          final mediaUrl = post.media.isNotEmpty ? (post.media.first.thumbnailUrl ?? post.media.first.mediaUrl) : '';
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: Colors.white10,
                    child: mediaUrl.isNotEmpty
                        ? Image.network(
                            mediaUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.white38, size: 20),
                          )
                        : const Icon(Icons.feed, color: Colors.white38, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName.isNotEmpty ? post.userName : 'Athlete',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.content.isNotEmpty ? post.content : 'Shared content',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        orElse: () => const SizedBox.shrink(),
      );
    }

    return const SizedBox.shrink();
  }
}
