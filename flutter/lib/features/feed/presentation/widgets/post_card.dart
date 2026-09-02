import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/post_media_widget.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../domain/models/post_model.dart';
import '../controllers/feed_controller.dart';
import '../controllers/post_delete_controller.dart';
import '../screens/feed_screen.dart'
    show AnimatedLikeButton, AnimatedBookmarkButton, CommentBottomSheet, ShareBottomSheet;
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../../core/services/cache_manager.dart';
import '../controllers/like_controller.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';

/// Reusable feed-style post card.
///
/// Used by the main Feed and the Instagram-style user posts viewer so both
/// share the exact same UI and functionality (like, comment, share, bookmark,
/// profile navigation and the owner-only edit/delete menu).
///
/// When [onToggleLike]/[onToggleBookmark] are not provided the card falls back
/// to writing directly through the repositories, which keeps Firestore-backed
/// streams (e.g. the user posts viewer) in sync in real time.
class PostCard extends ConsumerWidget {
  final PostModel post;

  /// Called with the current liked state when the like button is tapped.
  /// Called with the current bookmarked state when the bookmark is tapped.
  final void Function(bool currentlyBookmarked)? onToggleBookmark;

  /// Called after the post has been successfully deleted by its owner.
  final VoidCallback? onDeleted;
  final VoidCallback? onMediaTap;

  const PostCard({
    super.key,
    required this.post,
    this.onToggleBookmark,
    this.onDeleted,
    this.onMediaTap,
  });

  void _handleLike(WidgetRef ref) {
    ref.read(sharedLikeStateProvider.notifier).toggleLike(post);
  }

  void _handleBookmark(WidgetRef ref) {
    if (onToggleBookmark != null) {
      onToggleBookmark!(post.hasBookmarked);
      return;
    }
    final userId = ref.read(loggedInUserIdProvider);
    if (userId.isEmpty) return;
    if (post.hasBookmarked) {
      CacheManager().removeBookmarkedPostId(userId, post.id);
    } else {
      CacheManager().addBookmarkedPostId(userId, post.id);
    }
    ref.read(bookmarkRepositoryProvider).toggleBookmark(userId, post);
  }

  void _showOwnerMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70, size: 22),
              title: const Text(
                'Edit',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Editing posts is coming soon.'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
              title: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete post?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this post and its media. This action cannot be undone.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(postDeleteControllerProvider).deletePost(post);
      onDeleted?.call();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = DateTime.now().difference(post.createdAt);
    final postTime = d.inDays >= 1 ? '${d.inDays}d' : d.inHours >= 1 ? '${d.inHours}h' : '${d.inMinutes}m';
    final loggedInId = ref.watch(loggedInUserIdProvider);
    final isOwner = loggedInId.isNotEmpty && loggedInId == post.userId;
    final likeState = ref.watch(postLikeProvider(post));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.04)),
      ),
      color: const Color(0xFF0B1220),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Profile Avatar, Details and Category Chip
            Builder(builder: (context) {
              final displayName = post.userName.trim().isNotEmpty ? post.userName.trim() : 'Athlete';
              final hasValidAvatar = post.userAvatar.isNotEmpty &&
                  (post.userAvatar.startsWith('http://') || post.userAvatar.startsWith('https://'));

              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      context.go('/profile/${post.userId}');
                    },
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                      backgroundImage: hasValidAvatar ? CachedNetworkImageProvider(post.userAvatar) : null,
                      child: !hasValidAvatar
                          ? Text(
                              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            context.go('/profile/${post.userId}');
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              ),
                              if (post.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${post.sport} • ${post.position} • $postTime',
                          style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.category.name.toUpperCase(),
                      style: const TextStyle(color: AppTheme.primaryColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Owner-only options menu (Edit / Delete)
                  if (isOwner)
                    GestureDetector(
                      onTap: () => _showOwnerMenu(context, ref),
                      child: Container(
                        padding: const EdgeInsets.only(left: 8),
                        child: const Icon(Icons.more_vert, color: Colors.white60, size: 20),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),

            // Content Caption Text
            MentionText(
              text: post.content,
              mentions: post.mentions,
              style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xE6FFFFFF)),
            ),
            const SizedBox(height: 12),

            // Media Image with double-tap gesture to like
            if (post.media.isNotEmpty)
              AutoPlayVideoVisibilityWidget(
                mediaUrl: post.media.first.mediaUrl,
                mediaType: post.media.first.mediaType,
                thumbnailUrl: post.media.first.thumbnailUrl,
                mediaWidth: post.media.first.width,
                mediaHeight: post.media.first.height,
                isLiked: likeState.isLiked,
                onDoubleTapLike: () {
                  ref.read(sharedLikeStateProvider.notifier).toggleLike(post, forceLike: true);
                },
                onMediaTap: onMediaTap,
              ),
            const SizedBox(height: 8),

            // Engagement Count Indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  Text(
                    '${likeState.likesCount} likes',
                    style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.fiber_manual_record, size: 4, color: Colors.white24),
                  const SizedBox(width: 8),
                  Text(
                    '${post.commentsCount} comments',
                    style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.fiber_manual_record, size: 4, color: Colors.white24),
                  const SizedBox(width: 8),
                  Text(
                    '${post.shares} shares',
                    style: const TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Divider(color: Colors.white.withOpacity(0.04), height: 12),

            // Action Buttons Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Like Action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedLikeButton(
                      isLiked: likeState.isLiked,
                      onTap: () => _handleLike(ref),
                    ),
                    const Text('Like', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                  ],
                ),

                // Comment Action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white60, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => CommentBottomSheet(
                            post: post,
                            onCommentAdded: (newCount) {
                              // Comment counts sync reactively through Firestore.
                            },
                          ),
                        );
                      },
                    ),
                    const Text('Comment', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                  ],
                ),

                // Share Action
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white60, size: 20),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => ShareContentBottomSheet(
                            postId: post.id,
                            reelId: post.hasVideo ? post.id : null,
                            shareType: post.hasVideo ? 'reel' : 'post',
                          ),
                        );
                      },
                    ),
                    const Text('Share', style: TextStyle(fontSize: 11.5, color: Colors.white60)),
                  ],
                ),

                // Bookmark Action
                AnimatedBookmarkButton(
                  isBookmarked: post.hasBookmarked,
                  onTap: () => _handleBookmark(ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
