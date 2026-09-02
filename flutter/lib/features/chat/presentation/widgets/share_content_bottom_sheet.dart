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
  final String shareType; // 'post', 'reel', 'profile'

  const ShareContentBottomSheet({
    super.key,
    this.postId,
    this.reelId,
    this.userId,
    required this.shareType,
  });

  @override
  ConsumerState<ShareContentBottomSheet> createState() => _ShareContentBottomSheetState();
}

class _ShareContentBottomSheetState extends ConsumerState<ShareContentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedReceiverIds = {};
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (_selectedReceiverIds.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    final commentText = _commentController.text.trim();
    final receivers = List<String>.from(_selectedReceiverIds);
    final targetPostId = widget.postId ?? widget.reelId;
    final targetReelId = widget.reelId ?? widget.postId;
    final shareType = widget.shareType;
    final userId = widget.userId;

    // 1. Immediately dismiss modal with 0ms latency to prevent double taps
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Content shared successfully!'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );

    // 2. Dispatch sending asynchronously in background
    for (final receiverId in receivers) {
      final notifier = ref.read(chatProvider(receiverId).notifier);
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
      }
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
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text(
              'Share to Chat',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search people to share with...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a message (optional)...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                error: (err, _) => Center(child: Text('Error loading profiles: $err', style: const TextStyle(color: Colors.redAccent))),
                data: (profiles) {
                  final list = profiles.where((p) => p.id != myId).toList();

                  final filtered = list.where((p) {
                    if (_searchQuery.isEmpty) return true;
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        p.username.toLowerCase().contains(_searchQuery) ||
                        p.sport.toLowerCase().contains(_searchQuery) ||
                        p.role.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No people found.',
                        style: TextStyle(color: Colors.white38),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final profile = filtered[index];
                      final isSelected = _selectedReceiverIds.contains(profile.id);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(profile.avatarUrl),
                          backgroundColor: Colors.white10,
                        ),
                        title: Row(
                          children: [
                            Text(
                              profile.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            if (profile.verified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Colors.blue,
                                size: 13,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '${profile.role} • ${profile.sport}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                        trailing: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.white24,
                              width: 2,
                            ),
                            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.black)
                              : null,
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReceiverIds.isEmpty ? null : _handleSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.white10,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Send',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: _selectedReceiverIds.isEmpty ? Colors.white24 : Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
