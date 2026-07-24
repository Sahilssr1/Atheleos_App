import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final String mediaType; // "image" or "video"

  const FullscreenMediaViewer({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
  });

  static void show(BuildContext context, String mediaUrl, String mediaType) {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (context) => FullscreenMediaViewer(
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      ),
    );
  }

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initializeVideo();
    }
  }

  void _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl));
      _videoController = controller;
      await controller.initialize();
      
      if (!mounted) {
        controller.dispose();
        return;
      }

      await controller.setLooping(true);
      await controller.play();

      setState(() {
        _isInitialized = true;
        _isPlaying = true;
      });

      controller.addListener(() {
        if (mounted) {
          final nowPlaying = controller.value.isPlaying;
          if (nowPlaying != _isPlaying) {
            setState(() {
              _isPlaying = nowPlaying;
            });
          }
        }
      });
    } catch (e) {
      debugPrint("Error loading video in fullscreen: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final controller = _videoController;
    if (controller == null || !_isInitialized) return;

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _toggleMute() {
    final controller = _videoController;
    if (controller == null || !_isInitialized) return;

    final isCurrentlyMuted = controller.value.volume == 0.0;
    controller.setVolume(isCurrentlyMuted ? 1.0 : 0.0);
    setState(() {
      _isMuted = !isCurrentlyMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MEDIA VIEW
          Center(
            child: widget.mediaType == 'image'
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.mediaUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryColor),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white24, size: 48),
                      ),
                    ),
                  )
                : _hasError
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                            SizedBox(height: 12),
                            Text(
                              'Failed to play video',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : !_isInitialized
                        ? const Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor),
                          )
                        : GestureDetector(
                            onTap: _togglePlay,
                            child: AspectRatio(
                              aspectRatio: _videoController!.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  VideoPlayer(_videoController!),
                                  
                                  // Play/Pause big center icon when paused
                                  if (!_isPlaying)
                                    const Center(
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.black45,
                                        child: Icon(Icons.play_arrow, size: 40, color: Colors.white),
                                      ),
                                    ),

                                  // Video progress bar
                                  VideoProgressIndicator(
                                    _videoController!,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: AppTheme.primaryColor,
                                      bufferedColor: Colors.white24,
                                      backgroundColor: Colors.white10,
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
          ),

          // TOP NAVIGATION ACTIONS
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                // Video mute toggle button
                if (widget.mediaType == 'video' && _isInitialized)
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                      ),
                      onPressed: _toggleMute,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
