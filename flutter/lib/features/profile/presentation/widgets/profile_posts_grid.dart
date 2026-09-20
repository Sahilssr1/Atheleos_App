import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../feed/presentation/screens/user_posts_viewer_screen.dart';
import '../controllers/profile_controller.dart';
import '../../../clips/presentation/screens/clips_screen.dart';
import '../../../../core/utils/user_facing_error.dart';

class ProfilePostsGrid extends ConsumerStatefulWidget {
  final String userId;

  const ProfilePostsGrid({super.key, required this.userId});

  @override
  ConsumerState<ProfilePostsGrid> createState() => _ProfilePostsGridState();
}

class _ProfilePostsGridState extends ConsumerState<ProfilePostsGrid> {
  String _selectedTab = 'posts'; // 'posts' | 'saved_posts' | 'saved_clips'

  @override
  Widget build(BuildContext context) {
    final loggedInId = ref.watch(loggedInUserIdProvider);
    final isOwner = loggedInId == widget.userId;

    // Determine what provider to watch
    AsyncValue<List<PostModel>> postsAsync;
    if (_selectedTab == 'posts') {
      postsAsync = ref.watch(userPostsProvider(widget.userId));
    } else {
      postsAsync = ref.watch(bookmarkedPostsProvider);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Tab Selector (Only shown if isOwner is true)
        if (isOwner) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                _buildTabButton('posts', 'POSTS'),
                const SizedBox(width: 8),
                _buildTabButton('saved_posts', 'SAVED POSTS'),
                const SizedBox(width: 8),
                _buildTabButton('saved_clips', 'SAVED CLIPS'),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2. Grid Body
        postsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            ),
          ),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Text(
                UserFacingError.message(err, fallback: 'Unable to load posts right now.'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (allPosts) {
            // Apply filtering based on selected tab
            List<PostModel> displayPosts = [];
            if (_selectedTab == 'posts') {
              displayPosts = allPosts;
            } else if (_selectedTab == 'saved_posts') {
              // Saved posts: show bookmarked items with image media
              displayPosts = allPosts.where((p) => !p.hasVideo).toList();
            } else if (_selectedTab == 'saved_clips') {
              // Saved clips: show bookmarked items with video media
              displayPosts = allPosts.where((p) => p.hasVideo).toList();
            }

            // Keep only posts with media
            final mediaPosts = displayPosts.where((p) => p.media.isNotEmpty).toList();

            if (mediaPosts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 40,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedTab == 'posts'
                            ? 'NO POSTS GALLERY YET'
                            : _selectedTab == 'saved_posts'
                                ? 'NO SAVED POSTS YET'
                                : 'NO SAVED CLIPS YET',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: Text(
                    '${_selectedTab.replaceAll('_', ' ').toUpperCase()} GALLERY (${mediaPosts.length})',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: AppTheme.primaryColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mediaPosts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                    childAspectRatio: 1.0,
                  ),
                  itemBuilder: (context, idx) {
                    final post = mediaPosts[idx];
                    final mediaItem = post.media.first;
                    final isVideo = mediaItem.mediaType == 'video';
                    final thumbnailUrl = mediaItem.thumbnailUrl ?? mediaItem.mediaUrl;

                    return GestureDetector(
                      onTap: () {
                        if (_selectedTab == 'posts') {
                          // Unified feed: opens the scrollable viewer for BOTH pictures and reels.
                          // Reels can be tapped inside that feed to enter fullscreen mode.
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserPostsViewerScreen.forUser(
                                userId: widget.userId,
                                initialPostId: post.id,
                                title: 'Posts',
                              ),
                            ),
                          );
                        } else if (_selectedTab == 'saved_clips') {
                          // Saved Clips tab goes directly to the fullscreen Reels Viewer
                          final reels = mediaPosts.where((p) => p.hasVideo).toList();
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
                        } else {
                          // Saved gallery: browse the bookmarked image posts.
                          final imagePosts = mediaPosts.where((p) => !p.hasVideo).toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserPostsViewerScreen.forPosts(
                                posts: imagePosts,
                                initialPostId: post.id,
                                title: 'Saved Posts',
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: thumbnailUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 360,
                              memCacheHeight: 360,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF0F172A),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.white24),
                              ),
                            ),
                            if (isVideo)
                              Container(
                                color: const Color(0x3D000000),
                                child: const Center(
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: Colors.black54,
                                    child: Icon(
                                      Icons.play_arrow,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    final isSelected = _selectedTab == tabKey;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedTab = tabKey;
          });
        }
      },
      backgroundColor: const Color(0xFF0F172A),
      selectedColor: AppTheme.primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.05),
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
    );
  }
}
