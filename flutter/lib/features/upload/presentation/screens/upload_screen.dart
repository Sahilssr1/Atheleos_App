import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sports_service.dart';
import '../../../../core/services/location_service.dart';
import '../../../../core/widgets/mention_autocomplete_overlay.dart';
import '../../../../core/widgets/sport_selector_field.dart';
import '../../../feed/domain/models/post_model.dart';
import '../../../../core/widgets/ath_icons.dart';
import '../controllers/post_upload_controller.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final TextEditingController _contentController = TextEditingController();
  final FocusNode _contentFocusNode = FocusNode();

  String _selectedSportCategory = 'All';
  late String _selectedSport;

  PostCategory _selectedCategory = PostCategory.general;

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
  VideoPlayerController? _videoPlayerController;
  bool _isVideoInitializing = false;

  void _disposeVideoController() {
    try {
      _videoPlayerController?.pause();
      _videoPlayerController?.dispose();
    } catch (_) {}
    _videoPlayerController = null;
    _isVideoInitializing = false;
  }

  void _clearMedia() {
    _disposeVideoController();
    setState(() {
      _pickedFile = null;
      _isVideo = false;
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  final TextEditingController _locationController = TextEditingController();
  List<LocationResult> _locationSuggestions = [];
  bool _isSearchingLocation = false;
  Timer? _locationDebounce;

  @override
  void initState() {
    super.initState();
    final sports = SportsService.getSports();
    _selectedSport = sports.isNotEmpty ? sports.first : 'Athletics (Track & Field)';
    // Pre-fetch live backend sports hierarchy asynchronously
    SportsService.loadFromBackend().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _disposeVideoController();
    _contentController.dispose();
    _contentFocusNode.dispose();
    _locationController.dispose();
    _locationDebounce?.cancel();
    super.dispose();
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
        if (!mounted || _locationController.text.trim() != q) return;
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
      _locationController.text = item.shortLabel;
      _locationSuggestions = [];
      _isSearchingLocation = false;
    });
    FocusScope.of(context).unfocus();
  }

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
                content: Text('Video exceeds the 250MB limit. Please select a shorter clip.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        _disposeVideoController();
        setState(() {
          _pickedFile = file;
          _isVideo = true;
          _isVideoInitializing = true;
        });

        try {
          final controller = kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(file.path))
              : VideoPlayerController.file(File(file.path));
          await controller.initialize();
          await controller.setLooping(true);
          await controller.setVolume(0.0);
          await controller.play();

          if (!mounted) {
            controller.dispose();
            return;
          }
          setState(() {
            _videoPlayerController = controller;
            _isVideoInitializing = false;
          });
        } catch (e) {
          debugPrint('Failed to initialize video preview: $e');
          if (mounted) {
            setState(() {
              _isVideoInitializing = false;
            });
          }
        }
      } else {
        _disposeVideoController();
        setState(() {
          _pickedFile = file;
          _isVideo = false;
        });
      }
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
              leading: const Icon(AthIcons.photo, color: AppTheme.primaryColor),
              title: Text('Choose Photo', style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickMedia(false); },
            ),
            ListTile(
              leading: const Icon(AthIcons.videoCamera, color: AppTheme.primaryColor),
              title: Text('Choose Video', style: GoogleFonts.outfit(color: Colors.white)),
              onTap: () { Navigator.pop(context); _pickMedia(true); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handlePublish() {
    final caption = _contentController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a caption first.')),
      );
      return;
    }

    final category = _selectedCategory;
    final sport = _selectedSport;
    final location = _locationController.text.trim().isEmpty ? null : _locationController.text.trim();
    final pickedFile = _pickedFile;
    final isVideo = _isVideo;

    // Launch background upload coordinator immediately
    ref.read(postUploadProvider.notifier).startUpload(
      caption: caption,
      category: category,
      sport: sport,
      location: location,
      pickedFile: pickedFile,
      isVideo: isVideo,
    );

    // Clear and dispose local preview controller
    _disposeVideoController();
    _contentController.clear();
    _locationController.clear();
    _locationSuggestions = [];
    setState(() {
      _pickedFile = null;
      _isVideo = false;
    });

    // Notify user with feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(AthIcons.cloudArrowUp, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Publishing highlight in background...',
                style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // Transition smoothly back to home feed without blocking the user
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sportCategories = ['All', ...SportsService.getCategories()];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Create Highlight',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _handlePublish,
            child: Text('Publish',
                style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sport Category Filter Chips (from Backend hierarchy)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sport Category',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60),
                ),
                Text(
                  'From Atheleos catalog',
                  style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sportCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final cat = sportCategories[idx];
                  final isSelected = _selectedSportCategory == cat;
                  return ChoiceChip(
                    showCheckmark: false,
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedSportCategory = cat;
                          if (cat != 'All') {
                            final sports = SportsService.getSportsForCategory(cat);
                            if (sports.isNotEmpty && !sports.contains(_selectedSport)) {
                              _selectedSport = sports.first;
                            }
                          }
                        });
                      }
                    },
                    selectedColor: AppTheme.primaryColor,
                    backgroundColor: const Color(0xFF141414),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryColor : const Color(0xFF262626),
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2. Select Specific Sport
            Text('Sport',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SportSelectorField(
                key: ValueKey('sport_${_selectedSportCategory}_$_selectedSport'),
                initialSport: _selectedSport,
                hintText: 'Search or Select Sport',
                onSportChanged: (val) {
                  setState(() {
                    _selectedSport = val.isEmpty ? SportsService.getSports().first : val;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // 3. Caption
            Text('Caption',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            MentionAutocompleteOverlay(
              controller: _contentController,
              focusNode: _contentFocusNode,
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                maxLines: 4,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Share your training, match highlight, or achievement...',
                  hintStyle: GoogleFonts.outfit(color: Colors.white24),
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

            // 4. Activity Tag
            Text('Activity Tag',
                style: GoogleFonts.outfit(
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
                  onSelected: (selected) {
                    setState(() { _selectedCategory = cat; });
                  },
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: const Color(0xFF141414),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryColor : const Color(0xFF262626),
                  ),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 5. Location (Optional) with live OpenStreetMap autocomplete
            Text('Location (Optional)',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              onChanged: _onLocationQuery,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter city or location (e.g. Mumbai, Dallas)...',
                hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 13),
                prefixIcon: const Icon(AthIcons.mapPin, size: 18, color: AppTheme.primaryColor),
                suffixIcon: _isSearchingLocation
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                        ),
                      )
                    : _locationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(AthIcons.xMark, size: 16, color: Colors.white54),
                            onPressed: () {
                              setState(() {
                                _locationController.clear();
                                _locationSuggestions = [];
                              });
                            },
                          )
                        : null,
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
            if (_locationSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x2AFFFFFF)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final loc in _locationSuggestions)
                      InkWell(
                        onTap: () => _selectLocation(loc),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            children: [
                              const Icon(AthIcons.mapPin, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc.shortLabel,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                    if (loc.displayName.isNotEmpty && loc.displayName != loc.shortLabel)
                                      Text(
                                        loc.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
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
              ),
            const SizedBox(height: 20),

            // 6. Media Picker
            Text('Media (Optional)',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
            const SizedBox(height: 8),
            _buildMediaPreview(),

            const SizedBox(height: 28),

            // 7. Publish button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _handlePublish,
                child: Text('PUBLISH HIGHLIGHT',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_pickedFile == null) {
      return GestureDetector(
        onTap: _showMediaPicker,
        child: Container(
          width: double.infinity,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF262626), width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AthIcons.cloudArrowUp, size: 28, color: AppTheme.primaryColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to pick a photo or video',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploads directly in background to Cloudflare R2',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333), width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Content Preview
          if (_isVideo)
            if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380, minHeight: 220),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio > 0
                        ? _videoPlayerController!.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                ),
              )
            else if (_isVideoInitializing)
              Container(
                height: 220,
                color: const Color(0xFF141414),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2.5),
                      SizedBox(height: 12),
                      Text('Loading video preview...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 220,
                color: const Color(0xFF141414),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AthIcons.videoCamera, color: AppTheme.primaryColor, size: 40),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _pickedFile!.name,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380, minHeight: 200),
              child: kIsWeb
                  ? Image.network(_pickedFile!.path, fit: BoxFit.contain, width: double.infinity)
                  : Image.file(File(_pickedFile!.path), fit: BoxFit.contain, width: double.infinity),
            ),

          // Play/Pause tap overlay for video
          if (_isVideo && _videoPlayerController != null && _videoPlayerController!.value.isInitialized)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    if (_videoPlayerController!.value.isPlaying) {
                      _videoPlayerController!.pause();
                    } else {
                      _videoPlayerController!.play();
                    }
                  });
                },
                child: Container(
                  color: Colors.transparent,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _videoPlayerController!.value.isPlaying ? 0.0 : 0.85,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(AthIcons.play, color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Media Type Badge (Bottom Left)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isVideo ? AthIcons.videoCamera : AthIcons.photo,
                    size: 13,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isVideo
                        ? (_videoPlayerController != null && _videoPlayerController!.value.isInitialized
                            ? 'VIDEO • ${_formatDuration(_videoPlayerController!.value.duration)}'
                            : 'VIDEO')
                        : 'PHOTO',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons: Change & Remove (Top Right)
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _showMediaPicker,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AthIcons.arrowPath, size: 12, color: AppTheme.primaryColor),
                        const SizedBox(width: 5),
                        Text(
                          'Change',
                          style: GoogleFonts.outfit(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _clearMedia,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 0.8),
                    ),
                    child: const Icon(AthIcons.xMark, size: 14, color: Colors.redAccent),
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
