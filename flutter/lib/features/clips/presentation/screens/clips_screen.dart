import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/post_media_widget.dart';
import '../../../../core/services/sports_service.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../../core/services/mention_service.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../feed/domain/models/comment_model.dart';
import '../controllers/clips_controller.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../feed/presentation/controllers/post_delete_controller.dart';
import 'dart:io';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../feed/presentation/controllers/like_controller.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';

String formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  }
  return number.toString();
}

class ClipsScreen extends ConsumerStatefulWidget {
  const ClipsScreen({super.key});

  @override
  ConsumerState<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends ConsumerState<ClipsScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _incrementActiveClipView();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Clear the global active/preload URLs so the last-active video
    // controller is released as soon as the user leaves Clips. Safe to
    // read `ref` during dispose in ConsumerState.
    try {
      ref.read(activeVideoUrlProvider.notifier).state = null;
      ref.read(preloadedVideoUrlProvider.notifier).state = null;
    } catch (_) {}
    super.dispose();
  }

  void _incrementActiveClipView() {
    final clipsAsync = ref.read(clipsProvider);
    clipsAsync.whenData((clips) {
      if (clips.isNotEmpty && _currentIndex < clips.length) {
        ref.read(clipsProvider.notifier).incrementView(clips[_currentIndex].id);
        _preloadClipsForIndex(_currentIndex, clips);
      }
    });
  }

  void _preloadClipsForIndex(int currentIndex, List<PostModel> clips) {
    final network = ref.read(networkServiceProvider);
    if (network.speed == ConnectionSpeed.none) return; // offline

    // Preload only the next clip (N+1) to avoid memory pressure.
    // CacheManager.preloadVideo is de-duplicated and concurrency-limited,
    // so repeated calls with the same URL are safe/cheap.
    final nextIndex = currentIndex + 1;
    if (nextIndex < clips.length && clips[nextIndex].media.isNotEmpty) {
      final videoUrl = clips[nextIndex].media.first.mediaUrl;
      CacheManager().preloadVideo(videoUrl);
    }
  }

  Widget _buildClipsSportsRow(BuildContext context, WidgetRef ref) {
    final selectedSport = ref.watch(selectedClipSportProvider);
    final sports = ['All', ...SportsService.supportedSports];
    return Container(
      height: 40,
      color: Colors.transparent,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sports.length,
        itemBuilder: (context, index) {
          final sport = sports[index];
          final isSelected = selectedSport == sport;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              showCheckmark: false,
              label: Text(sport),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(selectedClipSportProvider.notifier).state = sport;
                }
              },
              backgroundColor: Colors.black45,
              selectedColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryColor : Colors.white24,
                ),
              ),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clipsAsync = ref.watch(clipsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: clipsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text('Error loading clips: $err', style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () => ref.invalidate(clipsProvider),
                child: const Text('RETRY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
        data: (clips) {
          if (clips.isEmpty) {
            return Stack(
              children: [
                const Center(
                  child: Text('No clips found.', style: TextStyle(color: Colors.white38)),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 0,
                  right: 0,
                  child: _buildClipsSportsRow(context, ref),
                ),
              ],
            );
          }
          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: clips.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  ref.read(clipsProvider.notifier).incrementView(clips[index].id);
                  _preloadClipsForIndex(index, clips);
                },
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  return ClipPlayerItem(
                    // Key by clip id so PageView never reuses a `_ClipPlayerItemState`
                    // for a different clip — which would leave a stale
                    // VideoPlayerController pointing at another video.
                    key: ValueKey('clip_${clip.id}'),
                    clip: clip,
                    isActive: index == _currentIndex,
                    onShare: () {
                      ref.read(clipsProvider.notifier).incrementShare(clip.id);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (context) => ShareContentBottomSheet(
                          reelId: clip.id,
                          shareType: 'reel',
                        ),
                      );
                    },
                  );
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: _buildClipsSportsRow(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ClipPlayerItem extends ConsumerStatefulWidget {
  final PostModel clip;
  final bool isActive;

  const ClipPlayerItem({
    super.key,
    required this.clip,
    required this.isActive,
    this.onBookmark,
    this.onShare,
    this.onDelete,
  });

  final VoidCallback? onBookmark;
  final VoidCallback? onShare;

  /// Called after the clip has been successfully deleted by its owner.
  final VoidCallback? onDelete;


  @override
  ConsumerState<ClipPlayerItem> createState() => _ClipPlayerItemState();
}

class _ClipPlayerItemState extends ConsumerState<ClipPlayerItem> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isInitializing = false;
  bool _showHeartAnimation = false;
  bool _showPauseOverlay = false;

  /// Bumped every time we start a new initialize or dispose, so the async
  /// tail of a superseded init cannot mutate a fresh controller or write to
  /// a controller that has already been disposed (which crashes the native
  /// texture layer on iOS/Android).
  int _initGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initializePlayer();
    }
  }

  @override
  void didUpdateWidget(covariant ClipPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // We rely on ValueKey('clip_${clip.id}') at the call site to force a
    // fresh state when the clip id changes, so we only have to worry about
    // isActive transitions here.
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_controller == null && !_isInitializing) {
          _initializePlayer();
        } else if (_controller != null && _isInitialized) {
          _controller!.play();
        }
      } else {
        _disposePlayer();
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || _controller == null) return;
    final nowPlaying = _controller!.value.isPlaying;
    if (nowPlaying != _isPlaying) {
      setState(() {
        _isPlaying = nowPlaying;
      });
    }
  }

  /// Fully release the native decoder + texture backing this clip.
  ///
  /// Safe to call multiple times; bumps [_initGeneration] so any in-flight
  /// [_initializePlayer] awaiting `controller.initialize()` will abort at
  /// its next check and dispose the intermediate controller instead of
  /// wiring it up.
  void _disposePlayer() {
    _initGeneration++;
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerUpdate);
      try {
        controller.pause();
      } catch (_) {}
      controller.dispose();
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
        _isPlaying = false;
      });
    } else {
      _isInitialized = false;
      _isPlaying = false;
    }
  }

  Future<void> _initializePlayer() async {
    if (widget.clip.media.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    if (_isInitializing) return;
    _isInitializing = true;
    final generation = ++_initGeneration;

    if (mounted) {
      setState(() {
        _hasError = false;
        _isInitialized = false;
      });
    }

    VideoPlayerController? localController;
    try {
      final mediaUrl = widget.clip.media.first.mediaUrl;
      final cachedPath = await CacheManager().getCachedVideoPath(mediaUrl);

      // Bail early if the widget was torn down or a newer generation started.
      if (!mounted || generation != _initGeneration) return;

      if (cachedPath != null) {
        localController = VideoPlayerController.file(File(cachedPath));
      } else {
        localController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
        // Cache-in-background is de-duplicated inside CacheManager, so
        // repeat re-inits do not spawn parallel HTTP downloads.
        CacheManager().preloadVideo(mediaUrl);
      }

      await localController.initialize();

      if (!mounted || generation != _initGeneration) {
        await localController.dispose();
        return;
      }

      await localController.setLooping(true);
      final globalMuted = ref.read(videosMutedProvider);
      await localController.setVolume(globalMuted ? 0.0 : 1.0);

      if (!mounted || generation != _initGeneration) {
        await localController.dispose();
        return;
      }

      _controller = localController;
      localController.addListener(_onControllerUpdate);

      if (widget.isActive) {
        await localController.play();
      }

      if (!mounted || generation != _initGeneration) return;

      setState(() {
        _isInitialized = true;
        _isPlaying = widget.isActive;
      });
    } catch (e) {
      debugPrint('Error initializing clip video: $e');
      try {
        if (localController != null && localController != _controller) {
          await localController.dispose();
        }
      } catch (_) {}
      if (mounted && generation == _initGeneration) {
        setState(() => _hasError = true);
      }
    } finally {
      if (generation == _initGeneration) {
        _isInitializing = false;
      }
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _handleDoubleTap() {
    setState(() {
      _showHeartAnimation = true;
    });

    ref.read(sharedLikeStateProvider.notifier).toggleLike(widget.clip, forceLike: true);

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
      }
    });
  }

  void _handleSingleTap() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() {
        _showPauseOverlay = true;
      });
    } else {
      _controller!.play();
      setState(() {
        _showPauseOverlay = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final likeState = ref.watch(postLikeProvider(widget.clip));

    // Reactively adjust volume ONLY when the mute state actually flips —
    // never inside build itself (that used to fire on every rebuild and
    // caused a native round-trip per frame).
    ref.listen<bool>(videosMutedProvider, (prev, next) {
      final controller = _controller;
      if (controller != null && _isInitialized) {
        controller.setVolume(next ? 0.0 : 1.0);
      }
    });
    final isGlobalMuted = ref.watch(videosMutedProvider);

    final loggedInId = ref.watch(loggedInUserIdProvider);
    final isOwner = loggedInId.isNotEmpty && loggedInId == widget.clip.userId;

    final thumbnailUrl = widget.clip.media.isNotEmpty ? (widget.clip.media.first.thumbnailUrl ?? widget.clip.media.first.mediaUrl) : '';

    return VisibilityDetector(
      key: Key('clip_player_${widget.clip.id}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        if (info.visibleFraction == 0) {
          // Fully off-screen (e.g. user switched tab, page scrolled away):
          // fully release the controller so the native decoder + texture
          // are returned to the OS. Re-inits are cheap because the file is
          // cached on disk.
          _disposePlayer();
        } else if (widget.isActive && info.visibleFraction > 0.5) {
          // Back on screen and we ARE the active page → play (re-init if
          // we were torn down while off-screen).
          if (_controller == null && !_isInitializing && !_hasError) {
            _initializePlayer();
          } else if (_controller != null &&
              _isInitialized &&
              !_controller!.value.isPlaying) {
            _controller!.play();
          }
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        // 1. VIDEO VIEWPORT
        GestureDetector(
          onTap: _handleSingleTap,
          onDoubleTap: _handleDoubleTap,
          child: Container(
            color: Colors.black,
            child: _hasError
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                        const SizedBox(height: 8),
                        const Text('Could not load video', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _initializePlayer,
                          icon: const Icon(Icons.refresh, color: AppTheme.primaryColor, size: 16),
                          label: const Text('Retry', style: TextStyle(color: AppTheme.primaryColor, fontSize: 12)),
                        ),
                      ],
                    ),
                  )
                : _isInitialized && _controller != null
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (thumbnailUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.broken_image, color: Colors.white24, size: 40),
                          ),
                        ),
                      const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
          ),
        ),

        // 2. GRADIENT OVERLAYS
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
              ),
            ),
          ),
        ),

        // 3. TITLE & AUTHOR DETAILS LEFT COLUMN
        Positioned(
          bottom: 32,
          left: 16,
          right: 90,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  context.go('/profile/${widget.clip.userId}');
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage: NetworkImage(widget.clip.userAvatar),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.clip.userName,
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              if (widget.clip.verified) ...[
                                const SizedBox(width: 4),
                                  const Icon(Icons.verified, size: 14, color: AppTheme.primaryColor),
                              ],
                            ],
                          ),
                          Text(
                            'Click to view profile',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.clip.sport.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              MentionText(
                text: widget.clip.content,
                mentions: widget.clip.mentions,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    '${formatNumber(widget.clip.views)} views',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 4. FLOATING RIGHT NAVIGATION (INTERACTIONS)
        Positioned(
          bottom: 32,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like Button
              _buildInteractionButton(
                icon: likeState.isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: likeState.isLiked ? AppTheme.primaryColor : Colors.white,
                label: '${likeState.likesCount}',
                onTap: () {
                  ref.read(sharedLikeStateProvider.notifier).toggleLike(widget.clip);
                },
              ),
              const SizedBox(height: 18),

              // Comment Button
              _buildInteractionButton(
                icon: Icons.chat_bubble_outline_rounded,
                iconColor: Colors.white,
                label: '${widget.clip.commentsCount}',
                onTap: () {
                  _showClipComments(context);
                },
              ),
              const SizedBox(height: 18),

              // Bookmark Save Button
              _buildInteractionButton(
                icon: widget.clip.hasBookmarked ? Icons.bookmark : Icons.bookmark_border,
                iconColor: widget.clip.hasBookmarked ? AppTheme.primaryColor : Colors.white,
                label: 'Save',
                onTap: () {
                  if (widget.onBookmark != null) {
                    widget.onBookmark!();
                  } else {
                    ref.read(clipsProvider.notifier).toggleBookmark(widget.clip.id, widget.clip.hasBookmarked);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.clip.hasBookmarked ? 'Removed from saved clips' : 'Saved clip successfully!'),
                      backgroundColor: AppTheme.primaryColor,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // Share Button
              _buildInteractionButton(
                icon: Icons.share_rounded,
                iconColor: Colors.white,
                label: '${widget.clip.shares}',
                onTap: () {
                  ref.read(clipsProvider.notifier).incrementShare(widget.clip.id);
                  if (widget.onShare != null) {
                    widget.onShare!();
                  } else {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ShareContentBottomSheet(
                        reelId: widget.clip.id,
                        shareType: 'reel',
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 18),

              // Global Mute Toggle Button
              GestureDetector(
                onTap: () {
                  ref.read(videosMutedProvider.notifier).state = !isGlobalMuted;
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.black54,
                  child: Icon(
                    isGlobalMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),

              // Owner-only options menu (Edit / Delete)
              if (isOwner) ...[
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => _showOwnerMenu(context),
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.more_vert, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 5. DOUBLE-TAP HEART ANIMATION OVERLAY
        if (_showHeartAnimation)
          const Align(
            alignment: Alignment.center,
            child: InteractiveHeartOverlay(),
          ),

        // 6. SINGLE-TAP PLAY/PAUSE INDICATOR OVERLAY
        if (_showPauseOverlay && !_isPlaying)
          const IgnorePointer(
            child: Align(
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, size: 40, color: Colors.white),
              ),
            ),
          ),
      ],
    ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.black54,
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showClipComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipCommentsBottomSheet(
        clipId: widget.clip.id,
        clipOwnerId: widget.clip.userId,
        thumbnailUrl: widget.clip.media.isNotEmpty
            ? (widget.clip.media.first.thumbnailUrl ??
                widget.clip.media.first.mediaUrl)
            : null,
      ),
    );
  }

  void _showOwnerMenu(BuildContext context) {
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
                    content: Text('Editing reels is coming soon.'),
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
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete reel?',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will permanently remove this reel and its media. This action cannot be undone.',
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
      _controller?.pause();
      await ref.read(postDeleteControllerProvider).deletePost(widget.clip);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reel deleted'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 1),
          ),
        );
      }
      widget.onDelete?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete reel. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _VisualClipComment {
  final CommentModel comment;
  final int indentLevel;
  const _VisualClipComment({required this.comment, required this.indentLevel});
}

// ---------------------- CLIPS COMMENT BOTTOM SHEET ----------------------
class ClipCommentsBottomSheet extends ConsumerStatefulWidget {
  final String clipId;
  final String? clipOwnerId;
  final String? thumbnailUrl;

  const ClipCommentsBottomSheet({
    super.key,
    required this.clipId,
    this.clipOwnerId,
    this.thumbnailUrl,
  });

  @override
  ConsumerState<ClipCommentsBottomSheet> createState() => _ClipCommentsBottomSheetState();
}

class _ClipCommentsBottomSheetState extends ConsumerState<ClipCommentsBottomSheet> {
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

    final userId = user?.id ?? 'user_1';
    final username = user?.name ?? 'Jordan Vance';
    final avatar = user?.avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=150';
    final verified = user?.verified ?? true;

    _commentController.clear();
    _commentFocusNode.unfocus();

    if (_editingComment != null) {
      final editingId = _editingComment!.commentId;
      setState(() {
        _editingComment = null;
      });
      try {
        // Comments are nested under posts collection for clips too
        await ref.read(commentRepositoryProvider).editComment(widget.clipId, editingId, text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing comment: $e')),
          );
        }
      }
      return;
    }

    final allProfiles = ref.read(profileListProvider).valueOrNull ?? [];
    final mentionsList = MentionService.parseAndMapMentions(text, allProfiles);

    final commentId = 'comment_clip_${DateTime.now().millisecondsSinceEpoch}_$userId';
    final parentId = _replyingToComment?.commentId;
    final replyTargetUserId = _replyingToComment?.userId;

    final comment = CommentModel(
      commentId: commentId,
      postId: widget.clipId,
      userId: userId,
      username: username,
      profileImage: avatar,
      verified: verified,
      text: text,
      createdAt: DateTime.now(),
      parentId: parentId,
      mentions: mentionsList,
    );

    setState(() {
      _replyingToComment = null;
    });

    try {
      await ref.read(commentRepositoryProvider).addComment(comment);

      // Notify the reel owner / parent-comment author.
      final actor =
          NotificationActor(id: userId, name: username, avatar: avatar);
      final preview = text.length > 60 ? '${text.substring(0, 57)}...' : text;
      final ownerId = widget.clipOwnerId;

      if (parentId != null && replyTargetUserId != null) {
        unawaited(NotificationService.instance.commentReply(
          receiverId: replyTargetUserId,
          actor: actor,
          contentId: widget.clipId,
          commentId: commentId,
          preview: preview,
        ));
        if (ownerId != null && ownerId != replyTargetUserId) {
          unawaited(NotificationService.instance.comment(
            receiverId: ownerId,
            actor: actor,
            contentId: widget.clipId,
            commentId: commentId,
            isReel: true,
            preview: preview,
            thumbnailUrl: widget.thumbnailUrl,
          ));
        }
      } else if (ownerId != null) {
        unawaited(NotificationService.instance.comment(
          receiverId: ownerId,
          actor: actor,
          contentId: widget.clipId,
          commentId: commentId,
          isReel: true,
          preview: preview,
          thumbnailUrl: widget.thumbnailUrl,
        ));
      }

      // Trigger notifications for mentioned users
      await MentionService.sendMentionNotifications(
        senderId: userId,
        senderName: username,
        senderAvatar: avatar,
        textContent: text,
        targetType: 'comment',
        targetId: widget.clipId,
        mentions: mentionsList,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  void _deleteComment(CommentModel comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
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
        await ref.read(commentRepositoryProvider).deleteComment(widget.clipId, comment.commentId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting comment: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsStream = ref.watch(commentsStreamProvider(widget.clipId));
    final userAsync = ref.watch(currentUserProvider);
    final currentUserAvatar = userAsync.valueOrNull?.avatarUrl ?? 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=150';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0B1329),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Clip Responses',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          const Divider(color: Colors.white10, height: 24),
          
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 350),
              child: commentsStream.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                data: (comments) {
                  if (comments.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Text(
                          'No reactions yet. Spark the discussion!',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
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

                  final List<_VisualClipComment> visualList = [];
                  for (final parent in parentComments) {
                    visualList.add(_VisualClipComment(comment: parent, indentLevel: 0));
                    final replies = repliesMap[parent.commentId];
                    if (replies != null) {
                      replies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                      for (final reply in replies) {
                        visualList.add(_VisualClipComment(comment: reply, indentLevel: 1));
                        final subReplies = repliesMap[reply.commentId];
                        if (subReplies != null) {
                          subReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                          for (final subReply in subReplies) {
                            visualList.add(_VisualClipComment(comment: subReply, indentLevel: 2));
                          }
                        }
                      }
                    }
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: visualList.length,
                    itemBuilder: (context, index) {
                      final item = visualList[index];
                      final comment = item.comment;
                      final indent = item.indentLevel;

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
                          left: indent * 24.0,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (indent > 0) ...[
                              Container(
                                width: 2,
                                height: 32,
                                margin: const EdgeInsets.only(right: 6),
                                color: Colors.white10,
                              ),
                            ],
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                context.go('/profile/${comment.userId}');
                              },
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: NetworkImage(comment.profileImage),
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
                                      context.go('/profile/${comment.userId}');
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          comment.username,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        if (comment.verified) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 12, color: AppTheme.primaryColor),
                                        ],
                                        const SizedBox(width: 8),
                                        Text(
                                          timeAgo,
                                          style: const TextStyle(color: Colors.white38, fontSize: 9.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  MentionText(
                                    text: comment.text,
                                    mentions: comment.mentions,
                                    style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, height: 1.3),
                                  ),
                                  const SizedBox(height: 4),
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
                                          style: TextStyle(color: AppTheme.primaryColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (isOwn) ...[
                                        const SizedBox(width: 14),
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
                                            style: TextStyle(color: Colors.white54, fontSize: 9.5),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        GestureDetector(
                                          onTap: () => _deleteComment(comment),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.redAccent, fontSize: 9.5),
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
                                size: 12,
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
          ),

          const Divider(color: Colors.white10, height: 24),
          if (_replyingToComment != null || _editingComment != null)
            Container(
              color: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
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

          Row(
            children: [
              Expanded(
                child: MentionAutocompleteOverlay(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Share your response...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                      filled: true,
                      fillColor: Colors.black38,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                radius: 18,
                child: IconButton(
                  icon: const Icon(Icons.send, size: 14, color: Colors.black),
                  onPressed: _submitComment,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class InteractiveHeartOverlay extends StatefulWidget {
  const InteractiveHeartOverlay({super.key});

  @override
  State<InteractiveHeartOverlay> createState() => _InteractiveHeartOverlayState();
}

class _InteractiveHeartOverlayState extends State<InteractiveHeartOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_animController);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: const Icon(
        Icons.favorite,
        color: Colors.white,
        size: 96,
      ),
    );
  }
}

// ---------------------- REELS VIEWER SCREEN ----------------------
class ReelsViewerScreen extends ConsumerStatefulWidget {
  final List<PostModel> clips;
  final int initialIndex;

  const ReelsViewerScreen({
    super.key,
    required this.clips,
    required this.initialIndex,
  });

  @override
  ConsumerState<ReelsViewerScreen> createState() => _ReelsViewerScreenState();
}

class _ReelsViewerScreenState extends ConsumerState<ReelsViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<PostModel> _clips;

  @override
  void initState() {
    super.initState();
    _clips = List.from(widget.clips);
    _currentIndex = widget.initialIndex.clamp(0, _clips.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Release the last-active video controller when the fullscreen reels
    // viewer is popped so we never leave a decoder + texture behind.
    try {
      ref.read(activeVideoUrlProvider.notifier).state = null;
      ref.read(preloadedVideoUrlProvider.notifier).state = null;
    } catch (_) {}
    super.dispose();
  }

  void _onLike(int index) {
    final clip = _clips[index];
    ref.read(sharedLikeStateProvider.notifier).toggleLike(clip);
  }

  void _onBookmark(int index) {
    final clip = _clips[index];
    final bool newBookmarkState = !clip.hasBookmarked;

    setState(() {
      _clips[index] = clip.copyWith(
        hasBookmarked: newBookmarkState,
      );
    });

    final authUid = FirebaseAuth.instance.currentUser?.uid;
    final userId = (authUid != null && authUid.isNotEmpty)
        ? authUid
        : ref.read(loggedInUserIdProvider);

    if (newBookmarkState) {
      CacheManager().addBookmarkedPostId(userId, clip.id);
    } else {
      CacheManager().removeBookmarkedPostId(userId, clip.id);
    }

    ref.read(bookmarkRepositoryProvider).toggleBookmark(userId, clip);
  }

  void _onShare(int index) {
    final clip = _clips[index];
    setState(() {
      _clips[index] = clip.copyWith(shares: clip.shares + 1);
    });
    ref.read(postRepositoryProvider).incrementShareCount(clip.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareContentBottomSheet(
        reelId: clip.id,
        shareType: 'reel',
      ),
    );
  }

  void _onDeleted(int index) {
    if (index < 0 || index >= _clips.length) return;
    setState(() {
      _clips.removeAt(index);
      if (_currentIndex >= _clips.length && _clips.isNotEmpty) {
        _currentIndex = _clips.length - 1;
      }
    });
    if (_clips.isEmpty && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _clips.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              ref.read(postRepositoryProvider).incrementViewCount(_clips[index].id);
            },
            itemBuilder: (context, index) {
              final clip = _clips[index];
              return ClipPlayerItem(
                key: ValueKey('reels_viewer_${clip.id}'),
                clip: clip,
                isActive: index == _currentIndex,
                onBookmark: () => _onBookmark(index),
                onShare: () => _onShare(index),
                onDelete: () => _onDeleted(index),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
              onPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }
}
