import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:shimmer/shimmer.dart';
import '../services/cache_manager.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Video lifecycle policy (Instagram-style)
// ─────────────────────────────────────────────────────────────────────────────
// Only ONE video plays at a time (`activeVideoUrlProvider`).
//
// A widget is allowed to hold a live [VideoPlayerController] only if its URL
// is EITHER the active URL OR the single preloaded/next URL. Every other
// off-screen `PostMediaWidget` MUST fully dispose its controller so the
// native video decoder + texture is released back to the OS.
//
// The Feed notifier updates `preloadedVideoUrlProvider` to the very next
// video that the user is likely to watch (based on scroll direction), so
// activating it feels instant while never keeping more than 2 controllers
// alive at once.
// ─────────────────────────────────────────────────────────────────────────────

/// URL of the video that is currently visible and playing. `null` when nothing
/// is playing (e.g. the user is scrolling between videos or on a non-video
/// post).
final activeVideoUrlProvider = StateProvider<String?>((ref) => null);

/// URL of the single "next" video we want to keep initialized in the
/// background for near-instant playback when it scrolls into view. Set to
/// `null` when there is no such candidate.
final preloadedVideoUrlProvider = StateProvider<String?>((ref) => null);

/// Global mute state, shared across every video in the app so toggling mute
/// on one feed video mutes every other one (Instagram behaviour).
final videosMutedProvider = StateProvider<bool>((ref) => true);

class PostMediaWidget extends ConsumerStatefulWidget {
  final String mediaUrl;
  final String mediaType; // "image" or "video"
  final String? thumbnailUrl;
  final bool isLiked;
  final VoidCallback onDoubleTapLike;
  final double? maxAspectRatio; // optional limit to avoid extremely tall posts
  final int? mediaWidth;
  final int? mediaHeight;
  final VoidCallback? onMediaTap;

  const PostMediaWidget({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    required this.isLiked,
    required this.onDoubleTapLike,
    this.maxAspectRatio,
    this.mediaWidth,
    this.mediaHeight,
    this.onMediaTap,
  });

  /// Computes the known aspect ratio from width/height metadata,
  /// falling back to 4/5 (portrait default like Instagram) if unknown.
  /// Clamps to avoid extremely tall or wide posts.
  double get knownAspectRatio {
    if (mediaWidth != null && mediaHeight != null && mediaWidth! > 0 && mediaHeight! > 0) {
      final raw = mediaWidth! / mediaHeight!;
      // Clamp between 4:5 (portrait) and 16:9 (landscape)
      return raw.clamp(0.8, 1.91);
    }
    // Default fallback: 4:5 portrait (Instagram default placeholder)
    return 4 / 5;
  }

  @override
  ConsumerState<PostMediaWidget> createState() => _PostMediaWidgetState();
}

class _PostMediaWidgetState extends ConsumerState<PostMediaWidget> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isInitializing = false;

  /// Monotonically increasing token guarding against stale async
  /// [_initializeVideo] completions writing to a controller that has already
  /// been disposed (which crashes the native texture).
  int _initGeneration = 0;

  // Heart overlay animation on double tap
  late AnimationController _heartController;
  late Animation<double> _heartScale;
  late Animation<double> _heartOpacity;
  bool _showHeart = false;

  // Show visual feedback when mute state changes
  bool _showMuteIndicator = false;
  late DateTime _lastMuteIndicatorTime;

  // Track last known video state to avoid unnecessary rebuilds
  bool _lastBuffering = false;
  bool _lastPlaying = false;

  @override
  void initState() {
    super.initState();
    _lastMuteIndicatorTime = DateTime.now();

    // Setup heart animation
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_heartController);

    _heartOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 0.95), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 0.95), weight: 45),
      TweenSequenceItem(tween: Tween<double>(begin: 0.95, end: 0.0), weight: 20),
    ]).animate(_heartController);

    if (widget.mediaType == 'video') {
      // Reconcile against current provider state after the first frame so we
      // can subscribe to future changes via `ref.listen` in build().
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _reconcileControllerLifecycle();
      });
    }
  }

  bool get _shouldHoldController {
    if (widget.mediaType != 'video') return false;
    final active = ref.read(activeVideoUrlProvider);
    final preloaded = ref.read(preloadedVideoUrlProvider);
    return widget.mediaUrl == active || widget.mediaUrl == preloaded;
  }

  bool get _shouldPlay {
    return widget.mediaType == 'video' &&
        ref.read(activeVideoUrlProvider) == widget.mediaUrl;
  }

  /// Central state machine: brings the widget's controller into agreement
  /// with the current active/preload policy. Called on every provider change
  /// and whenever the widget updates.
  void _reconcileControllerLifecycle() {
    if (!mounted) return;
    if (widget.mediaType != 'video') return;

    final shouldHold = _shouldHoldController;
    final shouldPlay = _shouldPlay;

    if (!shouldHold) {
      // We're neither the active nor the preload target → free the native
      // decoder + texture immediately.
      _disposeVideo();
      return;
    }

    if (_videoController == null && !_isInitializing && !_hasError) {
      _initializeVideo();
      return;
    }

    // Controller already exists → toggle play/pause based on policy.
    final controller = _videoController;
    if (controller != null && _isInitialized) {
      if (shouldPlay && !controller.value.isPlaying) {
        controller.play();
      } else if (!shouldPlay && controller.value.isPlaying) {
        controller.pause();
      }
    }
  }

  String _getAdaptiveStreamUrl(String url) {
    if (url.contains('cloudinary.com/video/upload/')) {
      final parts = url.split('/upload/');
      if (parts.length == 2) {
        String afterUpload = parts[1];
        if (afterUpload.endsWith('.mp4')) {
          afterUpload = '${afterUpload.substring(0, afterUpload.length - 4)}.m3u8';
          // sp_auto enables Cloudinary's dynamic adaptive streaming (HLS)
          return '${parts[0]}/upload/sp_auto/$afterUpload';
        }
      }
    }
    return url;
  }

  Future<void> _initializeVideo() async {
    if (widget.mediaUrl.isEmpty || _isInitializing) return;

    _isInitializing = true;
    final generation = ++_initGeneration;
    setState(() {
      _hasError = false;
      _isInitialized = false;
    });

    VideoPlayerController? localController;
    try {
      final adaptiveUrl = _getAdaptiveStreamUrl(widget.mediaUrl);
      localController = VideoPlayerController.networkUrl(Uri.parse(adaptiveUrl));

      await localController.initialize();

      // Abort if this init has been superseded (widget disposed, URL changed,
      // or lifecycle policy moved this widget out of the hold window).
      if (!mounted || generation != _initGeneration) {
        await localController.dispose();
        return;
      }

      await localController.setLooping(true);
      final isMuted = ref.read(videosMutedProvider);
      await localController.setVolume(isMuted ? 0.0 : 1.0);

      if (!mounted || generation != _initGeneration) {
        await localController.dispose();
        return;
      }

      _videoController = localController;
      localController.addListener(_videoPlayerListener);

      setState(() {
        _isInitialized = true;
      });

      // Auto-play if we're the active video; otherwise stay paused
      // (preloaded but not playing).
      if (_shouldPlay) {
        await localController.play();
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // Best-effort cleanup of the local controller so a failed init never
      // leaks a native decoder.
      try {
        if (localController != null && localController != _videoController) {
          await localController.dispose();
        }
      } catch (_) {}
      if (mounted && generation == _initGeneration) {
        setState(() {
          _hasError = true;
        });
      }
    } finally {
      if (generation == _initGeneration) {
        _isInitializing = false;
      }
    }
  }

  void _videoPlayerListener() {
    if (!mounted || _videoController == null) return;
    final isBuffering = _videoController!.value.isBuffering;
    final isPlaying = _videoController!.value.isPlaying;
    if (isBuffering != _lastBuffering || isPlaying != _lastPlaying) {
      _lastBuffering = isBuffering;
      _lastPlaying = isPlaying;
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(PostMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaUrl != oldWidget.mediaUrl || widget.mediaType != oldWidget.mediaType) {
      _disposeVideo();
      if (widget.mediaType == 'video') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _reconcileControllerLifecycle();
        });
      }
    }
  }

  /// Fully releases the native decoder + texture backing this widget's video.
  ///
  /// Safe to call multiple times — bumps the init generation so any in-flight
  /// [_initializeVideo] running against the old controller aborts on its next
  /// await point instead of writing to a disposed controller.
  void _disposeVideo() {
    _initGeneration++;
    final controller = _videoController;
    _videoController = null;
    _isInitialized = false;
    _hasError = false;
    _lastBuffering = false;
    _lastPlaying = false;
    if (controller != null) {
      controller.removeListener(_videoPlayerListener);
      // Pause synchronously, then dispose. `dispose()` returns a Future but
      // we don't await it here — it's fire-and-forget cleanup and awaiting
      // would delay list scrolling.
      try {
        controller.pause();
      } catch (_) {}
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _heartController.dispose();
    _disposeVideo();
    super.dispose();
  }

  void _triggerDoubleTapLike() {
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
    widget.onDoubleTapLike();
  }

  void _toggleMute() {
    final currentMute = ref.read(videosMutedProvider);
    final newMute = !currentMute;
    ref.read(videosMutedProvider.notifier).state = newMute;

    // Show temporary mute/unmute volume overlay indicator
    setState(() {
      _showMuteIndicator = true;
      _lastMuteIndicatorTime = DateTime.now();
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && DateTime.now().difference(_lastMuteIndicatorTime).inMilliseconds >= 900) {
        setState(() {
          _showMuteIndicator = false;
        });
      }
    });
  }

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.08),
      child: AspectRatio(
        aspectRatio: widget.knownAspectRatio,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return AspectRatio(
      aspectRatio: widget.knownAspectRatio,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Failed to load media',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  if (widget.mediaType == 'video') {
                    setState(() {
                      _hasError = false;
                    });
                    _reconcileControllerLifecycle();
                  } else {
                    setState(() {});
                  }
                },
                icon: const Icon(Icons.refresh, size: 16, color: AppTheme.primaryColor),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // React to any change that could affect our controller lifecycle:
    //  * active URL changed (some other video became active / no active video)
    //  * preloaded URL changed (we might newly enter/exit the hold window)
    //  * mute state changed (adjust volume)
    if (widget.mediaType == 'video') {
      ref.listen<String?>(activeVideoUrlProvider, (prev, next) {
        _reconcileControllerLifecycle();
      });
      ref.listen<String?>(preloadedVideoUrlProvider, (prev, next) {
        _reconcileControllerLifecycle();
      });
      ref.listen<bool>(videosMutedProvider, (prev, next) {
        final controller = _videoController;
        if (controller != null && _isInitialized) {
          controller.setVolume(next ? 0.0 : 1.0);
        }
      });
    }

    final isMuted = ref.watch(videosMutedProvider);

    return GestureDetector(
      onDoubleTap: _triggerDoubleTapLike,
      onTap: widget.mediaType == 'video' ? (widget.onMediaTap ?? _toggleMute) : widget.onMediaTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // MEDIA RENDERER
            if (widget.mediaType == 'image')
              AspectRatio(
                aspectRatio: widget.knownAspectRatio,
                child: CachedNetworkImage(
                  imageUrl: widget.mediaUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildShimmerPlaceholder(),
                  errorWidget: (context, url, error) => _buildErrorWidget(),
                ),
              )
            else if (widget.mediaType == 'video')
              _hasError
                  ? _buildErrorWidget()
                  : !_isInitialized
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            // Show thumbnail while initializing video
                            if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: widget.thumbnailUrl!,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => _buildShimmerPlaceholder(),
                                errorWidget: (context, url, error) => Container(color: Colors.black),
                              )
                            else
                              AspectRatio(
                                aspectRatio: widget.knownAspectRatio,
                                child: Container(
                                  width: double.infinity,
                                  color: Colors.black,
                                ),
                              ),
                            // Only show a spinner if this video is the active
                            // one — a paused preload should look like a still
                            // thumbnail, not a loading indicator.
                            if (_shouldPlay)
                              const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        )
                      : AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoController!),
                              // Buffer Loader spinner
                              if (_videoController!.value.isBuffering)
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primaryColor,
                                    strokeWidth: 2,
                                  ),
                                ),
                            ],
                          ),
                        ),

            // HEART POP ANIMATION OVERLAY
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
                        color: Colors.red,
                        size: 90,
                      ),
                    ),
                  );
                },
              ),

            // VOLUME/MUTE STATE OVERLAY INDICATOR
            if (widget.mediaType == 'video' && _showMuteIndicator)
              AnimatedOpacity(
                opacity: _showMuteIndicator ? 0.9 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 24,
                  child: Icon(
                    isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Wrapping class to provide Visibility Detector integration in a feed list.
//
// Uses visibility to decide which single video should be the "active" one
// (playing + audible). Also updates the preloaded URL to the widget just
// below the currently-visible one so scrolling forward is instant.
class AutoPlayVideoVisibilityWidget extends ConsumerWidget {
  final String mediaUrl;
  final String mediaType;
  final String? thumbnailUrl;
  final bool isLiked;
  final VoidCallback onDoubleTapLike;
  final Widget? child;
  final int? mediaWidth;
  final int? mediaHeight;
  final VoidCallback? onMediaTap;

  const AutoPlayVideoVisibilityWidget({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.thumbnailUrl,
    required this.isLiked,
    required this.onDoubleTapLike,
    this.child,
    this.mediaWidth,
    this.mediaHeight,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (mediaType != 'video') {
      return child ?? PostMediaWidget(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        isLiked: isLiked,
        onDoubleTapLike: onDoubleTapLike,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        onMediaTap: onMediaTap,
      );
    }

    return VisibilityDetector(
      key: Key('video_vis_${mediaUrl.hashCode}'),
      onVisibilityChanged: (info) {
        final activeUrl = ref.read(activeVideoUrlProvider);
        if (info.visibleFraction > 0.6) {
          // This video is now dominantly on screen → make it the active one.
          if (activeUrl != mediaUrl) {
            ref.read(activeVideoUrlProvider.notifier).state = mediaUrl;
          }
        } else if (info.visibleFraction == 0) {
          // Fully off-screen. If we were the active video, clear it so the
          // controller can be released. Also clear the preload slot if we
          // owned it, to avoid keeping a decoder alive for a video that has
          // scrolled far away.
          if (activeUrl == mediaUrl) {
            ref.read(activeVideoUrlProvider.notifier).state = null;
          }
          final preloaded = ref.read(preloadedVideoUrlProvider);
          if (preloaded == mediaUrl) {
            ref.read(preloadedVideoUrlProvider.notifier).state = null;
          }
        } else {
          // Partially visible but under the play threshold — pause if we
          // were the one playing. Do NOT touch the preload slot: this
          // widget is likely about to become active as scrolling continues.
          if (activeUrl == mediaUrl) {
            ref.read(activeVideoUrlProvider.notifier).state = null;
          }
        }
      },
      child: child ?? PostMediaWidget(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        thumbnailUrl: thumbnailUrl,
        isLiked: isLiked,
        onDoubleTapLike: onDoubleTapLike,
        mediaWidth: mediaWidth,
        mediaHeight: mediaHeight,
        onMediaTap: onMediaTap,
      ),
    );
  }
}

/// Best-effort helper: fully releases the currently playing feed video.
///
/// Called when the user leaves the Feed / Reels screens so that the
/// on-screen video controller is torn down along with playback + audio.
void releaseActiveFeedVideo(WidgetRef ref) {
  ref.read(activeVideoUrlProvider.notifier).state = null;
  ref.read(preloadedVideoUrlProvider.notifier).state = null;
}

// Silence the analyzer about the imported CacheManager symbol so ambient
// imports don't get tree-shaken from tooling. Preload is invoked from the
// notifier layer (feed_controller / clips_controller); we import it here to
// document the dependency for any future in-widget prefetch hooks.
// ignore: unused_element
CacheManager get _cacheManagerReference => CacheManager();
