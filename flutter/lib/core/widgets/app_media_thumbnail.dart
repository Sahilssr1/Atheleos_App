import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:shimmer/shimmer.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

/// A robust media thumbnail widget that displays images or video thumbnails.
///
/// If a video doesn't have an image thumbnail or has a raw .mp4 URL as thumbnail,
/// it gracefully loads the first frame of the video using [VideoPlayerController],
/// preventing black or empty blank boxes across search and profile grids.
class AppMediaThumbnail extends StatefulWidget {
  final String? imageUrl;
  final String? videoUrl;
  final bool isVideo;
  final BoxFit fit;
  final int memCacheWidth;
  final bool showPlayIcon;
  final double playIconSize;

  const AppMediaThumbnail({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.isVideo = false,
    this.fit = BoxFit.cover,
    this.memCacheWidth = 400,
    this.showPlayIcon = false,
    this.playIconSize = 20,
  });

  @override
  State<AppMediaThumbnail> createState() => _AppMediaThumbnailState();
}

class _AppMediaThumbnailState extends State<AppMediaThumbnail> {
  bool _imageFailed = false;

  bool _isDirectVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    return clean.endsWith('.mp4') ||
        clean.endsWith('.mov') ||
        clean.endsWith('.webm') ||
        clean.endsWith('.m3u8') ||
        clean.contains('.mp4?') ||
        clean.contains('.mov?') ||
        clean.contains('/video/upload/');
  }

  String? _resolveImageUrl() {
    String raw = widget.imageUrl?.trim() ?? '';
    // If no imageUrl provided and not a video, videoUrl is actually the media image URL!
    if (raw.isEmpty && !widget.isVideo) {
      raw = widget.videoUrl?.trim() ?? '';
    }
    if (raw.isEmpty) {
      if (widget.isVideo && widget.videoUrl != null) {
        final vUrl = widget.videoUrl!.trim();
        if (vUrl.contains('/media/') && vUrl.endsWith('.mp4')) {
          return vUrl.replaceAll('.mp4', '_thumb.jpg');
        }
        if (vUrl.contains('/video/upload/')) {
          return vUrl
              .replaceAll('/video/upload/', '/video/upload/so_0/')
              .replaceAll(RegExp(r'\.(mp4|mov|webm)$', caseSensitive: false), '.jpg');
        }
      }
      return null;
    }

    // If raw thumbnailUrl was mistakenly saved as a direct video URL (.mp4), resolve to thumb
    if (_isDirectVideoUrl(raw)) {
      if (raw.contains('/media/') && raw.endsWith('.mp4')) {
        return raw.replaceAll('.mp4', '_thumb.jpg');
      }
      if (raw.contains('/video/upload/')) {
        return raw
            .replaceAll('/video/upload/', '/video/upload/so_0/')
            .replaceAll(RegExp(r'\.(mp4|mov|webm)$', caseSensitive: false), '.jpg');
      }
      return null;
    }

    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveImg = _resolveImageUrl();
    final effectiveVideo = widget.videoUrl?.trim() ?? (widget.isVideo ? widget.imageUrl?.trim() : null);

    Widget content;

    if (effectiveImg != null && effectiveImg.startsWith('http') && !_imageFailed) {
      content = CachedNetworkImage(
        imageUrl: effectiveImg,
        fit: widget.fit,
        memCacheWidth: widget.memCacheWidth,
        placeholder: (_, __) => _buildShimmer(),
        errorWidget: (_, __, ___) {
          // If thumbnail image fails and we have videoUrl, fallback to video frame
          if (widget.isVideo && effectiveVideo != null && effectiveVideo.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _imageFailed = true);
            });
          }
          return _buildFallback(isVid: widget.isVideo);
        },
      );
    } else if (widget.isVideo && effectiveVideo != null && effectiveVideo.isNotEmpty) {
      content = _VideoFirstFrame(
        videoUrl: effectiveVideo,
        fit: widget.fit,
      );
    } else {
      content = _buildFallback(isVid: widget.isVideo);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (widget.showPlayIcon)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AthIcons.playCircleFill,
                size: widget.playIconSize,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF161616),
      highlightColor: const Color(0xFF242424),
      child: Container(color: const Color(0xFF161616)),
    );
  }

  Widget _buildFallback({required bool isVid}) {
    return Container(
      color: const Color(0xFF161616),
      alignment: Alignment.center,
      child: Icon(
        isVid ? AthIcons.playCircle : AthIcons.photo,
        color: Colors.white24,
        size: 28,
      ),
    );
  }
}

/// Lightweight video preview that loads and freezes on the 1st frame.
class _VideoFirstFrame extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;

  const _VideoFirstFrame({
    required this.videoUrl,
    required this.fit,
  });

  @override
  State<_VideoFirstFrame> createState() => _VideoFirstFrameState();
}

class _VideoFirstFrameState extends State<_VideoFirstFrame> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant _VideoFirstFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initVideo();
    }
  }

  void _disposeController() {
    try {
      _controller?.pause();
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initialized = false;
  }

  Future<void> _initVideo() async {
    final cleanUrl = widget.videoUrl.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(cleanUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _controller = ctrl;
      await ctrl.initialize();
      await ctrl.seekTo(Duration.zero);
      await ctrl.pause();
      if (mounted) {
        setState(() {
          _initialized = true;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF181818),
        alignment: Alignment.center,
        child: const Icon(AthIcons.playCircle, color: Colors.white24, size: 28),
      );
    }

    if (!_initialized || _controller == null) {
      return Shimmer.fromColors(
        baseColor: const Color(0xFF161616),
        highlightColor: const Color(0xFF242424),
        child: Container(color: const Color(0xFF161616)),
      );
    }

    return FittedBox(
      fit: widget.fit,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width > 0 ? _controller!.value.size.width : 720,
        height: _controller!.value.size.height > 0 ? _controller!.value.size.height : 1280,
        child: VideoPlayer(_controller!),
      ),
    );
  }
}
