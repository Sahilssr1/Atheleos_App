import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sports_service.dart';
import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/events_controller.dart';
import '../../../../core/utils/user_facing_error.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: 'United States');
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _maxParticipantsController = TextEditingController(text: '100');
  final _entryFeeController = TextEditingController(text: '0.00');
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _websiteController = TextEditingController();
  final _externalUrlController = TextEditingController();

  final _ageGroupController = TextEditingController(text: 'All Ages');
  final _genderController = TextEditingController(text: 'All');
  final _skillLevelController = TextEditingController(text: 'Open');

  // Selected dropdown properties
  String _selectedSport = SportsService.supportedSports.first;
  String _selectedType = 'Tournament';
  String _selectedLevel = 'Open';
  String _selectedRegType = 'internal';
  String _selectedStatus = 'Upcoming';

  final List<String> _eventTypes = [
    'Tournament',
    'Trial',
    'Selection Camp',
    'Training Camp',
    'Workshop',
    'Coaching Clinic',
    'Open Practice',
    'Friendly Match',
    'League',
    'Championship',
    'Seminar',
    'Fitness Event',
    'Other'
  ];

  final List<String> _competitionLevels = [
    'District',
    'State',
    'National',
    'International',
    'School',
    'College',
    'University',
    'Professional',
    'Open'
  ];

  final List<String> _eventStatuses = [
    'Upcoming',
    'Registration Open',
    'Registration Closed',
    'Live',
    'Completed',
    'Cancelled'
  ];

  // Dates & Times
  DateTime? _startDate;
  TimeOfDay? _startTime;
  DateTime? _endDate;
  TimeOfDay? _endTime;
  DateTime? _deadline;

  // Media Banner Picking
  XFile? _bannerFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _success = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _maxParticipantsController.dispose();
    _entryFeeController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    _contactEmailController.dispose();
    _websiteController.dispose();
    _externalUrlController.dispose();
    _ageGroupController.dispose();
    _genderController.dispose();
    _skillLevelController.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() {
        _bannerFile = file;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart, bool isDeadline) async {
    final initialDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isDeadline) {
          _deadline = picked;
        } else if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final initialTime = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  // Cloudinary event banner thumbnail helper removed. R2 generated thumbnails are used directly.

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Event Start Date and Time.')),
      );
      return;
    }

    if (_endDate == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Event End Date and Time.')),
      );
      return;
    }

    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Registration Deadline Date.')),
      );
      return;
    }

    final userProfile = ref.read(activeProfileProvider).value;
    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile not loaded. Cannot publish event.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      String mediaUrl = '';
      String publicId = '';
      String thumbnailUrl = '';

      // Handle Cloudinary upload if a banner is picked
      if (_bannerFile != null) {
        Uint8List? bytes;
        String? filePath;

        if (kIsWeb) {
          bytes = await _bannerFile!.readAsBytes();
        } else {
          filePath = _bannerFile!.path;
        }

        final idempotencyKey = const Uuid().v4();
        final queue = ref.read(uploadQueueProvider.notifier);
        final taskId = await queue.addTask(
          bytes: bytes,
          filePath: filePath,
          fileName: _bannerFile!.name,
          ownerType: 'event',
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
            throw Exception(t.errorMessage ?? 'Banner upload failed');
          }
        }

        if (completedTask == null || completedTask.mediaId == null) {
          throw Exception('Banner task failed to return media ID');
        }

        publicId = completedTask.mediaId!;
        final doc = await FirebaseFirestore.instance.collection('media').doc(publicId).get();
        final urls = doc.data()?['urls'] as Map?;
        mediaUrl = urls?['original'] as String? ?? mediaUrl;
        thumbnailUrl = urls?['thumbnail'] as String? ?? mediaUrl;
      }

      final eventId = 'event_${DateTime.now().millisecondsSinceEpoch}';
      
      final startDateComplete = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final endDateComplete = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endTime!.hour,
        _endTime!.minute,
      );

      final event = EventModel(
        eventId: eventId,
        organizerUid: userProfile.id,
        organizerName: userProfile.name,
        organizerAvatar: userProfile.avatarUrl,
        verifiedOrganizer: userProfile.verified,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        sport: _selectedSport,
        eventType: _selectedType,
        bannerUrl: mediaUrl,
        bannerPublicId: publicId,
        bannerThumbnailUrl: thumbnailUrl,
        competitionLevel: _selectedLevel,
        registrationType: _selectedRegType,
        externalRegistrationUrl: _selectedRegType == 'external' ? _externalUrlController.text.trim() : null,
        eventStatus: _selectedStatus,
        venue: _venueController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        country: _countryController.text.trim(),
        latitude: double.tryParse(_latController.text),
        longitude: double.tryParse(_lngController.text),
        startDate: startDateComplete,
        endDate: endDateComplete,
        registrationDeadline: _deadline!,
        startTime: _formatTimeOfDay(_startTime),
        endTime: _formatTimeOfDay(_endTime),
        maxParticipants: int.tryParse(_maxParticipantsController.text) ?? 100,
        currentParticipants: 0,
        entryFee: double.tryParse(_entryFeeController.text) ?? 0.0,
        contactPerson: _contactPersonController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        contactEmail: _contactEmailController.text.trim(),
        officialWebsite: _websiteController.text.trim().isNotEmpty ? _websiteController.text.trim() : null,
        ageGroup: _ageGroupController.text.trim(),
        gender: _genderController.text.trim(),
        skillLevel: _skillLevelController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await ref.read(eventsRepositoryProvider).createEvent(event);
      
      // Invalidate events list stream provider to refresh the main screen list
      ref.invalidate(eventsStreamProvider);

      if (mounted) {
        setState(() {
          _isUploading = false;
          _success = true;
        });
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            context.pop();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to publish event. Please try again.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(activeProfileProvider).valueOrNull;
    final canCreate = userProfile != null && (
      userProfile.role == 'Coach' || 
      userProfile.role == 'Federation' || 
      userProfile.role == 'Brand'
    );

    if (!canCreate) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('HOST EVENT')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Only Coaches, Federations, and Brands are eligible to host events on ATHELEOS.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
      );
    }

    if (_success) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 80, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Event Published!',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Your sports event is now open for registration.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('HOST A NEW EVENT', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryColor),
                  SizedBox(height: 16),
                  Text('Uploading banner and publishing event...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Banner Picker ---
                    Text('Event Banner Cover',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickBanner,
                      child: Container(
                        width: double.infinity,
                        height: 160,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                          image: _bannerFile != null
                              ? DecorationImage(
                                  image: FileImage(File(_bannerFile!.path)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _bannerFile == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.image_outlined, size: 36, color: Colors.white38),
                                  const SizedBox(height: 8),
                                  Text('Select Banner Cover Image',
                                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                                ],
                              )
                            : Container(
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Edit Cover',
                                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- General Info Section ---
                    _buildSectionTitle('General Information'),
                    _buildTextField(
                      controller: _titleController,
                      label: 'Event Title',
                      hint: 'e.g. Texas Gridiron Elite Combine',
                      validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
                    ),

                    // Sport selection
                    Text('Sport (Mandatory)',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedSport,
                          dropdownColor: const Color(0xFF0F172A),
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(border: InputBorder.none),
                          items: SportsService.supportedSports.map((sport) {
                            return DropdownMenuItem<String>(
                              value: sport,
                              child: Text(sport),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() { _selectedSport = val; });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Grid details: Event Type & Competition Level
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Event Type',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedType,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    underline: const SizedBox(),
                                    items: _eventTypes.map((t) {
                                      return DropdownMenuItem<String>(value: t, child: Text(t));
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() { _selectedType = v; });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Competition Level',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedLevel,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    underline: const SizedBox(),
                                    items: _competitionLevels.map((l) {
                                      return DropdownMenuItem<String>(value: l, child: Text(l));
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() { _selectedLevel = v; });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description & Guidelines',
                      hint: 'Who can participate, Eligibility, Rules, required documents, Prize details, etc.',
                      maxLines: 6,
                      validator: (v) => v == null || v.isEmpty ? 'Description is required' : null,
                    ),

                    // --- Logistics (Venue & Coordinates) ---
                    _buildSectionTitle('Venue & Logistics'),
                    _buildTextField(
                      controller: _venueController,
                      label: 'Venue Address',
                      hint: 'e.g. AT&T Stadium, Gate 4 Entrance',
                      validator: (v) => v == null || v.isEmpty ? 'Venue address is required' : null,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            hint: 'e.g. Dallas',
                            validator: (v) => v == null || v.isEmpty ? 'City is required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'State',
                            hint: 'e.g. TX',
                            validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _countryController,
                            label: 'Country',
                            hint: 'e.g. United States',
                            validator: (v) => v == null || v.isEmpty ? 'Country is required' : null,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _latController,
                            label: 'Latitude (Optional)',
                            hint: 'e.g. 32.7473',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _lngController,
                            label: 'Longitude (Optional)',
                            hint: 'e.g. -97.0945',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    // --- Dates and Times ---
                    _buildSectionTitle('Event Schedule'),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Date',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _selectDate(context, true, false),
                                child: Text(_startDate == null ? 'Select Date' : '${_startDate!.month}/${_startDate!.day}/${_startDate!.year}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Time',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _selectTime(context, true),
                                child: Text(_startTime == null ? 'Select Time' : _formatTimeOfDay(_startTime)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Date',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _selectDate(context, false, false),
                                child: Text(_endDate == null ? 'Select Date' : '${_endDate!.month}/${_endDate!.day}/${_endDate!.year}'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End Time',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _selectTime(context, false),
                                child: Text(_endTime == null ? 'Select Time' : _formatTimeOfDay(_endTime)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- Registration & Limits ---
                    _buildSectionTitle('Registration Settings'),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registration Deadline',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  alignment: Alignment.centerLeft,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _selectDate(context, false, true),
                                child: Text(_deadline == null ? 'Select Date' : '${_deadline!.month}/${_deadline!.day}/${_deadline!.year}'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Registration Flow',
                                  style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedRegType,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF0F172A),
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    underline: const SizedBox(),
                                    items: const [
                                      DropdownMenuItem(value: 'internal', child: Text('Internal (Register inside ATHELEOS)')),
                                      DropdownMenuItem(value: 'external', child: Text('External Website registration')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() { _selectedRegType = v; });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_selectedRegType == 'external') ...[
                      _buildTextField(
                        controller: _externalUrlController,
                        label: 'Registration Website Link',
                        hint: 'https://mysportsplatform.com/events/texas-combine/register',
                        validator: (v) => _selectedRegType == 'external' && (v == null || v.isEmpty)
                            ? 'External registration link is required'
                            : null,
                      ),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _maxParticipantsController,
                            label: 'Maximum Participants Limit',
                            hint: '100',
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || int.tryParse(v) == null ? 'Must be a valid integer' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _entryFeeController,
                            label: 'Entry Fee amount (\$) (0 for Free)',
                            hint: '0.00',
                            keyboardType: TextInputType.number,
                            validator: (v) => v == null || double.tryParse(v) == null ? 'Must be a valid fee amount' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- Eligibility ---
                    _buildSectionTitle('Eligibility Requirements'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _ageGroupController,
                            label: 'Age Group Eligibility',
                            hint: 'e.g. Under 17, 18-22, etc.',
                            validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _genderController,
                            label: 'Gender Eligibility',
                            hint: 'e.g. Co-ed, Female Only, Male Only',
                            validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _skillLevelController,
                      label: 'Skill Level / Qualification Requirement',
                      hint: 'e.g. Open, Intermediate, Varsity, Division 1 prospects only',
                      validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
                    ),

                    // --- Event Status ---
                    _buildSectionTitle('Current Event Status'),
                    Text('Event Status Tag',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white60)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF0F172A),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          underline: const SizedBox(),
                          items: _eventStatuses.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() { _selectedStatus = v; });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Contact Information ---
                    _buildSectionTitle('Organizer Contact Information'),
                    _buildTextField(
                      controller: _contactPersonController,
                      label: 'Contact Person Name',
                      hint: 'e.g. Sarah Connor',
                      validator: (v) => v == null || v.isEmpty ? 'Contact person is required' : null,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _contactNumberController,
                            label: 'Contact Phone Number',
                            hint: '+1 (555) 123-4567',
                            validator: (v) => v == null || v.isEmpty ? 'Phone number is required' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _contactEmailController,
                            label: 'Contact Email',
                            hint: 'event@mysports.com',
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v == null || v.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      controller: _websiteController,
                      label: 'Official Website link (Optional)',
                      hint: 'https://lonestarcombine.com',
                    ),

                    const SizedBox(height: 32),

                    // Host Event Submit Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _handleSubmit,
                      child: Text(
                        'HOST SPORTS EVENT',
                        style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white12, height: 1),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: Colors.white24, fontSize: 12.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
