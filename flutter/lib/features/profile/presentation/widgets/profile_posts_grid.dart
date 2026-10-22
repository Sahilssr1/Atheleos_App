import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_media_thumbnail.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../feed/presentation/screens/user_posts_viewer_screen.dart';
import '../controllers/profile_controller.dart';
import '../../../clips/presentation/screens/clips_screen.dart';
import '../../../../core/utils/user_facing_error.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

enum _GridTab { posts, saved, clips }

/// Posts / Saved / Clips grid matching the website profile page.
class ProfilePostsGrid extends ConsumerStatefulWidget {
  final String userId;

  const ProfilePostsGrid({super.key, required this.userId});

  @override
  ConsumerState<ProfilePostsGrid> createState() => _ProfilePostsGridState();
}

class _ProfilePostsGridState extends ConsumerState<ProfilePostsGrid> {
  _GridTab _tab = _GridTab.posts;

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(loggedInUserIdProvider) == widget.userId;
    final tab = isOwner ? _tab : _GridTab.posts;

    final AsyncValue<List<PostModel>> postsAsync = tab == _GridTab.saved
        ? ref.watch(bookmarkedPostsProvider)
        : ref.watch(userPostsProvider(widget.userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwner)
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
            ),
            child: Row(
              children: [
                _tabButton(_GridTab.posts, 'Posts'),
                _tabButton(_GridTab.saved, 'Saved'),
                _tabButton(_GridTab.clips, 'Clips'),
              ],
            ),
          ),
        const SizedBox(height: 16),
        postsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Text(
              UserFacingError.message(err, fallback: 'Unable to load posts right now.'),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          data: (all) {
            final posts = tab == _GridTab.clips
                ? all.where((p) => p.hasVideo).toList()
                : all;
            if (posts.isEmpty) return _emptyState(tab);
            return GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemBuilder: (context, index) =>
                  _tile(context, posts, posts[index], tab),
            );
          },
        ),
      ],
    );
  }

  Widget _tabButton(_GridTab tab, String label) {
    final selected = _tab == tab;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? AppTheme.primaryColor
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(_GridTab tab) {
    final label = switch (tab) {
      _GridTab.saved => 'NO SAVED POSTS YET',
      _GridTab.clips => 'NO CLIPS YET',
      _GridTab.posts => 'NO POSTS YET',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(AthIcons.camera, size: 32, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, List<PostModel> posts, PostModel post, _GridTab tab) {
    if (tab == _GridTab.clips || post.hasVideo) {
      final reels = posts.where((p) => p.hasVideo).toList();
      final index = reels.indexWhere((p) => p.id == post.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsViewerScreen(
            clips: reels.isNotEmpty ? reels : [post],
            initialIndex: index < 0 ? 0 : index,
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => tab == _GridTab.saved
            ? UserPostsViewerScreen.forPosts(
                posts: posts,
                initialPostId: post.id,
                title: 'Saved',
              )
            : UserPostsViewerScreen.forUser(
                userId: widget.userId,
                initialPostId: post.id,
                title: 'Posts',
              ),
      ),
    );
  }

  Widget _tile(BuildContext context, List<PostModel> posts, PostModel post, _GridTab tab) {
    final media = post.media.isNotEmpty ? post.media.first : null;
    final isVideo = post.hasVideo || (media?.isVideo ?? false);

    Widget content;
    if (media == null) {
      content = Container(
        color: const Color(0x05FFFFFF),
        padding: const EdgeInsets.all(12),
        alignment: Alignment.center,
        child: Text(
          post.content,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      );
    } else {
      final imageUrl = isVideo ? (media.thumbnailUrl ?? '') : media.mediaUrl;
      content = AppMediaThumbnail(
        imageUrl: imageUrl,
        videoUrl: isVideo ? media.mediaUrl : null,
        isVideo: isVideo,
        fit: BoxFit.cover,
        memCacheWidth: 360,
        showPlayIcon: isVideo,
        playIconSize: 16,
      );
    }

    return GestureDetector(
      onTap: () => _open(context, posts, post, tab),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF171717),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        clipBehavior: Clip.antiAlias,
        child: content,
      ),
    );
  }
}
