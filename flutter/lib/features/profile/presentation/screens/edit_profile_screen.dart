import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import '../controllers/profile_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _sportController;
  late TextEditingController _positionController;
  late TextEditingController _clubController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _dateOfBirthController;
  late TextEditingController _genderController;
  late TextEditingController _personalNotesController;
  late TextEditingController _achievementsController;
  late TextEditingController _certificationsController;
  late TextEditingController _websiteController;
  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _tiktokController;
  late TextEditingController _industryController;
  late TextEditingController _organizationNameController;

  // ── Statistics (mutable local copy, written to profile on save) ────────
  late List<StatEntry> _statistics;

  late double _height;
  late double _weight;
  String? _resumeFileName;

  // Image states for Cloudinary uploads
  late String _avatarUrl;
  late String _coverUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.name);
    _usernameController = TextEditingController(text: p.username);
    _bioController = TextEditingController(text: p.bio);
    _sportController = TextEditingController(text: p.sport);
    _positionController = TextEditingController(text: p.primaryPosition);
    _clubController = TextEditingController(text: p.clubOrAcademy);
    _cityController = TextEditingController(text: p.city);
    _stateController = TextEditingController(text: p.state);
    _countryController = TextEditingController(text: p.country);
    _dateOfBirthController = TextEditingController(text: p.dateOfBirth);
    _genderController = TextEditingController(text: p.gender);
    _personalNotesController = TextEditingController(text: p.personalNotes);
    _achievementsController =
        TextEditingController(text: p.achievements.join('\n'));
    _certificationsController =
        TextEditingController(text: p.certifications.join('\n'));
    _websiteController = TextEditingController(text: p.website);
    _instagramController =
        TextEditingController(text: p.socialLinks['Instagram'] ?? '');
    _twitterController =
        TextEditingController(text: p.socialLinks['Twitter'] ?? '');
    _tiktokController =
        TextEditingController(text: p.socialLinks['TikTok'] ?? '');
    _industryController = TextEditingController(text: p.industry ?? '');
    _organizationNameController =
        TextEditingController(text: p.organizationName ?? '');

    _height = p.height ?? 180.0;
    _weight = p.weight ?? 75.0;
    _resumeFileName = p.resumeFileName;
    _statistics = List<StatEntry>.from(p.statistics);

    // Load initial avatar and cover URLs
    _avatarUrl = p.avatarUrl;
    _coverUrl = p.coverUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _sportController.dispose();
    _positionController.dispose();
    _clubController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _dateOfBirthController.dispose();
    _genderController.dispose();
    _personalNotesController.dispose();
    _achievementsController.dispose();
    _certificationsController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _tiktokController.dispose();
    _industryController.dispose();
    _organizationNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage({required bool isAvatar}) async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      // Prepare file data based on platform (Web uses bytes, Native platforms use file path)
      final bytes = kIsWeb ? await image.readAsBytes() : null;
      final filePath = kIsWeb ? null : image.path;
      final fileName =
          '${widget.profile.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final idempotencyKey = const Uuid().v4();
      final queue = ref.read(uploadQueueProvider.notifier);
      final taskId = await queue.addTask(
        bytes: bytes,
        filePath: filePath,
        fileName: fileName,
        ownerType: 'profile',
        idempotencyKey: idempotencyKey,
      );

      UploadTask? completedTask;
      await for (final tasks in ref.read(uploadQueueProvider.notifier).stream) {
        final t = tasks.where((t) => t.id == taskId).firstOrNull;
        if (t == null) break;
        if (t.status == UploadStatus.completed) {
          completedTask = t;
          break;
        }
        if (t.status == UploadStatus.failed || t.status == UploadStatus.cancelled) {
          throw Exception(t.errorMessage ?? 'Upload failed');
        }
      }

      if (completedTask == null || completedTask.mediaId == null) {
        throw Exception('Profile photo task failed to return media ID');
      }

      final doc = await FirebaseFirestore.instance.collection('media').doc(completedTask.mediaId).get();
      final urls = doc.data()?['urls'] as Map?;
      final downloadUrl = urls?['original'] as String?;
      if (downloadUrl == null) {
        throw Exception('Profile image variant URL is missing.');
      }

      setState(() {
        if (isAvatar) {
          _avatarUrl = downloadUrl;
        } else {
          _coverUrl = downloadUrl;
        }
        _isUploadingImage = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isAvatar ? "Profile" : "Cover"} image uploaded successfully!'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      debugPrint('Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildImagesEditSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('PROFILE IMAGES'),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            // Cover Photo
            GestureDetector(
              onTap: () => _pickAndUploadImage(isAvatar: false),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(_coverUrl.isNotEmpty
                        ? _coverUrl
                        : 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?auto=format&fit=crop&q=80&w=800'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.photo_camera, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            // Avatar Photo
            Positioned(
              bottom: -30,
              left: 16,
              child: GestureDetector(
                onTap: () => _pickAndUploadImage(isAvatar: true),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundColor: const Color(0xFF1E293B),
                        backgroundImage: NetworkImage(_avatarUrl.isNotEmpty
                            ? _avatarUrl
                            : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200&h=200'),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 35),
        if (_isUploadingImage)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
                SizedBox(width: 10),
                Text('Uploading image to Firebase Storage...',
                    style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          ),
      ],
    );
  }

  void _saveProfile() {
    if (_isUploadingImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while images are uploading...'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final p = widget.profile;

      final Map<String, String> updatedSocials = {};
      if (_instagramController.text.trim().isNotEmpty) {
        updatedSocials['Instagram'] = _instagramController.text.trim();
      }
      if (_twitterController.text.trim().isNotEmpty) {
        updatedSocials['Twitter'] = _twitterController.text.trim();
      }
      if (_tiktokController.text.trim().isNotEmpty) {
        updatedSocials['TikTok'] = _tiktokController.text.trim();
      }

      final List<String> updatedAch = _achievementsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final List<String> updatedCert = _certificationsController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      final updatedProfile = p.copyWith(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim(),
        sport: _sportController.text.trim(),
        primaryPosition: _positionController.text.trim(),
        clubOrAcademy: _clubController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.trim(),
        gender: _genderController.text.trim(),
        personalNotes: _personalNotesController.text.trim(),
        avatarUrl: _avatarUrl,
        coverUrl: _coverUrl,
        achievements: updatedAch,
        certifications: updatedCert,
        website: _websiteController.text.trim(),
        socialLinks: updatedSocials,
        resumeFileName: _resumeFileName,
        height: _height,
        weight: _weight,
        industry: _industryController.text.trim(),
        organizationName: _organizationNameController.text.trim(),
        statistics: List<StatEntry>.from(_statistics), // persist stats
      );

      // 1. Update profileListProvider (in-memory + async Firestore write)
      ref.read(profileListProvider.notifier).updateProfile(updatedProfile);

      // 2. Immediately sync the UniversalProfileController that ProfileLoader
      //    watches, so the profile screen re-renders without a Firestore round-trip.
      ref
          .read(universalProfileControllerProvider(updatedProfile.id).notifier)
          .syncProfile(updatedProfile);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 8),
              Text('Profile updated successfully!',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppTheme.primaryColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _simulateResumeUpload() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPLOAD ATHLETIC RESUME',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a document to represent your athletic accomplishments and academic credentials.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 20),
              _buildFileOption('My_Athletic_Resume_2026.pdf'),
              _buildFileOption('Official_Academic_Transcript.pdf'),
              _buildFileOption('Tyler_Brooks_QB_Profile.pdf'),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.add, color: AppTheme.primaryColor),
                label: const Text('Add Custom File Name',
                    style: TextStyle(color: AppTheme.primaryColor)),
                onPressed: () {
                  Navigator.pop(context);
                  _showCustomFileDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileOption(String fileName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
        title: Text(fileName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: Colors.white30),
        onTap: () {
          setState(() {
            _resumeFileName = fileName;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── Statistics dialog ─────────────────────────────────────────────────

  /// Opens a bottom-sheet to add a new statistic or edit an existing one.
  /// Pass [existing] to pre-populate fields for editing.
  void _showStatisticDialog({StatEntry? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final valueController = TextEditingController(text: existing?.value ?? '');
    StatType selectedType = existing?.type ?? StatType.number;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bar_chart,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          existing == null ? 'ADD STATISTIC' : 'EDIT STATISTIC',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── Statistic Name ───────────────────────────────────
                    Text(
                      'STATISTIC NAME',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameController,
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'e.g. Wins, Bench Press, Ranking',
                        hintStyle: GoogleFonts.inter(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF262626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Statistic name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Type ─────────────────────────────────────────────
                    Text(
                      'TYPE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<StatType>(
                          value: selectedType,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF262626),
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 14),
                          items: StatType.values.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            );
                          }).toList(),
                          onChanged: (t) {
                            if (t != null) {
                              setSheet(() => selectedType = t);
                              // Clear value when type changes
                              valueController.clear();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Value ─────────────────────────────────────────────
                    Text(
                      'VALUE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: valueController,
                      keyboardType: selectedType == StatType.number
                          ? TextInputType.number
                          : selectedType == StatType.decimal
                              ? const TextInputType.numberWithOptions(
                                  decimal: true)
                              : TextInputType.text,
                      style:
                          GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: selectedType.valueHint,
                        hintStyle: GoogleFonts.inter(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF262626),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Value is required'
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // ── Save button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            final entry = StatEntry(
                              id: existing?.id ??
                                  DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                              name: nameController.text.trim(),
                              type: selectedType,
                              value: valueController.text.trim(),
                            );
                            setState(() {
                              if (existing == null) {
                                _statistics.add(entry);
                              } else {
                                final idx = _statistics
                                    .indexWhere((s) => s.id == entry.id);
                                if (idx != -1) _statistics[idx] = entry;
                              }
                            });
                            Navigator.pop(ctx);
                          }
                        },
                        child: Text(
                          existing == null ? 'ADD STATISTIC' : 'SAVE CHANGES',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomFileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'CUSTOM RESUME FILE',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppTheme.primaryColor,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'e.g. My_Custom_Resume.pdf',
              labelText: 'File Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('CANCEL', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    String name = controller.text.trim();
                    if (!name.endsWith('.pdf')) {
                      name += '.pdf';
                    }
                    _resumeFileName = name;
                  });
                }
                Navigator.pop(context);
              },
              child:
                  const Text('SELECT', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile.role;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'EDIT ${role.toUpperCase()} PROFILE',
          style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.check, color: AppTheme.primaryColor, size: 28),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section: Images Edit
                _buildImagesEditSection(),
                const SizedBox(height: 24),

                // Section: Basic Info
                _buildSectionHeader('BASIC IDENTITY'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Name cannot be empty'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameController,
                  readOnly: true,
                  onTap: () => context.push('/settings/username'),
                  decoration: const InputDecoration(
                      labelText: 'Username', prefixText: '@'),
                  validator: (val) => val == null || val.isEmpty
                      ? 'Username cannot be empty'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Specific Sports/Details depending on role
                if (role == 'Athlete' || role == 'Coach') ...[
                  _buildSectionHeader('ATHLETIC DETAILS'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sportController,
                          decoration: const InputDecoration(labelText: 'Sport'),
                          validator: (val) => val == null || val.isEmpty
                              ? 'Sport cannot be empty'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _positionController,
                          decoration: InputDecoration(
                            labelText: role == 'Athlete'
                                ? 'Primary Position'
                                : 'Coaching Title',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clubController,
                    decoration: InputDecoration(
                      labelText: role == 'Athlete'
                          ? 'Club or High School Team'
                          : 'Academy/Club Affiliation',
                    ),
                  ),
                ] else ...[
                  _buildSectionHeader('ORGANIZATION DETAILS'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _organizationNameController,
                    decoration:
                        const InputDecoration(labelText: 'Organization Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _industryController,
                    decoration: const InputDecoration(
                        labelText: 'Industry (e.g. Media, Apparel)'),
                  ),
                ],
                const SizedBox(height: 24),

                // Section: Location & Links
                _buildSectionHeader('LOCATION & CONTACT'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (val) => val == null || val.isEmpty
                            ? 'City is required'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                            labelText: 'State (2 Letter)'),
                        validator: (val) => val == null || val.isEmpty
                            ? 'State is required'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateOfBirthController,
                        decoration: const InputDecoration(
                            labelText: 'Date of Birth (YYYY-MM-DD)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _genderController,
                        decoration: const InputDecoration(labelText: 'Gender'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _personalNotesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Personal Notes',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website Link',
                    prefixIcon:
                        Icon(Icons.language, size: 20, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Social Links
                _buildSectionHeader('SOCIAL PLATFORMS'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram Username',
                    prefixIcon: Icon(Icons.camera_alt_outlined,
                        size: 20, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _twitterController,
                  decoration: const InputDecoration(
                    labelText: 'Twitter/X Username',
                    prefixIcon: Icon(Icons.alternate_email,
                        size: 20, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _tiktokController,
                  decoration: const InputDecoration(
                    labelText: 'TikTok Username',
                    prefixIcon: Icon(Icons.play_circle_outline,
                        size: 20, color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 24),

                // Section: Lists (Achievements / Certifications)
                if (role == 'Athlete' ||
                    role == 'Coach' ||
                    role == 'Brand' ||
                    role == 'Federation') ...[
                  _buildSectionHeader(role == 'Coach'
                      ? 'ACCOLADES & MILESTONES'
                      : 'ACHIEVEMENTS / MILESTONES'),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter each milestone on a new line.',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _achievementsController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Achievements',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                if (role == 'Coach') ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('PROFESSIONAL CERTIFICATIONS'),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter each certification on a new line.',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _certificationsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Certifications',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Section: Resume Upload for Athletes
                if (role == 'Athlete') ...[
                  _buildSectionHeader('ATHLETIC RESUME DOCUMENT'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _simulateResumeUpload,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        border: Border.all(
                          color: _resumeFileName != null
                              ? AppTheme.primaryColor.withOpacity(0.4)
                              : Colors.white10,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _resumeFileName != null
                                ? Icons.document_scanner
                                : Icons.cloud_upload_outlined,
                            size: 44,
                            color: _resumeFileName != null
                                ? AppTheme.primaryColor
                                : Colors.white30,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _resumeFileName ??
                                'Drag and drop or click to upload PDF resume',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: _resumeFileName != null
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: _resumeFileName != null
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_resumeFileName != null) ...[
                            const SizedBox(height: 8),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: AppTheme.primaryColor, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Ready to Save',
                                  style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Section: Private Data (Only Athlete & Coach)
                if (role == 'Athlete' || role == 'Coach') ...[
                  _buildPrivateDataHeader(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Athlete Height',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${_height.round()} cm (${(_height / 30.48).floor()}\'${((_height % 30.48) / 2.54).round()}\")',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _height,
                          min: 140.0,
                          max: 220.0,
                          activeColor: AppTheme.primaryColor,
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setState(() {
                              _height = val;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Athlete Weight',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${_weight.round()} kg (${(_weight * 2.20462).round()} lbs)',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _weight,
                          min: 40.0,
                          max: 150.0,
                          activeColor: AppTheme.primaryColor,
                          inactiveColor: Colors.white12,
                          onChanged: (val) {
                            setState(() {
                              _weight = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Section: Statistics
                _buildSectionHeader('ATHLETE STATISTICS'),
                const SizedBox(height: 4),
                const Text(
                  'Add custom stats for your sport — unlimited, any type.',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 12),
                _buildStatisticsSection(),
                const SizedBox(height: 24),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    onPressed: _saveProfile,
                    child: Text(
                      'SAVE CHANGES',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Statistics list widget ─────────────────────────────────────────────────

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reorderable list of existing stats
        if (_statistics.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _statistics.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _statistics.removeAt(oldIndex);
                  _statistics.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final stat = _statistics[i];
                return _buildStatRow(stat, i, key: ValueKey(stat.id));
              },
            ),
          ),

        const SizedBox(height: 12),

        // Add Statistic button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle_outline,
                color: AppTheme.primaryColor, size: 18),
            label: Text(
              'ADD STATISTIC',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 13,
                color: AppTheme.primaryColor,
              ),
            ),
            onPressed: () => _showStatisticDialog(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(StatEntry stat, int index, {required Key key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: index == 0
            ? null
            : const Border(top: BorderSide(color: Color(0xFF222222))),
      ),
      child: Row(
        children: [
          // Drag handle
          const Icon(Icons.drag_handle, color: Colors.white24, size: 20),
          const SizedBox(width: 12),

          // Type chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stat.type.label.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Name + Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                Text(
                  stat.displayValue,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: Colors.white38, size: 18),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            onPressed: () => _showStatisticDialog(existing: stat),
          ),

          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 18),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            onPressed: () {
              setState(() {
                _statistics.removeWhere((s) => s.id == stat.id);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.bold,
        fontSize: 12,
        color: AppTheme.primaryColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildPrivateDataHeader() {
    return Row(
      children: [
        const Icon(Icons.lock_outline, color: AppTheme.primaryColor, size: 16),
        const SizedBox(width: 8),
        Text(
          'SECURE PRIVATE DATA',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppTheme.primaryColor,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'OWNER ONLY',
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 8,
                fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}
