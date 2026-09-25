import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../../core/services/sports_service.dart';
import '../../../../core/services/mention_service.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../../core/widgets/sport_selector_field.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import '../../../../core/utils/user_facing_error.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();
  PostCategory _selectedCategory = PostCategory.general;
  String _selectedSport = SportsService.supportedSports.first; // Mandatory default sport

  final List<PostCategory> _categories = [
    PostCategory.training,
    PostCategory.match,
    PostCategory.achievement,
    PostCategory.recovery,
    PostCategory.general,
  ];

  String _categoryName(PostCategory c) {
    switch (c) {
      case PostCategory.training: return 'Training';
      case PostCategory.match: return 'Match';
      case PostCategory.achievement: return 'Achievement';
      case PostCategory.recovery: return 'Recovery';
      case PostCategory.general: return 'General';
    }
  }

  XFile? _pickedFile;
  bool _isVideo = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _success = false;
  Timer? _progressTimer;

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  // Cloudinary video thumbnail helper removed. R2 generated thumbnails are used directly.

  Future<void> _pickMedia(bool pickVideo) async {
    final picker = ImagePicker();
    final XFile? file = pickVideo
        ? await picker.pickVideo(source: ImageSource.gallery)
        : await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
    if (file != null) {
      if (pickVideo) {
        final length = await file.length();
        if (length > 250 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video exceeds the 250MB limit. Please select a shorter or compressed clip.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      }
      setState(() {
        _pickedFile = file;
        _isVideo = pickVideo;
      });
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: AppTheme.primaryColor),
              title: Text('Choose Photo', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickMedia(false); },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: AppTheme.primaryColor),
              title: Text('Choose Video', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickMedia(true); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePublish() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a caption first.')),
      );
      return;
    }

    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? ref.read(loggedInUserIdProvider);
    ProfileModel? userProfile = ref.read(currentUserProvider).valueOrNull;
    if (userProfile == null || userProfile.id != currentUid) {
      if (currentUid.isNotEmpty) {
        userProfile = await ref.read(userRepositoryProvider).getUserById(currentUid);
      }
    }
    userProfile ??= ref.read(activeProfileProvider).valueOrNull;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final String resolvedId = (userProfile != null && userProfile.id.isNotEmpty)
        ? userProfile.id
        : currentUid;
    final String resolvedName = (userProfile != null && userProfile.name.isNotEmpty)
        ? userProfile.name
        : (firebaseUser?.displayName != null && firebaseUser!.displayName!.isNotEmpty ? firebaseUser.displayName! : 'Athlete');
    final String resolvedAvatar = (userProfile != null && userProfile.avatarUrl.isNotEmpty)
        ? userProfile.avatarUrl
        : (firebaseUser?.photoURL ?? '');
    final String resolvedPosition = (userProfile != null && userProfile.primaryPosition.isNotEmpty)
        ? (userProfile.primaryPosition.split(' ').firstOrNull ?? 'Athlete')
        : 'Athlete';
    final bool resolvedVerified = userProfile?.verified ?? false;

    setState(() { _isUploading = true; _uploadProgress = 0.0; });

    String? mediaUrl;
    String? thumbnailUrl;
    String? uploadedMediaId;
    int? actualWidth;
    int? actualHeight;
    double? actualDuration;
    final postId = const Uuid().v4();

    try {
      if (_pickedFile != null) {
        Uint8List? bytes;
        String? filePath;

        if (kIsWeb) {
          bytes = await _pickedFile!.readAsBytes();
        } else {
          filePath = _pickedFile!.path;
        }

        final idempotencyKey = const Uuid().v4();
        final queue = ref.read(uploadQueueProvider.notifier);
        
        final taskId = await queue.addTask(
          bytes: bytes,
          filePath: filePath,
          fileName: _pickedFile!.name,
          ownerType: 'post',
          idempotencyKey: idempotencyKey,
        );

        UploadTask? completedTask;
        
        await for (final tasks in ref.read(uploadQueueProvider.notifier).stream) {
          final matchingTasks = tasks.where((t) => t.id == taskId);
          final t = matchingTasks.isNotEmpty ? matchingTasks.first : null;
          if (t == null) break;
          
          if (t.status == UploadStatus.completed) {
            completedTask = t;
            break;
          }
          if (t.status == UploadStatus.failed || t.status == UploadStatus.cancelled) {
            throw Exception(t.errorMessage ?? 'Upload failed');
          }
          setState(() {
            _uploadProgress = t.progress;
          });
        }

        if (completedTask == null || completedTask.mediaId == null) {
          throw Exception('Upload task failed to return a valid media ID.');
        }

        final mediaId = completedTask.mediaId!;
        uploadedMediaId = mediaId;
        
        DocumentSnapshot<Map<String, dynamic>> docSnap = await FirebaseFirestore.instance
            .collection('media')
            .doc(mediaId)
            .snapshots()
            .firstWhere((snap) => snap.exists && snap.data()?['status'] == 'ready')
            .timeout(const Duration(minutes: 1), onTimeout: () {
              throw TimeoutException('Media processing timed out.');
            });

        final mediaData = docSnap.data()!;
        final urls = mediaData['urls'] as Map;
        mediaUrl = urls['original'] as String;
        thumbnailUrl = urls['thumbnail'] as String?;

        if (_isVideo && mediaData['videoMetadata'] != null) {
          final vMeta = mediaData['videoMetadata'] as Map<dynamic, dynamic>;
          final vWidth = (vMeta['width'] as num?)?.toInt();
          final vHeight = (vMeta['height'] as num?)?.toInt();
          if (vWidth != null && vWidth > 0 && vHeight != null && vHeight > 0) {
            actualWidth = vWidth;
            actualHeight = vHeight;
          }
          final vDur = (vMeta['duration'] as num?)?.toDouble();
          if (vDur != null && vDur > 0) {
            actualDuration = vDur;
          }
        }
      }

      setState(() { _uploadProgress = 1.0; });
      await Future.delayed(const Duration(milliseconds: 300));

      if (actualWidth == null || actualHeight == null) {
        actualWidth = _isVideo ? 1080 : 1080;
        actualHeight = _isVideo ? 1920 : 1080;

        try {
          if (_pickedFile != null) {
            if (_isVideo) {
              VideoPlayerController? tempController;
              try {
                if (kIsWeb) {
                  tempController = VideoPlayerController.networkUrl(Uri.parse(mediaUrl ?? ''));
                } else {
                  tempController = VideoPlayerController.file(File(_pickedFile!.path));
                }
                await tempController.initialize();
                final bool isRotated = tempController.value.rotationCorrection == 90 ||
                    tempController.value.rotationCorrection == 270;
                actualWidth = (isRotated ? tempController.value.size.height : tempController.value.size.width).toInt();
                actualHeight = (isRotated ? tempController.value.size.width : tempController.value.size.height).toInt();
              } catch (_) {} finally {
                tempController?.dispose();
              }
            } else {
              final bytes = await _pickedFile!.readAsBytes();
              final codec = await ui.instantiateImageCodec(bytes);
              final frame = await codec.getNextFrame();
              actualWidth = frame.image.width;
              actualHeight = frame.image.height;
              frame.image.dispose();
            }
          }
        } catch (_) {}
      }

      final mediaList = mediaUrl != null ? [
        MediaItem(
          mediaUrl: mediaUrl,
          mediaType: _isVideo ? 'video' : 'image',
          thumbnailUrl: thumbnailUrl ?? mediaUrl,
          publicId: uploadedMediaId ?? postId,
          width: actualWidth,
          height: actualHeight,
          duration: _isVideo ? (actualDuration ?? 15.0) : null,
        )
      ] : <MediaItem>[];

      final allProfiles = ref.read(profileListProvider).valueOrNull ?? [];
      final mentions = MentionService.parseAndMapMentions(_contentController.text.trim(), allProfiles);

      final post = PostModel(
        id: postId,
        type: 'post',
        userId: resolvedId,
        userName: resolvedName,
        userAvatar: resolvedAvatar,
        sport: _selectedSport,
        position: resolvedPosition,
        verified: resolvedVerified,
        content: _contentController.text.trim(),
        media: mediaList,
        category: _selectedCategory,
        likes: 0,
        commentsCount: 0,
        shares: 0,
        bookmarks: 0,
        views: 0,
        hasLiked: false,
        hasBookmarked: false,
        createdAt: DateTime.now(),
        mentions: mentions,
      );

      final Map<String, dynamic> data = post.toMap();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['likeCount'] = 0;
      data['bookmarkedBy'] = <String>[];
      data['bookmarkCount'] = 0;

      await FirebaseFirestore.instance.collection('posts').doc(postId).set(data);

      try {
        await MentionService.sendMentionNotifications(
          senderId: resolvedId,
          senderName: resolvedName,
          senderAvatar: resolvedAvatar,
          textContent: _contentController.text.trim(),
          targetType: 'post',
          targetId: postId,
          mentions: mentions,
        );
      } catch (err) {
        debugPrint('AtheleosDebug: Step 2 - Failed: $err');
      }

      if (resolvedId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(resolvedId)
              .update({'postsCount': FieldValue.increment(1)});
        } catch (err) {
          debugPrint('AtheleosDebug: Step 3 - Failed: $err');
        }
      }
      
      ref.invalidate(feedPostsProvider);

      ref.read(profileListProvider.notifier).loadAllProfiles();

      if (mounted) {
        setState(() { _isUploading = false; _success = true; });
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            setState(() {
              _success = false;
              _contentController.clear();
              _pickedFile = null;
              _uploadProgress = 0.0;
            });
          }
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() { _isUploading = false; _uploadProgress = 0.0; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Upload failed. Please try again.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text('Content Published!',
                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Your upload is now live on the platform.',
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Create Highlight',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _handlePublish,
            child: Text('Publish',
                style: GoogleFonts.spaceGrotesk(
                    color: _isUploading ? Colors.white24 : AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Select Sport (Mandatory)
                Text('Select Sport',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  child: SportSelectorField(
                    initialSport: _selectedSport,
                    hintText: 'Search or Select Sport',
                    onSportChanged: _isUploading ? (val) {} : (val) {
                      setState(() {
                        _selectedSport = val.isEmpty ? SportsService.supportedSports.first : val;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 20),

                // Caption
                Text('Caption',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 8),
                 MentionAutocompleteOverlay(
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocusNode,
                    maxLines: 4,
                    enabled: !_isUploading,
                    style: GoogleFonts.inter(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Share your training, match highlight, or achievement...',
                      hintStyle: GoogleFonts.inter(color: Colors.white24),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF262626), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF121212),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Category
                Text('Category',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(_categoryName(cat)),
                      selected: isSelected,
                      onSelected: _isUploading ? null : (selected) {
                        setState(() { _selectedCategory = cat; });
                      },
                      selectedColor: AppTheme.primaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Media picker
                Text('Media (Optional)',
                    style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isUploading ? null : () {
                    _showMediaPicker();
                  },
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF262626), width: 1),
                    ),
                    child: _pickedFile != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: kIsWeb
                                    ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                                    : (_isVideo
                                        ? Container(
                                            color: const Color(0xFF141414),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.videocam, color: AppTheme.primaryColor, size: 48),
                                                const SizedBox(height: 8),
                                                Text(_pickedFile!.name,
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                    overflow: TextOverflow.ellipsis),
                                              ],
                                            ),
                                          )
                                        : Image.file(File(_pickedFile!.path), fit: BoxFit.cover)),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.black38,
                                ),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('Tap to change',
                                        style: TextStyle(color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined,
                                  size: 40, color: Colors.white.withValues(alpha: 0.3)),
                              const SizedBox(height: 10),
                              Text('Tap to pick a photo or video',
                                  style: GoogleFonts.spaceGrotesk(
                                      fontWeight: FontWeight.bold, color: Colors.white54)),
                              const SizedBox(height: 4),
                              Text('Uploads directly to Cloudflare R2',
                                  style: GoogleFonts.inter(
                                      color: Colors.white24, fontSize: 11)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 28),

                // Publish button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isUploading ? null : _handlePublish,
                    child: Text('PUBLISH HIGHLIGHT',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),

          // Upload progress overlay
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _pickedFile != null ? 'Uploading to Cloudflare...' : 'Publishing...',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _pickedFile != null ? _uploadProgress : null,
                        backgroundColor: Colors.white12,
                        color: AppTheme.primaryColor,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      if (_pickedFile != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
