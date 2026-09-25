import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/atheleos_app_bar.dart';
import '../../../../core/services/sports_service.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../../core/services/mention_service.dart';
import '../../domain/models/post_model.dart';
import '../../domain/models/story_model.dart';
import '../../domain/models/comment_model.dart';
import '../controllers/feed_controller.dart';
import '../widgets/post_card.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import '../../../chat/presentation/controllers/chat_controller.dart';
import '../../../../core/widgets/post_media_widget.dart'
    show activeVideoUrlProvider, preloadedVideoUrlProvider;
import '../../../clips/presentation/screens/clips_screen.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/widgets/app_avatar.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        ref.read(feedPostsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Force-release the last-active + preloaded video controllers when the
    // Feed screen is torn down (tab switch, logout, etc.). `ref` is safe to
    // use during dispose on ConsumerState.
    try {
      ref.read(activeVideoUrlProvider.notifier).state = null;
      ref.read(preloadedVideoUrlProvider.notifier).state = null;
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final postsAsync = ref.watch(feedPostsProvider);

    return Scaffold(
      appBar: const AtheleosAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                child: RefreshIndicator(
                  color: AppTheme.primaryColor,
                  backgroundColor: const Color(0xFF121212),
                  onRefresh: () async {
                    await ref.read(feedPostsProvider.notifier).refresh();
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // 500 keeps just enough offscreen slivers alive for smooth
                    // fling scrolling without pinning many video controllers /
                    // decoded bitmaps in RAM.
                    cacheExtent: 500.0,
                    slivers: [
                      // Stories row scrolls with the page
                      SliverToBoxAdapter(child: _buildStoriesSection(context, ref)),

                      SliverToBoxAdapter(
                        child: Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      ),

                      // Create post card scrolls with the page
                      SliverToBoxAdapter(child: _buildCreatePostCard(context)),

                      // Category chips scroll with the page
                      SliverToBoxAdapter(
                        child: _buildCategoriesRow(context, ref, selectedCategory),
                      ),

                      // Sport and Sorting Header
                      SliverToBoxAdapter(
                        child: _buildSortAndFilterHeader(context, ref, ref.watch(feedSortProvider)),
                      ),

                      // Sport chips scroll with the page
                      SliverToBoxAdapter(
                        child: _buildSportsRow(context, ref, ref.watch(selectedSportProvider)),
                      ),

                      // Posts
                      ...postsAsync.when(
                        loading: () => [
                          const SliverToBoxAdapter(
                            child: _FeedScreenShimmerLoading(),
                          ),
                        ],
                        error: (err, stack) => [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              child: Center(
                                child: Text(
                                  UserFacingError.message(err, fallback: 'Unable to load feed right now.'),
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                        data: (posts) {
                          if (posts.isEmpty) {
                            return [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 60),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.sports_rounded,
                                        size: 48,
                                        color: Colors.white.withOpacity(0.15),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No highlights in this category yet.',
                                        style: TextStyle(color: Colors.white38, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ];
                          }
                          return [
                            SliverPadding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 8,
                                bottom: 84,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index == posts.length) {
                                      final notifier = ref.watch(feedPostsProvider.notifier);
                                      if (notifier.hasMore) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 24),
                                          child: Center(
                                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                                          ),
                                        );
                                      } else {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 32),
                                          child: Center(
                                            child: Text(
                                              'No more posts to load.',
                                              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    // Smart background prefetching for media (deferred to post-frame to keep build pure)
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        ref.read(feedPostsProvider.notifier).prefetchMediaForIndex(index, posts);
                                      }
                                    });
                                    return _buildPostCard(context, ref, posts[index], theme);
                                  },
                                  childCount: posts.length + 1,
                                ),
                              ),
                            ),
                          ];
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoriesSection(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(feedStoriesProvider);

    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: storiesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (err, stack) {
          // If error occurs, render own story upload button rather than breaking UI
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildMyStoryButton(context, ref, null),
            ],
          );
        },
        data: (stories) {
          // Group stories by userId and preserve the order of the first appearance
          final Map<String, List<StoryModel>> groupedStories = {};
          final List<String> userIds = [];
          
          for (final story in stories) {
            if (!groupedStories.containsKey(story.userId)) {
              groupedStories[story.userId] = [];
              userIds.add(story.userId);
            }
            groupedStories[story.userId]!.add(story);
          }

          final myId = ref.read(loggedInUserIdProvider);

          // Find if we have our own stories
          final myStories = groupedStories[myId];
          if (myStories != null) {
            userIds.remove(myId);
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: userIds.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildMyStoryButton(context, ref, myStories);
              }

              final userId = userIds[index - 1];
              final userStories = groupedStories[userId]!;
              
              // Gradient border shows if there is AT LEAST ONE unviewed story by this user
              final hasUnviewed = userStories.any((s) => !s.viewedBy.contains(myId));
              final gradientBorder = hasUnviewed;
              
              // Use the first story's avatar and name
              final representativeStory = userStories.first;
              final hasValidAvatar = representativeStory.userAvatar.isNotEmpty &&
                  (representativeStory.userAvatar.startsWith('http://') || representativeStory.userAvatar.startsWith('https://'));
              final displayName = representativeStory.userName.trim().isNotEmpty
                  ? representativeStory.userName.trim()
                  : 'Athlete';

              return Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: GestureDetector(
                  onTap: () {
                    // Find the first unread story, or default to the first story
                    final startStory = userStories.firstWhere((s) => !s.viewedBy.contains(myId), orElse: () => userStories.first);
                    final initialIndex = userStories.indexOf(startStory);

                    showDialog(
                      context: context,
                      useSafeArea: false,
                      builder: (context) => StoryViewerDialog(
                        stories: userStories,
                        initialIndex: initialIndex,
                        onStoryViewed: (id) {
                          ref.read(feedStoriesProvider.notifier).viewStory(id);
                        },
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Avatar with neon gradient ring for unviewed stories
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: gradientBorder
                              ? const LinearGradient(
                                  colors: [AppTheme.primaryColor, Colors.orangeAccent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          border: !gradientBorder
                              ? Border.all(color: Colors.white24, width: 1.5)
                              : null,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: CircleAvatar(
                            radius: 25,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                            backgroundImage: hasValidAvatar
                                ? CachedNetworkImageProvider(
                                    representativeStory.userAvatar,
                                    maxWidth: 120,
                                    maxHeight: 120,
                                  )
                                : null,
                            child: !hasValidAvatar
                                ? Text(
                                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Username with verification badge
                      SizedBox(
                        width: 62,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: Text(
                                displayName.split(' ').first,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xCCFFFFFF),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (representativeStory.verified) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.verified, size: 10, color: AppTheme.primaryColor),
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
        },
      ),
    );
  }

  Widget _buildMyStoryButton(BuildContext context, WidgetRef ref, List<StoryModel>? myStories) {
    final userAsync = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;
    final avatarUrl = (userProfile != null && userProfile.avatarUrl.trim().isNotEmpty)
        ? userProfile.avatarUrl.trim()
        : (FirebaseAuth.instance.currentUser?.photoURL ?? '');
    final myId = ref.watch(loggedInUserIdProvider);

    final bool hasUnviewed = myStories != null && myStories.any((s) => !s.viewedBy.contains(myId));

    return Padding(
      padding: const EdgeInsets.only(right: 14.0),
      child: GestureDetector(
        onTap: () async {
          if (myStories != null && myStories.isNotEmpty) {
            final startStory = myStories.firstWhere((s) => !s.viewedBy.contains(myId), orElse: () => myStories.first);
            final initialIndex = myStories.indexOf(startStory);

            showDialog(
              context: context,
              useSafeArea: false,
              builder: (context) => StoryViewerDialog(
                stories: myStories,
                initialIndex: initialIndex,
                onStoryViewed: (id) {
                  ref.read(feedStoriesProvider.notifier).viewStory(id);
                },
              ),
            );
          } else {
            await _uploadStoryAction(context, ref);
          }
        },
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnviewed
                        ? const LinearGradient(
                            colors: [AppTheme.primaryColor, Colors.orangeAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    border: (!hasUnviewed && myStories != null) 
                        ? Border.all(color: Colors.white24, width: 1.5)
                        : null,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: CircleAvatar(
                      radius: 25,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      backgroundImage: (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))
                          ? CachedNetworkImageProvider(
                              avatarUrl,
                              maxWidth: 120,
                              maxHeight: 120,
                            )
                          : null,
                      child: !(avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))
                          ? const Icon(Icons.person, color: AppTheme.primaryColor, size: 20)
                          : null,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _uploadStoryAction(context, ref),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your Story',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadStoryAction(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        useSafeArea: false,
        builder: (context) => StoryUploadDialog(imagePath: pickedFile.path),
      );
    }
  }

  Widget _buildCreatePostCard(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final userProfile = userAsync.valueOrNull;
    final avatarUrl = (userProfile != null && userProfile.avatarUrl.trim().isNotEmpty)
        ? userProfile.avatarUrl.trim()
        : (FirebaseAuth.instance.currentUser?.photoURL ?? '');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFF262626), width: 1),
      ),
      color: Colors.black,
      child: InkWell(
        onTap: () {
          context.go('/upload');
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: avatarUrl,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share your latest training, match or achievement.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.add_circle_outline_rounded,
                color: AppTheme.primaryColor.withOpacity(0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesRow(BuildContext context, WidgetRef ref, String selectedCategory) {
    final categoriesList = ['All', 'Training', 'Match', 'Achievement', 'Recovery', 'General'];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: categoriesList.length,
        itemBuilder: (context, index) {
          final category = categoriesList[index];
          final isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                ref.read(selectedCategoryProvider.notifier).state = category;
              },
              backgroundColor: const Color(0xFF141414),
              selectedColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF262626),
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortAndFilterHeader(BuildContext context, WidgetRef ref, String currentSort) {
    final sortOptions = ['Latest', 'Trending'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'FILTER BY CATEGORY',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white38,
              letterSpacing: 1.0,
            ),
          ),
          Row(
            children: sortOptions.map((opt) {
              final isSelected = currentSort == opt;
              return GestureDetector(
                onTap: () {
                  ref.read(feedSortProvider.notifier).state = opt;
                },
                child: Container(
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    opt.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: isSelected ? Colors.black : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsRow(BuildContext context, WidgetRef ref, String selectedSport) {
    ref.watch(sportsHierarchyProvider); // Reactively rebuild if Firestore hierarchy changes
    final categories = ['All', ...SportsService.getCategories()];

    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedSport == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                ref.read(selectedSportProvider.notifier).state = cat;
              },
              backgroundColor: const Color(0xFF141414),
              selectedColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFF262626),
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, WidgetRef ref, PostModel post, ThemeData theme) {
    return PostCard(
      post: post,
      onToggleBookmark: (currentlyBookmarked) =>
          ref.read(feedPostsProvider.notifier).toggleBookmark(post.id, currentlyBookmarked),
      onMediaTap: post.hasVideo ? () {
        final postsState = ref.read(feedPostsProvider);
        final postsList = postsState.value ?? [];
        final reels = postsList.where((p) => p.hasVideo).toList();
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

// Sub-widget: Like Button with Scale-Bounce Transition
class AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback onTap;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    required this.onTap,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border_rounded,
          color: widget.isLiked ? AppTheme.primaryColor : Colors.white60,
          size: 21,
        ),
        onPressed: () {
          _controller.forward(from: 0.0);
          widget.onTap();
        },
      ),
    );
  }
}

// Sub-widget: Bookmark Button with Scale-Bounce Transition
class AnimatedBookmarkButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback onTap;

  const AnimatedBookmarkButton({
    super.key,
    required this.isBookmarked,
    required this.onTap,
  });

  @override
  State<AnimatedBookmarkButton> createState() => _AnimatedBookmarkButtonState();
}

class _AnimatedBookmarkButtonState extends State<AnimatedBookmarkButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: IconButton(
        icon: Icon(
          widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border_rounded,
          color: widget.isBookmarked ? AppTheme.primaryColor : Colors.white60,
          size: 21,
        ),
        onPressed: () {
          _controller.forward(from: 0.0);
          widget.onTap();
        },
      ),
    );
  }
}

// Sub-widget: Media Viewer with Double Tap to Like and heart overlay popping
class PostMediaViewer extends StatefulWidget {
  final String imageUrl;
  final bool isLiked;
  final VoidCallback onDoubleTap;

  const PostMediaViewer({
    super.key,
    required this.imageUrl,
    required this.isLiked,
    required this.onDoubleTap,
  });

  @override
  State<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends State<PostMediaViewer> with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.25).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_heartController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 0.95), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 0.0), weight: 20),
    ]).animate(_heartController);
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _triggerDoubleTap() {
    setState(() {
      _showHeart = true;
    });
    _heartController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _showHeart = false;
        });
      }
    });
    widget.onDoubleTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _triggerDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              widget.imageUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 240,
                  color: Colors.white.withOpacity(0.04),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 240,
                  color: Colors.white.withOpacity(0.04),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 36),
                  ),
                );
              },
            ),
          ),
          if (_showHeart)
            AnimatedBuilder(
              animation: _heartController,
              builder: (context, child) {
                return Opacity(
                  opacity: _heartOpacity.value,
                  child: Transform.scale(
                    scale: _heartScale.value,
                    child: const Icon(
                      Icons.favorite,
                      color: AppTheme.primaryColor,
                      size: 80,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Sub-widget: Fullscreen Story Viewer Dialog
class StoryViewerDialog extends ConsumerStatefulWidget {
  final List<StoryModel> stories;
  final int initialIndex;
  final Function(String storyId) onStoryViewed;

  const StoryViewerDialog({
    super.key,
    required this.stories,
    required this.initialIndex,
    required this.onStoryViewed,
  });

  @override
  ConsumerState<StoryViewerDialog> createState() => _StoryViewerDialogState();
}

class _StoryViewerDialogState extends ConsumerState<StoryViewerDialog> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _progressController;
  late TextEditingController _replyController;
  late FocusNode _replyFocusNode;
  bool? _localLiked;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _replyController = TextEditingController();
    _replyFocusNode = FocusNode();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStory();
      }
    });

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _progressController.stop();
      } else {
        _progressController.forward();
      }
    });

    _startStory();
  }

  void _startStory() {
    setState(() {
      _localLiked = null;
    });
    _progressController.forward(from: 0.0);
    widget.onStoryViewed(widget.stories[_currentIndex].id);
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startStory();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startStory();
    } else {
      _progressController.forward(from: 0.0);
    }
  }

  void _toggleLike() async {
    final story = widget.stories[_currentIndex];
    final myId = ref.read(loggedInUserIdProvider);
    final currentlyLiked = _localLiked ?? story.likes.contains(myId);

    setState(() {
      _localLiked = !currentlyLiked;
    });

    try {
      await ref.read(storyRepositoryProvider).toggleStoryLike(story.id, myId);
    } catch (_) {}
  }

  void _sendStoryReply(String text) async {
    if (text.trim().isEmpty) return;

    final story = widget.stories[_currentIndex];
    _replyController.clear();
    _replyFocusNode.unfocus();

    try {
      await ref.read(chatProvider(story.userId).notifier).sendMessage(
        text,
        storyId: story.id,
        storyMediaUrl: story.mediaUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reply sent to ${story.userName}!'),
            backgroundColor: const Color(0xFF121212),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e, fallback: 'Failed to send reply. Please try again.'))),
        );
      }
    }

    _progressController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final myId = ref.watch(loggedInUserIdProvider);
    final hasLiked = _localLiked ?? story.likes.contains(myId);

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: GestureDetector(
        onLongPressStart: (_) {
          // Pause the story while user holds finger down (Instagram behavior)
          _progressController.stop();
          setState(() {});
        },
        onLongPressEnd: (_) {
          // Resume the story when user lifts finger
          _progressController.forward();
          setState(() {});
        },
        onTapDown: (details) {
          final width = MediaQuery.of(context).size.width;
          final height = MediaQuery.of(context).size.height;
          
          // Ignore taps in the bottom interactive section
          if (details.globalPosition.dy > height - 100) return;

          if (details.globalPosition.dx < width * 0.3) {
            _prevStory();
          } else {
            _nextStory();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fullscreen story image
            Image.network(
              story.mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, color: Colors.white24, size: 48),
                );
              },
            ),
            // Dim gradient scrim overlay for text readability
            Positioned.fill(
              child: Column(
                children: [
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 160,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Floating story overlays: Progress indicators, user metadata, and close action
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Segmented horizontal progress bars
                    Builder(
                      builder: (context) {
                        final currentUserId = story.userId;
                        final currentUserStories = widget.stories.where((s) => s.userId == currentUserId).toList();
                        final localIndex = currentUserStories.indexOf(story);
                        
                        return Row(
                          children: List.generate(
                            currentUserStories.length,
                            (idx) {
                              double value = 0.0;
                              if (idx < localIndex) {
                                value = 1.0;
                              } else if (idx == localIndex) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, child) {
                                        return LinearProgressIndicator(
                                          value: _progressController.value,
                                          backgroundColor: Colors.white24,
                                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                          minHeight: 2.5,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: LinearProgressIndicator(
                                    value: value,
                                    backgroundColor: Colors.white24,
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                    minHeight: 2.5,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                    ),
                    const SizedBox(height: 14),
                    // Athlete profile headers
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/profile/${story.userId}');
                          },
                          child: CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              story.userAvatar,
                              maxWidth: 120,
                              maxHeight: 120,
                            ),
                            radius: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            context.push('/profile/${story.userId}');
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    story.userName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                                  ),
                                  if (story.verified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified, size: 14, color: AppTheme.primaryColor),
                                  ],
                                ],
                              ),
                              const Text('Active Highlights', style: TextStyle(color: Colors.white54, fontSize: 10)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (story.userId == myId)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
                            onPressed: () async {
                              _progressController.stop();
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF121212),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Color(0xFF262626)),
                                  ),
                                  title: const Text('Delete Story', style: TextStyle(color: Colors.white)),
                                  content: const Text('Are you sure you want to delete this story?', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(feedStoriesProvider.notifier).deleteStory(story.id);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } else {
                                _progressController.forward();
                              }
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 24),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom interactive bar (Send message, toggle heart like, open Direct message chat)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 16.0 : (MediaQuery.of(context).padding.bottom + 16.0),
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (story.caption != null && story.caption!.isNotEmpty) ...[
                    Text(
                      story.caption!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(23),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
                      ),
                      child: TextField(
                        controller: _replyController,
                        focusNode: _replyFocusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Send message...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _sendStoryReply,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Icon(
                      hasLiked ? Icons.favorite : Icons.favorite_border,
                      color: hasLiked ? const Color(0xFFFF2F7A) : Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/chat/room?receiverId=${story.userId}');
                    },
                    child: const Icon(
                      Icons.send_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}

// Sub-widget: Comments Sheet
class _VisualComment {
  final CommentModel comment;
  final int indentLevel;
  const _VisualComment({required this.comment, required this.indentLevel});
}

// Sub-widget: Comments Sheet
class CommentBottomSheet extends ConsumerStatefulWidget {
  final PostModel post;
  final Function(int newCount) onCommentAdded;

  const CommentBottomSheet({
    super.key,
    required this.post,
    required this.onCommentAdded,
  });

  @override
  ConsumerState<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends ConsumerState<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  CommentModel? _replyingToComment;
  CommentModel? _editingComment;

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  void _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.valueOrNull;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final userId = (user?.id != null && user!.id.isNotEmpty)
        ? user.id
        : (firebaseUser?.uid ?? '');
    final username = (user?.name != null && user!.name.isNotEmpty)
        ? user.name
        : (firebaseUser?.displayName?.isNotEmpty == true
            ? firebaseUser!.displayName!
            : 'Athlete');
    final profileImage = (user?.avatarUrl != null && user!.avatarUrl.isNotEmpty)
        ? user.avatarUrl
        : (firebaseUser?.photoURL ?? '');
    final verified = user?.verified ?? false;

    _commentController.clear();
    _commentFocusNode.unfocus();

    if (_editingComment != null) {
      final editingId = _editingComment!.commentId;
      setState(() {
        _editingComment = null;
      });
      try {
        await ref.read(commentRepositoryProvider).editComment(widget.post.id, editingId, text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(UserFacingError.message(e, fallback: 'Unable to edit comment. Please try again.'))),
          );
        }
      }
      return;
    }

    final allProfiles = ref.read(profileListProvider).valueOrNull ?? [];
    final mentionsList = MentionService.parseAndMapMentions(text, allProfiles);

    final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final parentId = _replyingToComment?.commentId;
    final replyTargetUserId = _replyingToComment?.userId;

    final comment = CommentModel(
      commentId: commentId,
      postId: widget.post.id,
      userId: userId,
      username: username,
      profileImage: profileImage,
      verified: verified,
      text: text,
      createdAt: DateTime.now(),
      parentId: parentId,
      mentions: mentionsList,
    );

    setState(() {
      _replyingToComment = null;
    });

    final isOnline = ref.read(networkServiceProvider).isOnline;
    if (!isOnline) {
      // Optimistically add to cached comments so it shows up immediately
      final cachedList = CacheManager().loadComments(widget.post.id);
      cachedList.add(comment.toMap());
      CacheManager().saveComments(widget.post.id, cachedList);

      // Invalidate stream so it updates from cache
      ref.invalidate(commentsStreamProvider(widget.post.id));

      ref.read(offlineSyncProvider.notifier).queueAction(
        actionType: 'comment',
        targetId: widget.post.id,
        data: {'comment': comment.toMap()},
      );

      // Trigger callback with fake updated count
      widget.onCommentAdded(widget.post.commentsCount + 1);
      return;
    }

    try {
      await ref.read(commentRepositoryProvider).addComment(comment);

      // Notify the relevant recipients (owner / parent-comment author).
      final actor = NotificationActor(
          id: userId, name: username, avatar: profileImage);
      final media =
          widget.post.media.isNotEmpty ? widget.post.media.first : null;
      final thumb = media?.thumbnailUrl ?? media?.mediaUrl;
      final preview = text.length > 60 ? '${text.substring(0, 57)}...' : text;

      if (parentId != null && replyTargetUserId != null) {
        // Reply → notify the author of the parent comment.
        unawaited(NotificationService.instance.commentReply(
          receiverId: replyTargetUserId,
          actor: actor,
          contentId: widget.post.id,
          commentId: commentId,
          preview: preview,
        ));
        // Also notify the post owner if they are a different person.
        if (widget.post.userId != replyTargetUserId) {
          unawaited(NotificationService.instance.comment(
            receiverId: widget.post.userId,
            actor: actor,
            contentId: widget.post.id,
            commentId: commentId,
            isReel: widget.post.hasVideo,
            preview: preview,
            thumbnailUrl: thumb,
          ));
        }
      } else {
        // Top-level comment → notify the post owner.
        unawaited(NotificationService.instance.comment(
          receiverId: widget.post.userId,
          actor: actor,
          contentId: widget.post.id,
          commentId: commentId,
          isReel: widget.post.hasVideo,
          preview: preview,
          thumbnailUrl: thumb,
        ));
      }

      // Trigger notifications for mentioned users
      await MentionService.sendMentionNotifications(
        senderId: userId,
        senderName: username,
        senderAvatar: profileImage,
        textContent: text,
        targetType: 'comment',
        targetId: widget.post.id,
        mentions: mentionsList,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e, fallback: 'Unable to add comment. Please try again.'))),
        );
      }
    }
  }

  void _deleteComment(CommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121212),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF262626)),
        ),
        title: const Text('Delete Comment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete your comment?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(commentRepositoryProvider).deleteComment(widget.post.id, comment.commentId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(UserFacingError.message(e, fallback: 'Unable to delete comment. Please try again.'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsStreamProvider(widget.post.id));
    final userAsync = ref.watch(currentUserProvider);
    final currentUserAvatar = (userAsync.valueOrNull?.avatarUrl != null && userAsync.valueOrNull!.avatarUrl.isNotEmpty)
        ? userAsync.valueOrNull!.avatarUrl
        : (FirebaseAuth.instance.currentUser?.photoURL ?? '');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFF262626), width: 1),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          commentsAsync.when(
            loading: () => const Text('Comments (...)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            error: (_, __) => const Text('Comments (Error)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            data: (comments) => Text(
              'Comments (${comments.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const Divider(color: Colors.white12, height: 24),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: commentsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    UserFacingError.message(err, fallback: 'Unable to load comments right now.'),
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (comments) {
                if (comments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No comments yet. Be the first to reply!',
                        style: TextStyle(color: Colors.white38, fontSize: 12.5),
                      ),
                    ),
                  );
                }

                // Tree flattening algorithm
                final List<CommentModel> parentComments = [];
                final Map<String, List<CommentModel>> repliesMap = {};

                for (final comment in comments) {
                  if (comment.parentId == null || comment.parentId!.isEmpty) {
                    parentComments.add(comment);
                  } else {
                    repliesMap.putIfAbsent(comment.parentId!, () => []).add(comment);
                  }
                }

                final List<_VisualComment> visualList = [];
                for (final parent in parentComments) {
                  visualList.add(_VisualComment(comment: parent, indentLevel: 0));
                  final replies = repliesMap[parent.commentId];
                  if (replies != null) {
                    replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    for (final reply in replies) {
                      visualList.add(_VisualComment(comment: reply, indentLevel: 1));
                      final subReplies = repliesMap[reply.commentId];
                      if (subReplies != null) {
                        subReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                        for (final subReply in subReplies) {
                          visualList.add(_VisualComment(comment: subReply, indentLevel: 2));
                        }
                      }
                    }
                  }
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: visualList.length,
                  itemBuilder: (context, index) {
                    final visualItem = visualList[index];
                    final comment = visualItem.comment;
                    final indent = visualItem.indentLevel;

                    final duration = DateTime.now().difference(comment.createdAt);
                    String timeAgo = 'Just now';
                    if (duration.inDays > 0) {
                      timeAgo = '${duration.inDays}d ago';
                    } else if (duration.inHours > 0) {
                      timeAgo = '${duration.inHours}h ago';
                    } else if (duration.inMinutes > 0) {
                      timeAgo = '${duration.inMinutes}m ago';
                    }

                    final currentUserId = ref.watch(loggedInUserIdProvider);
                    final isLiked = comment.likedBy.contains(currentUserId);
                    final isOwn = comment.userId == currentUserId;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: 12.0,
                        left: indent * 28.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (indent > 0) ...[
                            Container(
                              width: 2,
                              height: 36,
                              margin: const EdgeInsets.only(right: 8),
                              color: Colors.white10,
                            ),
                          ],
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/${comment.userId}');
                            },
                            child: AppAvatar(
                              imageUrl: comment.profileImage,
                              radius: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push('/profile/${comment.userId}');
                                  },
                                  child: Row(
                                    children: [
                                      Text(
                                        comment.username,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white70),
                                      ),
                                      if (comment.verified) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified, size: 11, color: AppTheme.primaryColor),
                                      ],
                                      const SizedBox(width: 8),
                                      Text(
                                        timeAgo,
                                        style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                MentionText(
                                  text: comment.text,
                                  mentions: comment.mentions,
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF), height: 1.3),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _replyingToComment = comment;
                                        });
                                        _commentFocusNode.requestFocus();
                                      },
                                      child: const Text(
                                        'Reply',
                                        style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (isOwn) ...[
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _editingComment = comment;
                                            _commentController.text = comment.text;
                                          });
                                          _commentFocusNode.requestFocus();
                                        },
                                        child: const Text(
                                          'Edit',
                                          style: TextStyle(color: Colors.white54, fontSize: 10),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: () => _deleteComment(comment),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.redAccent, fontSize: 10),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.white38,
                              size: 14,
                            ),
                            onPressed: () {
                              ref.read(commentRepositoryProvider).toggleLikeComment(
                                    comment.postId,
                                    comment.commentId,
                                    currentUserId,
                                  );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          if (_replyingToComment != null || _editingComment != null)
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    _editingComment != null ? Icons.edit : Icons.reply,
                    color: AppTheme.primaryColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _editingComment != null
                          ? 'Editing your comment'
                          : 'Replying to @${_replyingToComment!.username}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingToComment = null;
                        _editingComment = null;
                        _commentController.clear();
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white38, size: 14),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                AppAvatar(
                  imageUrl: currentUserAvatar,
                  radius: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MentionAutocompleteOverlay(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    child: TextField(
                      controller: _commentController,
                      focusNode: _commentFocusNode,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.white24, fontSize: 12.5),
                      ),
                      style: const TextStyle(fontSize: 12.5),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor, size: 20),
                  onPressed: _submitComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Sub-widget: Share Sheet
class ShareBottomSheet extends ConsumerWidget {
  final PostModel post;

  const ShareBottomSheet({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = [
      {'name': 'Direct Message', 'icon': Icons.chat_bubble_outline_rounded},
      {'name': 'Share as Clip', 'icon': Icons.play_circle_outline_rounded},
      {'name': 'WhatsApp', 'icon': Icons.chat_bubble_rounded},
      {'name': 'Instagram Stories', 'icon': Icons.camera_alt_outlined},
      {'name': 'Twitter / X', 'icon': Icons.close},
      {'name': 'Copy Link', 'icon': Icons.copy_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: const Color(0xFF262626), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share Highlight',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const Divider(color: Colors.white12, height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.15,
            ),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              final channel = channels[index];
              return InkWell(
                onTap: () {
                  if (channel['name'] == 'Direct Message') {
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
                    return;
                  }

                  Navigator.pop(context);
                  
                  if (channel['name'] == 'Copy Link') {
                    final link = 'https://atheleos.com/posts/${post.id}';
                    Clipboard.setData(ClipboardData(text: link));
                  }
                  
                  // Increment Firestore share count
                  ref.read(feedPostsProvider.notifier).incrementShare(post.id);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(channel['name'] == 'Copy Link'
                          ? 'Link copied to clipboard!'
                          : 'Post shared to ${channel['name']}!'),
                      backgroundColor: AppTheme.primaryColor,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.04),
                      radius: 20,
                      child: Icon(channel['icon'] as IconData, color: Colors.white, size: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      channel['name'] as String,
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class StoryUploadDialog extends ConsumerStatefulWidget {
  final String imagePath;
  const StoryUploadDialog({super.key, required this.imagePath});

  @override
  ConsumerState<StoryUploadDialog> createState() => _StoryUploadDialogState();
}

class _StoryUploadDialogState extends ConsumerState<StoryUploadDialog> {
  final _captionController = TextEditingController();
  String _visibility = 'public';
  bool _isUploading = false;

  Future<void> _upload() async {
    setState(() => _isUploading = true);
    try {
      await ref.read(feedStoriesProvider.notifier).uploadStory(
        widget.imagePath,
        caption: _captionController.text.trim(),
        visibility: _visibility,
      );
      if (mounted) {
        Navigator.pop(context); // Close the dialog on success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFacingError.message(e, fallback: 'Failed to upload story. Please try again.'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(widget.imagePath), fit: BoxFit.cover),
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_isUploading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 16,
                right: 16,
                top: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _captionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Add a caption...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white12,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _visibility,
                          dropdownColor: const Color(0xFF141414),
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'public', child: Text('Public', style: TextStyle(color: Colors.white))),
                            DropdownMenuItem(value: 'followers', child: Text('Followers', style: TextStyle(color: Colors.white))),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _visibility = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isUploading ? null : _upload,
                      child: const Text('Share Story', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedScreenShimmerLoading extends StatefulWidget {
  const _FeedScreenShimmerLoading({super.key});

  @override
  State<_FeedScreenShimmerLoading> createState() => _FeedScreenShimmerLoadingState();
}

class _FeedScreenShimmerLoadingState extends State<_FeedScreenShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.75).animate(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: List.generate(2, (i) => _buildShimmerCard()),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF262626), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 80,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 200,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
