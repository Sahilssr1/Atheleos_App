import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';

class FullScreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final String senderName;
  final DateTime timestamp;
  final bool isGif;
  final VoidCallback? onReply;
  final void Function(String emoji)? onReact;

  const FullScreenMediaViewer({
    super.key,
    required this.mediaUrl,
    required this.senderName,
    required this.timestamp,
    this.isGif = false,
    this.onReply,
    this.onReact,
  });

  static Future<void> show(
    BuildContext context, {
    required String mediaUrl,
    required String senderName,
    required DateTime timestamp,
    bool isGif = false,
    VoidCallback? onReply,
    void Function(String emoji)? onReact,
  }) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, anim, _) => FullScreenMediaViewer(
          mediaUrl: mediaUrl,
          senderName: senderName,
          timestamp: timestamp,
          isGif: isGif,
          onReply: onReply,
          onReact: onReact,
        ),
        transitionsBuilder: (context, anim, _, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  State<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends State<FullScreenMediaViewer> {
  final TransformationController _transformController = TransformationController();
  final TextEditingController _replyController = TextEditingController();
  double _dragOffsetY = 0;
  bool _showControls = true;

  @override
  void dispose() {
    _transformController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  String _formatFullTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 2) return 'Just now';
    if (difference.inHours < 24 && dt.day == now.day) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return 'Today at $hour:$min $ampm';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isBase64 = widget.mediaUrl.startsWith('data:image');
    final formattedTime = _formatFullTimestamp(widget.timestamp);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: (1.0 - (_dragOffsetY.abs() / 400.0)).clamp(0.0, 1.0)),
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffsetY += details.primaryDelta ?? 0;
          });
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY.abs() > 100 || (details.primaryVelocity?.abs() ?? 0) > 800) {
            Navigator.pop(context);
          } else {
            setState(() {
              _dragOffsetY = 0;
            });
          }
        },
        child: Stack(
          children: [
            // Center interactive zoomable image/GIF
            Center(
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 1.0,
                  maxScale: 4.0,
                  onInteractionEnd: (_) {
                    if (_transformController.value.getMaxScaleOnAxis() < 1.0) {
                      _transformController.value = Matrix4.identity();
                    }
                  },
                  child: Hero(
                    tag: widget.mediaUrl,
                    child: isBase64
                        ? Image.memory(
                            base64Decode(widget.mediaUrl.split(',').last),
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : CachedNetworkImage(
                            imageUrl: widget.mediaUrl,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 54),
                            ),
                          ),
                  ),
                ),
              ),
            ),

            // Top Navigation Bar (WhatsApp style)
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 8,
                    right: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.senderName,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formattedTime,
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.reply_rounded, color: Colors.white),
                        tooltip: 'Reply',
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onReply?.call();
                        },
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Quick Reply & Reaction bar (WhatsApp style)
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 10,
                    top: 10,
                    left: 16,
                    right: 16,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onReply?.call();
                            },
                            child: const Text(
                              'Reply...',
                              style: TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Quick reaction emojis
                      ...['❤️', '😂', '🔥'].map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onReact?.call(emoji);
                              Navigator.pop(context);
                            },
                            child: Text(emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
