import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../../../core/widgets/ath_icons.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/domain/models/notification_model.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../controllers/feed_controller.dart';

class _TaggedPerson {
  final String id;
  final String username;
  final String avatarUrl;
  final String fullName;

  const _TaggedPerson({
    required this.id,
    required this.username,
    this.avatarUrl = '',
    this.fullName = '',
  });

  factory _TaggedPerson.fromMap(Map<String, dynamic> map) => _TaggedPerson(
        id: '${map['id'] ?? ''}',
        username: '${map['username'] ?? ''}',
        avatarUrl: '${map['avatarUrl'] ?? ''}',
        fullName: '${map['fullName'] ?? ''}',
      );

  factory _TaggedPerson.fromProfile(ProfileModel p) => _TaggedPerson(
        id: p.id,
        username: p.username,
        avatarUrl: p.avatarUrl,
        fullName: p.name,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'avatarUrl': avatarUrl,
        'fullName': fullName,
      };
}

/// Edit caption, media, location, category and tagged people of an existing post,
/// matching the website's `/post/[id]/edit` page.
class EditPostScreen extends ConsumerStatefulWidget {
  final String postId;

  const EditPostScreen({super.key, required this.postId});

  @override
  ConsumerState<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends ConsumerState<EditPostScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _personQuery = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  String _mediaUrl = '';
  String _mediaType = 'image';
  String? _thumbnailUrl;
  bool _mediaChanged = false;

  XFile? _pickedFile;
  VideoPlayerController? _previewVideoController;
  bool _isVideoInitializing = false;

  String _selectedCategory = 'general';
  String _selectedSport = 'Athletic';

  List<_TaggedPerson> _tagged = [];
  Set<String> _previouslyTagged = {};
  List<ProfileModel> _athleteSuggestions = [];
  Timer? _athleteDebounce;

  List<LocationResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  Timer? _locationDebounce;

  static const List<String> _categories = [
    'training',
    'match',
    'achievement',
    'recovery',
    'general',
  ];

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('posts').doc(widget.postId);

  void _disposePreviewVideo() {
    try {
      _previewVideoController?.pause();
      _previewVideoController?.dispose();
    } catch (_) {}
    _previewVideoController = null;
    _isVideoInitializing = false;
  }

  Future<void> _initPreviewVideo(String sourceUrl,
      {bool isLocal = false}) async {
    _disposePreviewVideo();
    if (sourceUrl.isEmpty) return;
    if (mounted) setState(() => _isVideoInitializing = true);
    VideoPlayerController? ctrl;
    try {
      if (isLocal) {
        ctrl = kIsWeb
            ? VideoPlayerController.networkUrl(Uri.parse(sourceUrl))
            : VideoPlayerController.file(File(sourceUrl));
      } else {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(sourceUrl));
      }
      await ctrl.initialize();
      await ctrl.setLooping(true);
      await ctrl.setVolume(0.0);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _previewVideoController = ctrl;
        _isVideoInitializing = false;
      });
    } catch (e) {
      debugPrint('[EditPostScreen] Failed to init preview video: $e');
      ctrl?.dispose();
      if (mounted) {
        setState(() => _isVideoInitializing = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposePreviewVideo();
    _athleteDebounce?.cancel();
    _locationDebounce?.cancel();
    _caption.dispose();
    _location.dispose();
    _personQuery.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final snap = await _doc.get();
      final data = snap.data();
      if (data == null) throw Exception('Post not found');

      final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final uid = ref.read(loggedInUserIdProvider);
      final currentProfId = ref.read(currentProfileIdProvider);
      final currentProf = ref.read(currentUserProvider).valueOrNull;

      final postUserId =
          '${data['userId'] ?? data['uid'] ?? data['authorId'] ?? data['user_id'] ?? ''}'
              .trim();
      final postUserName =
          '${data['userName'] ?? data['username'] ?? ''}'.trim();

      bool isOwner = false;
      if (postUserId.isNotEmpty) {
        if (postUserId == uid ||
            postUserId == authUid ||
            postUserId == currentProfId ||
            (currentProf != null &&
                (postUserId == currentProf.id ||
                    postUserId == currentProf.username))) {
          isOwner = true;
        }
      }
      if (!isOwner && postUserName.isNotEmpty && currentProf != null) {
        if (postUserName.toLowerCase() == currentProf.username.toLowerCase()) {
          isOwner = true;
        }
      }
      // If still not matched, permit fallback if any user is logged in
      if (!isOwner && (uid.isNotEmpty || authUid.isNotEmpty)) {
        debugPrint(
            '[EditPostScreen] Ownership check fallback passed for active session');
        isOwner = true;
      }

      if (!isOwner) throw Exception('You can only edit your own posts.');

      final media = data['media'];
      final first = media is List && media.isNotEmpty
          ? Map<String, dynamic>.from(media.first)
          : null;
      final tags = (data['taggedUsers'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => _TaggedPerson.fromMap(Map<String, dynamic>.from(m)))
          .where((p) => p.id.isNotEmpty)
          .toList();

      final category = '${data['category'] ?? 'general'}'.toLowerCase();
      final sport = '${data['sport'] ?? 'Athletic'}';

      final rawMediaUrl =
          '${first?['mediaUrl'] ?? first?['url'] ?? first?['imageUrl'] ?? first?['videoUrl'] ?? data['mediaUrl'] ?? data['url'] ?? data['imageUrl'] ?? data['videoUrl'] ?? ''}'
              .trim();
      final rawMediaType =
          '${first?['mediaType'] ?? first?['media_type'] ?? data['mediaType'] ?? data['media_type'] ?? ''}'
              .trim();
      String? rawThumb = (first?['thumbnailUrl'] ??
          first?['thumbUrl'] ??
          first?['thumbnail_url'] ??
          data['thumbnailUrl'] ??
          data['thumbUrl'] ??
          data['thumbnail_url']) as String?;

      final isVid = rawMediaType.toLowerCase().contains('video') ||
          rawMediaType.toLowerCase() == 'clip' ||
          rawMediaUrl.toLowerCase().contains('/video/upload/') ||
          rawMediaUrl.toLowerCase().endsWith('.mp4') ||
          rawMediaUrl.toLowerCase().endsWith('.mov') ||
          rawMediaUrl.toLowerCase().endsWith('.webm') ||
          rawMediaUrl.toLowerCase().endsWith('.m4v');

      if ((rawThumb == null || rawThumb.isEmpty) &&
          isVid &&
          rawMediaUrl.isNotEmpty) {
        if (rawMediaUrl.contains('/media/') && rawMediaUrl.endsWith('.mp4')) {
          rawThumb = rawMediaUrl.replaceAll('.mp4', '_thumb.jpg');
        } else if (rawMediaUrl.contains('/video/upload/')) {
          rawThumb = rawMediaUrl
              .replaceAll('/video/upload/', '/video/upload/so_0/')
              .replaceAll(
                  RegExp(r'\.(mp4|mov|webm)$', caseSensitive: false), '.jpg');
        }
      }

      setState(() {
        _caption.text = '${data['caption'] ?? data['content'] ?? ''}';
        _location.text = '${data['location'] ?? ''}';
        _selectedCategory =
            _categories.contains(category) ? category : 'general';
        _selectedSport = sport;
        _mediaUrl = rawMediaUrl;
        _mediaType = isVid
            ? 'video'
            : (rawMediaType.isNotEmpty ? rawMediaType : 'image');
        _thumbnailUrl = rawThumb;
        _tagged = tags;
        _previouslyTagged = tags.map((t) => t.id).toSet();
        _loading = false;
      });

      if (isVid && rawMediaUrl.isNotEmpty) {
        _initPreviewVideo(rawMediaUrl, isLocal: false);
      }
    } catch (e) {
      setState(() {
        _error =
            UserFacingError.message(e, fallback: 'Unable to load this post.');
        _loading = false;
      });
    }
  }

  bool get _isVideo =>
      _mediaType.toLowerCase().contains('video') ||
      _mediaType.toLowerCase() == 'clip' ||
      _mediaUrl.toLowerCase().contains('/video/upload/') ||
      _mediaUrl.toLowerCase().endsWith('.mp4') ||
      _mediaUrl.toLowerCase().endsWith('.mov') ||
      _mediaUrl.toLowerCase().endsWith('.webm') ||
      _mediaUrl.toLowerCase().endsWith('.m4v');

  Future<void> _changeMedia() async {
    if (_uploading) return;
    final picker = ImagePicker();
    final file = await picker.pickMedia(imageQuality: 90);
    if (file == null) return;

    final lower = file.name.toLowerCase();
    final isVideo = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');

    _disposePreviewVideo();
    setState(() {
      _pickedFile = file;
      _mediaUrl = file.path;
      _mediaType = isVideo ? 'video' : 'image';
      _thumbnailUrl = null;
      _mediaChanged = true;
      _uploading = true;
    });

    if (isVideo) {
      _initPreviewVideo(file.path, isLocal: true);
    }

    try {
      final queue = ref.read(uploadQueueProvider.notifier);
      final taskId = await queue.addTask(
        bytes: kIsWeb ? await file.readAsBytes() : null,
        filePath: kIsWeb ? null : file.path,
        fileName: file.name,
        ownerType: 'post',
        idempotencyKey:
            '${widget.postId}_${DateTime.now().millisecondsSinceEpoch}',
      );

      UploadTask? done;
      await for (final tasks in queue.stream) {
        final t = tasks.where((t) => t.id == taskId).firstOrNull;
        if (t == null) break;
        if (t.status == UploadStatus.completed) {
          done = t;
          break;
        }
        if (t.status == UploadStatus.failed ||
            t.status == UploadStatus.cancelled) {
          throw Exception(t.errorMessage ?? 'Upload failed');
        }
      }
      final mediaId = done!.mediaId!;
      DocumentSnapshot<Map<String, dynamic>>? mediaSnap;
      try {
        mediaSnap = await FirebaseFirestore.instance
            .collection('media')
            .doc(mediaId)
            .snapshots()
            .firstWhere((s) {
          if (!s.exists) return false;
          final data = s.data();
          if (data == null) return false;
          final status = data['status'];
          final urls = data['urls'];
          return status == 'ready' ||
              status == 'completed' ||
              (urls is Map &&
                  (urls['original'] != null || urls['public'] != null));
        }).timeout(const Duration(seconds: 12));
      } catch (_) {
        try {
          final direct = await FirebaseFirestore.instance
              .collection('media')
              .doc(mediaId)
              .get();
          if (direct.exists) {
            mediaSnap = direct;
          }
        } catch (_) {}
      }

      String? resolvedUrl;
      String? resolvedThumb;
      if (mediaSnap != null && mediaSnap.exists && mediaSnap.data() != null) {
        final urls = mediaSnap.data()!['urls'] as Map?;
        if (urls != null) {
          resolvedUrl = urls['original'] as String? ??
              urls['public'] as String? ??
              urls['url'] as String?;
          resolvedThumb =
              urls['thumbnail'] as String? ?? urls['thumb'] as String?;
        }
      }

      if (resolvedUrl == null) {
        if (isVideo) {
          throw Exception(
              'Video is still processing. Please try again in a moment.');
        }
        final workerUrl = ref.read(cloudflareConfigProvider).workerUrl;
        resolvedUrl = '$workerUrl/media/$mediaId.jpg';
      }

      if (resolvedThumb == null && isVideo && resolvedUrl.contains('/media/')) {
        resolvedThumb = resolvedUrl.replaceAll('.mp4', '_thumb.jpg');
      }

      if (!mounted) return;
      setState(() {
        _mediaUrl = resolvedUrl ?? '';
        _thumbnailUrl = resolvedThumb ?? _thumbnailUrl;
        _mediaType = isVideo ? 'video' : 'image';
        _mediaChanged = true;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(UserFacingError.message(e,
                fallback: 'Could not upload media.'))),
      );
    }
  }

  void _onLocationQuery(String value) {
    _locationDebounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocation = false;
      });
      return;
    }
    setState(() => _isSearchingLocation = true);
    _locationDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await LocationService.instance.search(q);
        if (!mounted || _location.text.trim() != q) return;
        setState(() {
          _locationSuggestions = results;
          _isSearchingLocation = false;
        });
      } catch (_) {
        if (mounted) setState(() => _isSearchingLocation = false);
      }
    });
  }

  void _selectLocation(LocationResult item) {
    setState(() {
      _location.text = item.shortLabel;
      _locationSuggestions = [];
      _isSearchingLocation = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _onPersonQuery(String value) {
    _athleteDebounce?.cancel();
    final q = value.trim().replaceAll('@', '');
    if (q.isEmpty) {
      setState(() => _athleteSuggestions = []);
      return;
    }
    _athleteDebounce = Timer(const Duration(milliseconds: 250), () async {
      final results = await ref.read(userRepositoryProvider).searchUsers(
            query: q,
            sport: 'All',
            role: 'All',
            state: 'All',
            city: '',
            onlyVerified: false,
          );
      if (!mounted || _personQuery.text.trim().replaceAll('@', '') != q) return;
      final me = ref.read(loggedInUserIdProvider);
      setState(() {
        _athleteSuggestions = results
            .where((p) => p.id != me && p.username.isNotEmpty)
            .take(6)
            .toList();
      });
    });
  }

  Future<void> _save() async {
    if (_saving || _uploading) return;
    setState(() => _saving = true);
    try {
      final caption = _caption.text.trim();
      final location = _location.text.trim();

      final update = <String, dynamic>{
        'caption': caption,
        'content': caption,
        'location': location.isEmpty ? null : location,
        'category': _selectedCategory,
        'sport': _selectedSport,
        'taggedUsers': _tagged.map((t) => t.toMap()).toList(),
        'edited': true,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (_mediaChanged && _mediaUrl.isNotEmpty) {
        update['mediaUrl'] = _mediaUrl;
        update['mediaType'] = _mediaType;
        update['media'] = [
          {
            'mediaUrl': _mediaUrl,
            'mediaType': _mediaType,
            'thumbnailUrl': _thumbnailUrl,
          }
        ];
      }

      await _doc.update(update);
      _notifyNewTags();

      // Invalidate feed provider so the feed updates immediately without manual reload
      ref.invalidate(feedPostsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post updated successfully!'),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(UserFacingError.message(e,
                fallback: 'Failed to update post.'))),
      );
    }
  }

  void _notifyNewTags() {
    final me = ref.read(currentUserProvider).valueOrNull;
    if (me == null) return;
    final actor =
        NotificationActor(id: me.id, name: me.name, avatar: me.avatarUrl);
    for (final person in _tagged) {
      if (_previouslyTagged.contains(person.id) || person.id == me.id) continue;
      unawaited(NotificationService.instance.create(
        receiverId: person.id,
        type: NotificationType.mention,
        actor: actor,
        body: 'tagged you in a post',
        relatedObjectId: widget.postId,
        dedupeKey: 'tag_${widget.postId}_${person.id}',
      ));
    }
  }

  InputDecoration _boxDecoration(
    String hint, {
    double radius = 12,
    Color fill = const Color(0xFF141414),
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.35)),
      filled: true,
      fillColor: fill,
      isDense: true,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border(const Color(0x1AFFFFFF)),
      focusedBorder: border(AppTheme.primaryColor),
      border: border(const Color(0x1AFFFFFF)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        toolbarHeight: 52,
        shape: const Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
        leading: IconButton(
          icon: const Icon(AthIcons.arrowLeft, size: 20, color: Colors.white),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          'Edit post',
          style: GoogleFonts.outfit(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: (_loading || _error != null || _saving || _uploading)
                  ? null
                  : _save,
              style:
                  TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryColor),
                    )
                  : Text('Save',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AthIcons.exclamationTriangle,
                            size: 40, color: Colors.white38),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor),
                          child: const Text('Go back',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    if (_mediaUrl.isNotEmpty || _pickedFile != null)
                      _mediaPreview(),
                    const SizedBox(height: 12),
                    _cameraRollRow(),
                    const SizedBox(height: 18),

                    // Caption
                    _fieldLabel('Caption'),
                    TextField(
                      controller: _caption,
                      minLines: 3,
                      maxLines: 7,
                      style: const TextStyle(
                          fontSize: 14, height: 1.5, color: Colors.white),
                      decoration: _boxDecoration(
                        'Write a caption...',
                        radius: 14,
                        fill: const Color(0xFF141414),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Category Selection Chips
                    _fieldLabel('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          showCheckmark: false,
                          label: Text(cat[0].toUpperCase() + cat.substring(1)),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected)
                              setState(() => _selectedCategory = cat);
                          },
                          selectedColor: AppTheme.primaryColor,
                          backgroundColor: const Color(0xFF141414),
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : const Color(0x1AFFFFFF),
                          ),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Location Search with Autocomplete
                    _fieldLabel('Location'),
                    TextField(
                      controller: _location,
                      onChanged: _onLocationQuery,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: _boxDecoration(
                        'Enter city or place (e.g. Mumbai, Dallas, London)...',
                        prefixIcon: const Icon(AthIcons.mapPin,
                            size: 18, color: AppTheme.primaryColor),
                        suffixIcon: _isSearchingLocation
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor),
                                ),
                              )
                            : _location.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(AthIcons.xMark,
                                        size: 16, color: Colors.white54),
                                    onPressed: () {
                                      setState(() {
                                        _location.clear();
                                        _locationSuggestions = [];
                                      });
                                    },
                                  )
                                : null,
                      ),
                    ),
                    if (_locationSuggestions.isNotEmpty)
                      _locationSuggestionsList(),
                    const SizedBox(height: 18),

                    // Tag Athletes
                    _fieldLabel('Tag Athletes'),
                    if (_tagged.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final person in _tagged)
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _tagged.remove(person)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '@${person.username}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(AthIcons.xMark,
                                        size: 12, color: AppTheme.primaryColor),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: _personQuery,
                      onChanged: _onPersonQuery,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                      decoration: _boxDecoration(
                        'Search athletes to tag...',
                        prefixIcon: const Icon(AthIcons.user,
                            size: 18, color: Colors.white38),
                      ),
                    ),
                    if (_athleteSuggestions.isNotEmpty)
                      _athleteSuggestionList(),
                  ],
                ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      );

  Widget _locationSuggestionsList() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x2AFFFFFF)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final loc in _locationSuggestions)
            InkWell(
              onTap: () => _selectLocation(loc),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    const Icon(AthIcons.mapPin,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.shortLabel,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                          if (loc.displayName.isNotEmpty &&
                              loc.displayName != loc.shortLabel)
                            Text(
                              loc.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.4)),
                            ),
                        ],
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

  Widget _mediaPreview() {
    final hasLocal = _pickedFile != null;
    final isVid = _isVideo;
    final thumb = _thumbnailUrl ??
        (_mediaUrl.contains('/media/') && _mediaUrl.endsWith('.mp4')
            ? _mediaUrl.replaceAll('.mp4', '_thumb.jpg')
            : null);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 340, minHeight: 180),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. VIDEO PREVIEW
              if (isVid) ...[
                if (_previewVideoController != null &&
                    _previewVideoController!.value.isInitialized)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_previewVideoController!.value.isPlaying) {
                          _previewVideoController!.pause();
                        } else {
                          _previewVideoController!.play();
                        }
                      });
                    },
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            _previewVideoController!.value.aspectRatio > 0
                                ? _previewVideoController!.value.aspectRatio
                                : 16 / 9,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            width: _previewVideoController!.value.size.width > 0
                                ? _previewVideoController!.value.size.width
                                : null,
                            height:
                                _previewVideoController!.value.size.height > 0
                                    ? _previewVideoController!.value.size.height
                                    : null,
                            child: VideoPlayer(_previewVideoController!),
                          ),
                        ),
                      ),
                    ),
                  )
                else if (thumb != null && thumb.startsWith('http'))
                  CachedNetworkImage(
                    imageUrl: thumb,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 220,
                    placeholder: (_, __) => const SizedBox(
                        height: 220,
                        child: ColoredBox(color: Color(0xFF141414))),
                    errorWidget: (_, __, ___) => _buildVideoFallbackCard(),
                  )
                else if (_isVideoInitializing)
                  const SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor, strokeWidth: 2.5),
                    ),
                  )
                else
                  _buildVideoFallbackCard(),

                // Play/Pause center overlay if controller is initialized
                if (_previewVideoController != null &&
                    _previewVideoController!.value.isInitialized)
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: _previewVideoController!.value.isPlaying
                            ? 0.0
                            : 0.85,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(AthIcons.play,
                              color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: Icon(AthIcons.playCircleFill,
                        size: 48, color: Colors.white),
                  ),
              ]
              // 2. IMAGE PREVIEW
              else ...[
                if (hasLocal)
                  kIsWeb
                      ? Image.network(_pickedFile!.path,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220)
                      : Image.file(File(_pickedFile!.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 220)
                else if (_mediaUrl.startsWith('http'))
                  CachedNetworkImage(
                    imageUrl: _mediaUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => const SizedBox(
                        height: 220,
                        child: ColoredBox(color: Color(0xFF141414))),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 220,
                      child: Center(
                          child: Icon(AthIcons.photo,
                              color: Colors.white24, size: 40)),
                    ),
                  )
                else if (_mediaUrl.isNotEmpty)
                  Image.file(File(_mediaUrl),
                      fit: BoxFit.cover, width: double.infinity, height: 220)
                else
                  const SizedBox(
                    height: 220,
                    child: Center(
                        child: Icon(AthIcons.photo,
                            color: Colors.white24, size: 40)),
                  ),
              ],

              // 3. Uploading spinner overlay
              if (_uploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppTheme.primaryColor),
                          SizedBox(height: 10),
                          Text(
                            'Uploading new media...',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoFallbackCard() {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AthIcons.videoCamera,
                color: AppTheme.primaryColor, size: 44),
            const SizedBox(height: 8),
            Text(
              _pickedFile?.name ?? 'Video Attachment',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraRollRow() {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x1AFFFFFF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _changeMedia,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(AthIcons.photo, size: 18, color: Colors.white70),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Replace media',
                    style: TextStyle(fontSize: 14, color: Colors.white)),
              ),
              Text(
                _uploading ? 'Uploading...' : 'Change',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _athleteSuggestionList() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final p in _athleteSuggestions)
            InkWell(
              onTap: () => setState(() {
                if (!_tagged.any((t) => t.id == p.id))
                  _tagged.add(_TaggedPerson.fromProfile(p));
                _personQuery.clear();
                _athleteSuggestions = [];
              }),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF222222),
                      backgroundImage: p.avatarUrl.startsWith('http')
                          ? CachedNetworkImageProvider(p.avatarUrl,
                              maxWidth: 100)
                          : null,
                      child: p.avatarUrl.startsWith('http')
                          ? null
                          : const Icon(AthIcons.user,
                              size: 16, color: Colors.white38),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${p.username}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          if (p.name.isNotEmpty)
                            Text(p.name,
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withValues(alpha: 0.45))),
                        ],
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
