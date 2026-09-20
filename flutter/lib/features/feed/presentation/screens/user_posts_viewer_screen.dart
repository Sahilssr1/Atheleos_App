import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/post_model.dart';
import '../controllers/feed_controller.dart';
import '../widgets/post_card.dart';
import '../../../clips/presentation/screens/clips_screen.dart';
import '../../../../core/utils/user_facing_error.dart';

/// Instagram-style vertical posts viewer.
///
/// Opened when tapping an image/text post in a profile grid (or any other
/// surface such as Search, Notifications or saved galleries). It starts from
/// the tapped post and lets the user scroll up/down through the rest of the
/// posts, each rendered with the full-featured [PostCard] (like, comment,
/// share, bookmark, profile navigation, owner delete).
///
/// Two modes:
///  * User mode ([UserPostsViewerScreen.forUser]) — streams only that user's
///    posts from Firestore (query scoped by userId, real-time updates).
///  * List mode ([UserPostsViewerScreen.forPosts]) — renders a fixed list
///    (e.g. saved/bookmarked posts).
class UserPostsViewerScreen extends ConsumerStatefulWidget {
  final String? userId;
  final List<PostModel>? posts;
  final String initialPostId;
  final String title;

  const UserPostsViewerScreen.forUser({
    super.key,
    required String this.userId,
    required this.initialPostId,
    this.title = 'Posts',
  }) : posts = null;

  const UserPostsViewerScreen.forPosts({
    super.key,
    required List<PostModel> this.posts,
    required this.initialPostId,
    this.title = 'Posts',
  }) : userId = null;

  @override
  ConsumerState<UserPostsViewerScreen> createState() => _UserPostsViewerScreenState();
}

class _UserPostsViewerScreenState extends ConsumerState<UserPostsViewerScreen> {
  final Key _centerKey = const ValueKey('posts_viewer_anchor');

  /// The post the viewer is anchored on (initially the tapped post).
  late String _anchorPostId;

  /// Local copy used in list mode so deletions update immediately.
  List<PostModel>? _localPosts;

  @override
  void initState() {
    super.initState();
    _anchorPostId = widget.initialPostId;
    if (widget.posts != null) {
      _localPosts = List<PostModel>.from(widget.posts!);
    }
  }

  void _handleDeleted(List<PostModel> currentPosts, PostModel deleted) {
    // Keep the scroll anchored on a neighbouring post when the anchor is removed.
    if (deleted.id == _anchorPostId) {
      final idx = currentPosts.indexWhere((p) => p.id == deleted.id);
      String? newAnchor;
      if (idx != -1) {
        if (idx + 1 < currentPosts.length) {
          newAnchor = currentPosts[idx + 1].id;
        } else if (idx - 1 >= 0) {
          newAnchor = currentPosts[idx - 1].id;
        }
      }
      _anchorPostId = newAnchor ?? '';
    }

    if (_localPosts != null) {
      setState(() {
        _localPosts!.removeWhere((p) => p.id == deleted.id);
      });
      if (_localPosts!.isEmpty && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      // User mode: the Firestore stream removes the post automatically.
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: false,
        title: Text(
          widget.title.toUpperCase(),
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: widget.userId != null ? _buildUserMode() : _buildListMode(),
    );
  }

  Widget _buildUserMode() {
    final postsAsync = ref.watch(userPostsProvider(widget.userId!));

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            UserFacingError.message(err, fallback: 'Unable to load posts right now.'),
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (allPosts) {
        return _buildPostsList(allPosts);
      },
    );
  }

  Widget _buildListMode() {
    return _buildPostsList(_localPosts ?? const []);
  }

  Widget _buildPostsList(List<PostModel> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined, size: 40, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'NO POSTS YET',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    // Anchor the scroll view on the tapped post: posts before it are laid out
    // above (scroll up), the tapped post and the rest below (scroll down).
    int anchorIndex = posts.indexWhere((p) => p.id == _anchorPostId);
    if (anchorIndex == -1) anchorIndex = 0;

    final before = posts.sublist(0, anchorIndex);
    final after = posts.sublist(anchorIndex);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        child: CustomScrollView(
          anchor: 0.0,
          center: _centerKey,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Posts newer than the tapped one (rendered upwards).
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = before[before.length - 1 - index];
                    return _buildViewerCard(posts, post);
                  },
                  childCount: before.length,
                ),
              ),
            ),
            // The tapped post and everything after it.
            SliverPadding(
              key: _centerKey,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildViewerCard(posts, after[index]),
                  childCount: after.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerCard(List<PostModel> posts, PostModel post) {
    return PostCard(
      key: ValueKey('posts_viewer_${post.id}'),
      post: post,
      onDeleted: () => _handleDeleted(posts, post),
      onMediaTap: post.hasVideo ? () {
        final reels = posts.where((p) => p.hasVideo).toList();
        int initialIndex = reels.indexWhere((p) => p.id == post.id);
        if (initialIndex == -1) initialIndex = 0;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelsViewerScreen(
              clips: reels,
              initialIndex: initialIndex,
            ),
          ),
        );
      } : null,
    );
  }
}
