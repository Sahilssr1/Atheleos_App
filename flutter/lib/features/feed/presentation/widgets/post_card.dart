import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/post_media_widget.dart';
import '../../../../core/widgets/expandable_caption.dart';
import '../../domain/models/post_model.dart';
import '../controllers/feed_controller.dart';
import '../controllers/post_delete_controller.dart';
import '../screens/feed_screen.dart'
    show AnimatedLikeButton, AnimatedBookmarkButton, CommentBottomSheet;
import '../screens/edit_post_screen.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../../core/services/cache_manager.dart';
import '../controllers/like_controller.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

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
    HapticFeedback.lightImpact();
    ref.read(sharedLikeStateProvider.notifier).toggleLike(post);
  }

  void _handleBookmark(WidgetRef ref) {
    HapticFeedback.selectionClick();
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
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: Color(0xFF262626), width: 1),
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
              leading: const Icon(AthIcons.pencilSquare, color: Colors.white70, size: 22),
              title: const Text(
                'Edit',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final updated = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => EditPostScreen(postId: post.id)),
                );
                if (updated == true) {
                  ref.invalidate(feedPostsProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(AthIcons.trash, color: Colors.redAccent, size: 22),
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
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626), width: 1),
        ),
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

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(postDeleteControllerProvider).deletePost(post);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: AppTheme.primaryColor,
          duration: Duration(seconds: 2),
        ),
      );
      onDeleted?.call();
    } catch (e) {
      debugPrint('Error deleting post: $e');
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Failed to delete post. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = DateTime.now().difference(post.createdAt);
    final postTime = d.inDays >= 1 ? '${d.inDays}d' : d.inHours >= 1 ? '${d.inHours}h' : '${d.inMinutes}m';
    final loggedInId = ref.watch(loggedInUserIdProvider);
    final isOwner = loggedInId.isNotEmpty && loggedInId == post.userId;
    final likeState = ref.watch(postLikeProvider(post));

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x14FFFFFF), width: 1),
        ),
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Profile Avatar, Details and Category Chip
              Builder(builder: (context) {
                final displayName = post.userName.trim().isNotEmpty ? post.userName.trim() : 'Athlete';

                // Resolve avatar: if post.userAvatar is empty or invalid, fallback to current user or profile cache
                String resolvedAvatar = post.userAvatar.trim();
                if (resolvedAvatar.isEmpty || !resolvedAvatar.startsWith('http')) {
                  if (isOwner) {
                    final myProfile = ref.watch(activeProfileProvider).valueOrNull;
                    if (myProfile != null && myProfile.avatarUrl.trim().startsWith('http')) {
                      resolvedAvatar = myProfile.avatarUrl.trim();
                    }
                  }
                  if (resolvedAvatar.isEmpty || !resolvedAvatar.startsWith('http')) {
                    final profiles = ref.watch(profileListProvider).valueOrNull ?? [];
                    final matched = profiles.where((p) => p.id == post.userId || (post.userName.isNotEmpty && p.username.toLowerCase() == post.userName.toLowerCase())).firstOrNull;
                    if (matched != null && matched.avatarUrl.trim().startsWith('http')) {
                      resolvedAvatar = matched.avatarUrl.trim();
                    }
                  }
                }

                return Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        context.push('/profile/${post.userId}');
                      },
                      child: AppAvatar(
                        imageUrl: resolvedAvatar,
                        radius: 20,
                        name: displayName,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            context.push('/profile/${post.userId}');
                          },
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    letterSpacing: -0.15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (post.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(AthIcons.checkBadgeSolid, size: 14, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${post.sport} • ${post.position} • $postTime',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        if (post.location != null && post.location!.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(AthIcons.mapPin, size: 10, color: AppTheme.primaryColor),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  post.location!.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.category.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  // Owner-only options menu (Edit / Delete)
                  if (isOwner)
                    GestureDetector(
                      onTap: () => _showOwnerMenu(context, ref),
                      child: Container(
                        padding: const EdgeInsets.only(left: 8),
                        child: const Icon(AthIcons.ellipsisVertical, color: Colors.white60, size: 20),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 12),

            // Content Caption Text
            ExpandableCaption(
              text: post.content,
              mentions: post.mentions,
              trimLength: 95,
              trimLines: 2,
              style: const TextStyle(fontSize: 14, height: 1.55, letterSpacing: -0.1, color: Color(0xE6FFFFFF)),
              actionStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.60),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
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
                  HapticFeedback.mediumImpact();
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

            Divider(color: const Color(0xFF1E1E1E), height: 12),

            // Action Buttons Bar
            Row(
              children: [
                Expanded(
                  child: _PostAction(
                    onTap: () => _handleLike(ref),
                    icon: AnimatedLikeButton(
                      isLiked: likeState.isLiked,
                      onTap: () => _handleLike(ref),
                    ),
                    label: 'Like',
                  ),
                ),
                Expanded(
                  child: _PostAction(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => CommentBottomSheet(
                          post: post,
                          onCommentAdded: (newCount) {},
                        ),
                      );
                    },
                    icon: const Icon(AthIcons.chatRound, color: Colors.white, size: 22),
                    label: 'Comment',
                  ),
                ),
                Expanded(
                  child: _PostAction(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        useRootNavigator: true,
                        builder: (context) => ShareContentBottomSheet(
                          postId: post.id,
                          reelId: post.hasVideo ? post.id : null,
                          shareType: post.hasVideo ? 'reel' : 'post',
                        ),
                      );
                    },
                    icon: const Icon(AthIcons.send, color: Colors.white, size: 22),
                    label: 'Share',
                  ),
                ),
                AnimatedBookmarkButton(
                  isBookmarked: post.hasBookmarked,
                  onTap: () => _handleBookmark(ref),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _PostAction extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final String label;

  const _PostAction({
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
