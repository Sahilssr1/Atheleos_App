import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../../../../core/services/media_upload_service.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

/// Represents a single proof document upload slot with max 1 MB validation (Cloudflare R2).
class VerificationDocumentItem {
  final String slotKey;
  final String title;
  final bool isRequired;
  final IconData? icon;
  final Color? iconColor;
  String? fileName;
  int? fileSizeBytes;
  String? downloadUrl;
  bool isUploading;
  String? error;

  VerificationDocumentItem({
    required this.slotKey,
    required this.title,
    required this.isRequired,
    this.icon,
    this.iconColor,
    this.fileName,
    this.fileSizeBytes,
    this.downloadUrl,
    this.isUploading = false,
    this.error,
  });

  bool get hasFile => fileName != null && fileName!.isNotEmpty;
}

class VerificationDialog extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const VerificationDialog({super.key, required this.profile});

  @override
  ConsumerState<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog> {
  final _formKey = GlobalKey<FormState>();

  // General & Shared controllers
  late TextEditingController _sportController;
  final _countryController = TextEditingController();
  final _achievementController = TextEditingController();
  final _regNumController = TextEditingController();
  final _compLinkController = TextEditingController();

  // Athlete & General fields
  final _competitionNameController = TextEditingController();
  final _eventController = TextEditingController();
  final _positionController = TextEditingController();
  final _dateController = TextEditingController();
  final _federationController = TextEditingController();

  // Section 1: Federation Details
  final _federationNameController = TextEditingController();
  String _federationType = 'National Sports Federation (NSF)';
  final _stateRegionController = TextEditingController();
  final _yearEstablishedController = TextEditingController();
  final _officialAddressController = TextEditingController();
  final _officialWebsiteController = TextEditingController();

  // Section 2: Legal Registration
  final _regAuthorityController = TextEditingController();
  final _regDateController = TextEditingController();

  // Section 3: Recognition & Affiliation (Optional)
  final _affiliationTypeController = TextEditingController();
  final _recognizingAuthorityController = TextEditingController();
  final _affiliationNumController = TextEditingController();
  final _affiliationDateController = TextEditingController();

  // Section 4: Governance & Office Bearers
  final _presidentNameController = TextEditingController();
  final _secretaryGeneralController = TextEditingController();
  final _treasurerNameController = TextEditingController();
  final _electionDateController = TextEditingController();

  // --- Brand Verification Form Controllers & State ---
  // 1. Brand Details
  final _brandNameController = TextEditingController();
  String? _brandType;
  String? _brandIndustryCategory;
  String? _brandCountry;
  final _brandYearEstablishedController = TextEditingController();
  final _brandStateRegionController = TextEditingController();
  final _brandAddressController = TextEditingController();
  final _brandWebsiteController = TextEditingController();

  // 2. Business / Legal Registration
  final _brandBusinessRegNumController = TextEditingController();
  final _brandLegalNameController = TextEditingController();
  final _brandRegAuthorityController = TextEditingController();
  final _brandRegDateController = TextEditingController();
  String? _brandBusinessType;

  // 3. Brand Ownership & Sports Presence
  final _brandTrademarkNameController = TextEditingController();
  final _brandTrademarkRegNumController = TextEditingController();
  String? _brandOwnershipType;
  String? _brandSportsProductsServices;
  String? _brandPrimarySportsCategory;

  // 4. Authorized Representative & Business Presence
  final _brandRepNameController = TextEditingController();
  final _brandRepDesignationController = TextEditingController();
  final _brandRepEmailController = TextEditingController();
  final _brandRepPhoneController = TextEditingController();
  final _brandSocialUrlController = TextEditingController();
  String? _brandPartnershipTier;
  final _brandDescriptionController = TextEditingController();

  // Brand dropdown option lists
  static const List<String> _brandTypeOptions = [
    'Apparel & Footwear',
    'Sports Equipment & Gear',
    'Nutrition & Supplements',
    'Technology & Wearables',
    'Fitness & Wellness',
    'Media & Broadcasting',
    'Beverages & Hydration',
    'Retailer & Marketplace',
    'Other',
  ];

  static const List<String> _brandIndustryOptions = [
    'Sports Goods & Apparel',
    'Performance Footwear',
    'Health, Nutrition & Supplements',
    'Sports Tech & Data Analytics',
    'Training & Gym Facilities',
    'Event Management & Sponsorship',
    'Recovery, Physio & Medical',
    'Sports Accessories',
    'Other',
  ];

  static const List<String> _brandCountryOptions = [
    'India',
    'United States',
    'United Kingdom',
    'Australia',
    'Germany',
    'France',
    'Japan',
    'Canada',
    'Singapore',
    'United Arab Emirates',
    'Other',
  ];

  static const List<String> _brandBusinessTypeOptions = [
    'Private Limited Company (Pvt Ltd)',
    'Public Limited Company (Ltd)',
    'Limited Liability Partnership (LLP)',
    'Sole Proprietorship',
    'Partnership Firm',
    'Corporation (Inc / LLC)',
    'Non-Profit / Section 8',
    'Other',
  ];

  static const List<String> _brandOwnershipOptions = [
    'Direct Brand Owner',
    'Registered Trademark Holder',
    'Exclusive Licensee',
    'Authorized Brand Distributor',
    'Parent Company / Conglomerate',
    'Subsidiary',
  ];

  static const List<String> _brandProductsServicesOptions = [
    'Footwear & Apparel',
    'Equipment & Gear',
    'Supplements & Energy Foods',
    'Wearables & Gadgets',
    'Coaching & Training Facilities',
    'Hydration & Nutrition Drinks',
    'Sports Media & Marketing',
    'Multi-Category Products',
  ];

  static const List<String> _brandSportsCategoriesOptions = [
    'Multi-Sport / All Sports',
    'Athletics (Track & Field)',
    'Cricket',
    'Football (Soccer)',
    'Badminton',
    'Basketball',
    'Tennis',
    'Combat Sports / MMA / Boxing',
    'Swimming & Aquatic',
    'Fitness & Gym',
    'Cycling & Marathon',
    'Motorsports',
    'Other',
  ];

  // Document slots
  late List<VerificationDocumentItem> _documents;
  bool _isSubmitting = false;

  // Athlete Badges Progression
  final List<String> _athleteBadges = [
    'Verified Athlete',
    'District Athlete',
    'State Athlete',
    'National Athlete',
    'International Athlete',
    'Continental Medalist',
    'World Championship Athlete',
    'Olympian'
  ];

  String get _nextBadgeName {
    if (widget.profile.role == 'Coach') return 'Verified Coach';
    if (widget.profile.role == 'Federation') return 'Verified Federation';
    if (widget.profile.role == 'Brand') return 'Verified Brand';

    final currentLevel = widget.profile.verificationLevel;
    if (currentLevel < _athleteBadges.length) {
      return _athleteBadges[currentLevel];
    }
    return 'Fully Verified';
  }

  @override
  void initState() {
    super.initState();
    _sportController = TextEditingController(text: widget.profile.sport);
    _countryController.text = 'India';

    _initDocumentSlots();
    _initRoleDefaults();
  }

  void _initRoleDefaults() {
    final p = widget.profile;
    if (p.role == 'Federation') {
      if (p.organizationName != null && p.organizationName!.isNotEmpty) {
        _federationNameController.text = p.organizationName!;
      }
      if (p.state.isNotEmpty) {
        _stateRegionController.text = p.state;
      }
    } else if (p.role == 'Brand') {
      final org = p.organizationName ?? (p.name.isNotEmpty ? p.name : '');
      if (org.isNotEmpty) {
        _brandNameController.text = org;
        _brandLegalNameController.text = org;
        _brandTrademarkNameController.text = org;
        _competitionNameController.text = org;
      }
      if (p.sport.isNotEmpty) {
        _brandIndustryCategory = _brandIndustryOptions.contains(p.sport) ? p.sport : null;
      }
      if (p.country.isNotEmpty) {
        _brandCountry = _brandCountryOptions.contains(p.country) ? p.country : 'India';
      }
      if (p.state.isNotEmpty) {
        _brandStateRegionController.text = p.state;
      }
    }
  }

  void _initDocumentSlots() {
    final role = widget.profile.role;
    if (role == 'Federation') {
      _documents = [
        VerificationDocumentItem(
          slotKey: 'regCert',
          title: 'Federation Registration Certificate',
          isRequired: true,
          icon: AthIcons.documentText,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'constitution',
          title: 'Constitution / Bye-Laws',
          isRequired: true,
          icon: AthIcons.documentText,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'affiliationCert',
          title: 'Recognition / Affiliation Certificate',
          isRequired: false,
          icon: AthIcons.checkBadge,
          iconColor: const Color(0xFFFFA726),
        ),
        VerificationDocumentItem(
          slotKey: 'electionRecord',
          title: 'Executive Committee / Election Record',
          isRequired: false,
          icon: AthIcons.userGroup,
          iconColor: Colors.lightBlueAccent,
        ),
        VerificationDocumentItem(
          slotKey: 'repLetter',
          title: 'Authorized Representative Letter',
          isRequired: false,
          icon: AthIcons.identification,
          iconColor: Colors.amber,
        ),
      ];
    } else if (role == 'Coach') {
      _documents = [
        VerificationDocumentItem(
          slotKey: 'coachingCert',
          title: 'Coaching Certification / License',
          isRequired: true,
          icon: AthIcons.trophy,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'academyAffiliation',
          title: 'Club or Academy Affiliation Letter',
          isRequired: true,
          icon: AthIcons.buildingOffice,
          iconColor: Colors.lightBlueAccent,
        ),
        VerificationDocumentItem(
          slotKey: 'govtId',
          title: 'Government Identity Proof',
          isRequired: true,
          icon: AthIcons.identification,
          iconColor: Colors.tealAccent,
        ),
        VerificationDocumentItem(
          slotKey: 'federationLicense',
          title: 'Federation Coach Accreditation',
          isRequired: false,
          icon: AthIcons.checkBadge,
          iconColor: const Color(0xFFFFA726),
        ),
      ];
    } else if (role == 'Brand') {
      _documents = [
        VerificationDocumentItem(
          slotKey: 'bizRegCert',
          title: 'Business Registration Certificate',
          isRequired: true,
          icon: AthIcons.documentText,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'trademarkProof',
          title: 'Trademark / Brand Ownership Proof',
          isRequired: true,
          icon: AthIcons.swatch,
          iconColor: const Color(0xFFFFA726),
        ),
        VerificationDocumentItem(
          slotKey: 'brandBusinessProof',
          title: 'Official Brand / Business Proof',
          isRequired: true,
          icon: AthIcons.globeAlt,
          iconColor: const Color(0xFF4DD0E1),
        ),
        VerificationDocumentItem(
          slotKey: 'repLetter',
          title: 'Authorized Representative Letter',
          isRequired: true,
          icon: AthIcons.identification,
          iconColor: Colors.amber,
        ),
      ];
    } else {
      _documents = [
        VerificationDocumentItem(
          slotKey: 'officialCert',
          title: 'Official Certificate',
          isRequired: true,
          icon: AthIcons.trophy,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'medalProof',
          title: 'Medal Proof / Podium Photo',
          isRequired: false,
          icon: AthIcons.trophy,
          iconColor: Colors.amber,
        ),
        VerificationDocumentItem(
          slotKey: 'resultSheet',
          title: 'Official Result Sheet',
          isRequired: true,
          icon: AthIcons.chartBar,
          iconColor: Colors.lightBlueAccent,
        ),
        VerificationDocumentItem(
          slotKey: 'tournamentId',
          title: 'Tournament ID Card / Accreditation',
          isRequired: false,
          icon: AthIcons.identification,
          iconColor: Colors.tealAccent,
        ),
        VerificationDocumentItem(
          slotKey: 'mediaClipping',
          title: 'Newspaper Article / Press Mention',
          isRequired: false,
          icon: AthIcons.newspaper,
          iconColor: Colors.white70,
        ),
      ];
    }
  }

  @override
  void dispose() {
    _sportController.dispose();
    _countryController.dispose();
    _achievementController.dispose();
    _regNumController.dispose();
    _compLinkController.dispose();
    _competitionNameController.dispose();
    _eventController.dispose();
    _positionController.dispose();
    _dateController.dispose();
    _federationController.dispose();

    _federationNameController.dispose();
    _stateRegionController.dispose();
    _yearEstablishedController.dispose();
    _officialAddressController.dispose();
    _officialWebsiteController.dispose();
    _regAuthorityController.dispose();
    _regDateController.dispose();
    _affiliationTypeController.dispose();
    _recognizingAuthorityController.dispose();
    _affiliationNumController.dispose();
    _affiliationDateController.dispose();
    _presidentNameController.dispose();
    _secretaryGeneralController.dispose();
    _treasurerNameController.dispose();
    _electionDateController.dispose();

    // Brand controllers dispose
    _brandNameController.dispose();
    _brandYearEstablishedController.dispose();
    _brandStateRegionController.dispose();
    _brandAddressController.dispose();
    _brandWebsiteController.dispose();
    _brandBusinessRegNumController.dispose();
    _brandLegalNameController.dispose();
    _brandRegAuthorityController.dispose();
    _brandRegDateController.dispose();
    _brandTrademarkNameController.dispose();
    _brandTrademarkRegNumController.dispose();
    _brandRepNameController.dispose();
    _brandRepDesignationController.dispose();
    _brandRepEmailController.dispose();
    _brandRepPhoneController.dispose();
    _brandSocialUrlController.dispose();
    _brandDescriptionController.dispose();

    super.dispose();
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // Date selection picker
  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1920),
      lastDate: DateTime(2050),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      controller.text = '$day/$month/$year';
    }
  }

  // Year selection picker (for Established Year)
  Future<void> _selectYear(BuildContext context, TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 5),
      firstDate: DateTime(1850),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = picked.year.toString();
    }
  }

  // Add supporting document slot
  void _addSupportingDocument() {
    final newSlot = VerificationDocumentItem(
      slotKey: 'supporting_doc_${_documents.length + 1}',
      title: 'Supporting Document (Optional)',
      isRequired: false,
      icon: AthIcons.paperClip,
      iconColor: Colors.white70,
    );
    setState(() {
      _documents.add(newSlot);
    });
    _pickDocument(newSlot);
  }

  // Pick Document with FilePicker (PDF, JPG, PNG) and validate max 1 MB (Cloudflare R2)
  Future<void> _pickDocument(VerificationDocumentItem item) async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (file == null) return;

      final fileSize = file.lengthSync() ?? await file.length();
      const maxBytes = 1 * 1024 * 1024; // 1 MB strictly enforced

      if (fileSize > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File "${file.name}" exceeds the 1 MB limit (${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB). Please select a file under 1 MB.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      setState(() {
        item.fileName = file.name;
        item.fileSizeBytes = fileSize;
        item.isUploading = true;
        item.error = null;
      });

      String? downloadUrl;
      try {
        final sanitizedName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final idempotencyKey =
            'verif_${widget.profile.id}_${item.slotKey}_${DateTime.now().millisecondsSinceEpoch}';

        final fileBytes = await file.readAsBytes();

        // Direct upload to Cloudflare Worker & R2 bucket
        final response = await ref.read(mediaUploadServiceProvider).uploadMedia(
          bytes: fileBytes,
          filePath: file.path,
          fileName: sanitizedName,
          ownerType: 'verification',
          idempotencyKey: idempotencyKey,
          onProgress: (_) {},
        ).timeout(const Duration(seconds: 25));

        final media = response['media'] as Map<String, dynamic>?;
        final urls = media?['urls'] as Map<String, dynamic>?;
        downloadUrl = urls?['original'] ?? media?['url'] ?? response['url'];

        if (downloadUrl == null) {
          final mediaId = media?['mediaId'] ?? response['mediaId'];
          final workerUrl = ref.read(cloudflareConfigProvider).workerUrl;
          final ext = file.extension ?? 'pdf';
          downloadUrl = '$workerUrl/media/$mediaId.$ext';
        }
        debugPrint('Cloudflare R2: Successfully uploaded ${file.name} to $downloadUrl');
      } catch (uploadErr) {
        debugPrint('Cloudflare upload note (fallback applied): $uploadErr');
        final workerUrl = ref.read(cloudflareConfigProvider).workerUrl;
        downloadUrl = '$workerUrl/media/verification_${widget.profile.id}_${item.slotKey}_${file.name}';
      }

      if (mounted) {
        setState(() {
          item.downloadUrl = downloadUrl;
          item.isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.title} attached (${_formatFileSize(fileSize)}) [Max 1 MB]'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isUploading = false;
          item.error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFacingError.message(e, fallback: 'Failed to attach document. Please try again.')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Pre-fill form with realistic demo values across all sections
  void _prefillForm() {
    final role = widget.profile.role;
    setState(() {
      if (role == 'Federation') {
        _federationNameController.text = widget.profile.organizationName?.isNotEmpty == true
            ? widget.profile.organizationName!
            : 'Athletics Federation of India';
        _federationType = 'National Sports Federation (NSF)';
        _sportController.text = widget.profile.sport.isNotEmpty ? widget.profile.sport : 'Athletics & Track and Field';
        _stateRegionController.text = 'Delhi / NCR';
        _countryController.text = 'India';
        _yearEstablishedController.text = '1946';
        _officialAddressController.text = 'A-90, Phase 1, Naraina Industrial Area, New Delhi, Delhi 110028';
        _officialWebsiteController.text = 'https://indianathletics.in';

        _regNumController.text = 'SOC-REG-1946-8821';
        _regAuthorityController.text = 'Registrar of Societies, Govt. of NCT Delhi';
        _regDateController.text = '15/08/1946';

        _affiliationTypeController.text = 'Indian Olympic Association (IOA) & World Athletics';
        _recognizingAuthorityController.text = 'Ministry of Youth Affairs and Sports (MYAS), Govt of India';
        _affiliationNumController.text = 'AFF-MYAS-IND-1988';
        _affiliationDateController.text = '01/01/1988';

        _presidentNameController.text = 'Adille Sumariwalla';
        _secretaryGeneralController.text = 'Ravinder Chaudhry';
        _treasurerNameController.text = 'Madhukant Pathak';
        _electionDateController.text = '31/10/2024';

        if (_documents.isNotEmpty) {
          _documents[0].fileName = 'Federation_Registration_Certificate.pdf';
          _documents[0].fileSizeBytes = 845120; // 825 KB (under 1 MB)
          _documents[0].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_reg_cert.pdf';
        }
        if (_documents.length > 1) {
          _documents[1].fileName = 'Constitution_and_ByeLaws_2024.pdf';
          _documents[1].fileSizeBytes = 621000; // 606 KB (under 1 MB)
          _documents[1].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_constitution.pdf';
        }
        if (_documents.length > 2) {
          _documents[2].fileName = 'Recognition_Affiliation_Certificate.pdf';
          _documents[2].fileSizeBytes = 545000; // 532 KB
          _documents[2].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_affiliation.pdf';
        }
        if (_documents.length > 3) {
          _documents[3].fileName = 'Executive_Committee_Election_Record.pdf';
          _documents[3].fileSizeBytes = 480000; // 468 KB
          _documents[3].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_elections.pdf';
        }
        if (_documents.length > 4) {
          _documents[4].fileName = 'Authorized_Representative_Letter.pdf';
          _documents[4].fileSizeBytes = 350000; // 341 KB
          _documents[4].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_rep_letter.pdf';
        }
      } else if (role == 'Coach') {
        _competitionNameController.text = 'Apex High Performance Track Academy';
        _sportController.text = widget.profile.sport.isNotEmpty ? widget.profile.sport : 'Track & Field / Sprinting';
        _regNumController.text = 'COACH-LIC-2026-781';
        _regAuthorityController.text = 'IAAF / World Athletics Certified';
        _achievementController.text =
            'Head Coach with 8+ years coaching national-level sprinters. Certified Level 2 IAAF coach, trained 14 state medalists.';
        _compLinkController.text = 'https://coachportfolio.atheleos.com/profile';
        _countryController.text = 'India';

        if (_documents.isNotEmpty) {
          _documents[0].fileName = 'Coaching_License_Level2.pdf';
          _documents[0].fileSizeBytes = 720000; // 703 KB (under 1 MB)
          _documents[0].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_coaching.pdf';
        }
        if (_documents.length > 1) {
          _documents[1].fileName = 'Academy_Affiliation_Letter.pdf';
          _documents[1].fileSizeBytes = 680000; // 664 KB
          _documents[1].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_affiliation.pdf';
        }
        if (_documents.length > 2) {
          _documents[2].fileName = 'Govt_Identity_Proof.pdf';
          _documents[2].fileSizeBytes = 550000; // 537 KB
          _documents[2].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_id.pdf';
        }
        if (_documents.length > 3) {
          _documents[3].fileName = 'Federation_Coach_Accreditation.pdf';
          _documents[3].fileSizeBytes = 420000; // 410 KB
          _documents[3].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_accreditation.pdf';
        }
      } else if (role == 'Brand') {
        _brandNameController.text = widget.profile.organizationName?.isNotEmpty == true
            ? widget.profile.organizationName!
            : 'Apex Athletic Gear';
        _brandType = 'Apparel & Footwear';
        _brandIndustryCategory = 'Sports Goods & Apparel';
        _brandCountry = 'India';
        _brandYearEstablishedController.text = '2018';
        _brandStateRegionController.text = 'Delhi NCR';
        _brandAddressController.text = 'Plot 42, Okhla Industrial Area Phase III, New Delhi 110020';
        _brandWebsiteController.text = 'https://www.apexathletic.com';

        _brandBusinessRegNumController.text = 'CIN-U74999DL2018PTC334920';
        _brandLegalNameController.text = 'Apex Athletic Performance Gear Private Limited';
        _brandRegAuthorityController.text = 'Registrar of Companies (RoC Delhi), MCA';
        _brandRegDateController.text = '14/08/2018';
        _brandBusinessType = 'Private Limited Company (Pvt Ltd)';

        _brandTrademarkNameController.text = 'APEX ATHLETIC';
        _brandTrademarkRegNumController.text = 'TM-CLASS-25-4928104';
        _brandOwnershipType = 'Direct Brand Owner';
        _brandSportsProductsServices = 'Footwear & Apparel';
        _brandPrimarySportsCategory = 'Multi-Sport / All Sports';

        _brandRepNameController.text = 'Vikramaditya Sharma';
        _brandRepDesignationController.text = 'Director & Head of Athlete Partnerships';
        _brandRepEmailController.text = 'partnerships@apexathletic.com';
        _brandRepPhoneController.text = '+91 98101 23456';
        _brandSocialUrlController.text = 'https://instagram.com/apexathletic';
        _brandPartnershipTier = 'Multi-Sport / All Sports';
        _brandDescriptionController.text =
            'Leading Indian performance athletic brand specializing in competition track spikes, training apparel, and technical gear for elite and emerging sports talent.';

        _competitionNameController.text = _brandNameController.text;
        _sportController.text = _brandIndustryCategory!;
        _regNumController.text = _brandBusinessRegNumController.text;
        _eventController.text = _brandRepNameController.text;
        _compLinkController.text = _brandWebsiteController.text;
        _positionController.text = _brandRepEmailController.text;
        _countryController.text = _brandCountry!;

        if (_documents.isNotEmpty) {
          _documents[0].fileName = 'Business_Registration_Certificate_MCA.pdf';
          _documents[0].fileSizeBytes = 740000; // 722 KB (under 1 MB)
          _documents[0].downloadUrl =
              'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_incorporation.pdf';
        }
        if (_documents.length > 1) {
          _documents[1].fileName = 'Trademark_Registration_Certificate_Class25.pdf';
          _documents[1].fileSizeBytes = 690000; // 673 KB (under 1 MB)
          _documents[1].downloadUrl =
              'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_trademark.pdf';
        }
        if (_documents.length > 2) {
          _documents[2].fileName = 'Official_Brand_Business_Proof_GST.pdf';
          _documents[2].fileSizeBytes = 540000; // 527 KB (under 1 MB)
          _documents[2].downloadUrl =
              'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_business_proof.pdf';
        }
        if (_documents.length > 3) {
          _documents[3].fileName = 'Authorized_Representative_Board_Letter.pdf';
          _documents[3].fileSizeBytes = 430000; // 420 KB (under 1 MB)
          _documents[3].downloadUrl =
              'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_rep_letter.pdf';
        }
      } else {
        // Athlete
        _competitionNameController.text = 'National Athletics Championship 2026';
        _eventController.text = '100m Sprint Sprinting';
        _positionController.text = 'Gold Medalist';
        _dateController.text = '12/06/2026';
        _federationController.text = 'Athletics Federation of India';
        _countryController.text = 'India';
        _achievementController.text = 'Finished first place with national record speed of 10.12 seconds.';
        _regNumController.text = 'ATH-2026-9843';
        _compLinkController.text = 'https://results.athleticsfederation.org/100m';

        if (_documents.isNotEmpty) {
          _documents[0].fileName = 'Official_Certificate.pdf';
          _documents[0].fileSizeBytes = 750000; // 732 KB (under 1 MB)
          _documents[0].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_cert.pdf';
        }
        if (_documents.length > 1) {
          _documents[1].fileName = 'Gold_Medal_Proof.png';
          _documents[1].fileSizeBytes = 680000; // 664 KB (under 1 MB)
          _documents[1].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_medal.png';
        }
        if (_documents.length > 2) {
          _documents[2].fileName = 'Result_Sheet_100m.pdf';
          _documents[2].fileSizeBytes = 540000; // 527 KB
          _documents[2].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_results.pdf';
        }
        if (_documents.length > 3) {
          _documents[3].fileName = 'Tournament_ID.pdf';
          _documents[3].fileSizeBytes = 430000; // 420 KB
          _documents[3].downloadUrl = 'https://atheleos-media-worker.atheleos-media.workers.dev/media/demo_id.pdf';
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form auto-filled with realistic verification details!'),
        backgroundColor: AppTheme.primaryColor,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all mandatory fields marked with an asterisk (*).'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate mandatory documents
    final missingMandatoryDocs = _documents.where((d) => d.isRequired && !d.hasFile).toList();
    if (missingMandatoryDocs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Required document missing: ${missingMandatoryDocs.first.title}'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Ensure no background document upload is still in progress
    final uploadingDocs = _documents.where((d) => d.isUploading).toList();
    if (uploadingDocs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please wait, "${uploadingDocs.first.title}" is still uploading.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final role = widget.profile.role;
      Map<String, dynamic> details = {};

      if (role == 'Federation') {
        details = {
          'federationName': _federationNameController.text.trim(),
          'federationType': _federationType,
          'sport': _sportController.text.trim(),
          'stateRegion': _stateRegionController.text.trim(),
          'country': _countryController.text.trim(),
          'yearEstablished': _yearEstablishedController.text.trim(),
          'officialAddress': _officialAddressController.text.trim(),
          'officialWebsite': _officialWebsiteController.text.trim(),

          'regNumber': _regNumController.text.trim(),
          'regAuthority': _regAuthorityController.text.trim(),
          'regDate': _regDateController.text.trim(),

          'affiliationType': _affiliationTypeController.text.trim(),
          'recognizingAuthority': _recognizingAuthorityController.text.trim(),
          'affiliationNumber': _affiliationNumController.text.trim(),
          'affiliationDate': _affiliationDateController.text.trim(),

          'presidentName': _presidentNameController.text.trim(),
          'secretaryGeneralName': _secretaryGeneralController.text.trim(),
          'treasurerName': _treasurerNameController.text.trim(),
          'latestElectionDate': _electionDateController.text.trim(),

          // Document mappings
          'documents': _documents.where((d) => d.hasFile).map((d) => {
            'slotKey': d.slotKey,
            'title': d.title,
            'fileName': d.fileName ?? '',
            'fileSizeBytes': d.fileSizeBytes,
            'downloadUrl': d.downloadUrl ?? '',
            'isRequired': d.isRequired,
          }).toList(),
          'uploadedFiles': _documents.where((d) => d.hasFile).map((d) => d.fileName ?? '').toList(),

          // Common keys for unified dashboard compatibility
          'competitionName': _federationNameController.text.trim(),
          'event': _secretaryGeneralController.text.trim().isNotEmpty
              ? '${_secretaryGeneralController.text.trim()} (Sec Gen)'
              : _presidentNameController.text.trim(),
          'positionCategory': _federationType,
          'athleteRegNum': _regNumController.text.trim(),
          'compLink': _officialWebsiteController.text.trim(),
          'targetBadge': 'Verified Federation',
          'targetLevel': 1,
          'submittedAt': DateTime.now().toIso8601String(),
        };
      } else if (role == 'Coach') {
        details = {
          'sport': _sportController.text.trim(),
          'competitionName': _competitionNameController.text.trim(),
          'athleteRegNum': _regNumController.text.trim(),
          'organizingFederation': _regAuthorityController.text.trim(),
          'achievement': _achievementController.text.trim(),
          'compLink': _compLinkController.text.trim(),
          'country': _countryController.text.trim(),
          'documents': _documents.where((d) => d.hasFile).map((d) => {
            'slotKey': d.slotKey,
            'title': d.title,
            'fileName': d.fileName ?? '',
            'fileSizeBytes': d.fileSizeBytes,
            'downloadUrl': d.downloadUrl ?? '',
            'isRequired': d.isRequired,
          }).toList(),
          'uploadedFiles': _documents.where((d) => d.hasFile).map((d) => d.fileName ?? '').toList(),
          'targetBadge': 'Verified Coach',
          'targetLevel': 1,
          'submittedAt': DateTime.now().toIso8601String(),
        };
      } else if (role == 'Brand') {
        details = {
          // 1. Brand Details
          'brandName': _brandNameController.text.trim(),
          'brandType': _brandType,
          'industryCategory': _brandIndustryCategory,
          'country': _brandCountry,
          'yearEstablished': _brandYearEstablishedController.text.trim(),
          'stateRegion': _brandStateRegionController.text.trim(),
          'officialAddress': _brandAddressController.text.trim(),
          'officialWebsite': _brandWebsiteController.text.trim(),

          // 2. Business / Legal Registration
          'businessRegNumber': _brandBusinessRegNumController.text.trim(),
          'legalBusinessName': _brandLegalNameController.text.trim(),
          'registrationAuthority': _brandRegAuthorityController.text.trim(),
          'registrationDate': _brandRegDateController.text.trim(),
          'businessType': _brandBusinessType,

          // 3. Brand Ownership & Sports Presence
          'trademarkName': _brandTrademarkNameController.text.trim(),
          'trademarkRegNumber': _brandTrademarkRegNumController.text.trim(),
          'ownershipType': _brandOwnershipType,
          'sportsProductsServices': _brandSportsProductsServices,
          'primarySportsCategory': _brandPrimarySportsCategory,

          // 4. Authorized Representative & Business Presence
          'representativeName': _brandRepNameController.text.trim(),
          'representativeDesignation': _brandRepDesignationController.text.trim(),
          'officialBusinessEmail': _brandRepEmailController.text.trim(),
          'businessContactPhone': _brandRepPhoneController.text.trim(),
          'socialUrl': _brandSocialUrlController.text.trim(),
          'partnershipTier': _brandPartnershipTier,
          'brandDescription': _brandDescriptionController.text.trim(),

          // 5. Document mappings
          'documents': _documents.where((d) => d.hasFile).map((d) => {
            'slotKey': d.slotKey,
            'title': d.title,
            'fileName': d.fileName ?? '',
            'fileSizeBytes': d.fileSizeBytes,
            'downloadUrl': d.downloadUrl ?? '',
            'isRequired': d.isRequired,
          }).toList(),
          'uploadedFiles': _documents.where((d) => d.hasFile).map((d) => d.fileName ?? '').toList(),

          // Unified keys for dashboard compatibility
          'competitionName': _brandNameController.text.trim(),
          'sport': _brandIndustryCategory ?? _brandPrimarySportsCategory ?? 'Sports Goods',
          'athleteRegNum': _brandBusinessRegNumController.text.trim(),
          'event': _brandRepNameController.text.trim().isNotEmpty
              ? '${_brandRepNameController.text.trim()} (${_brandRepDesignationController.text.trim()})'
              : _brandNameController.text.trim(),
          'compLink': _brandWebsiteController.text.trim(),
          'positionCategory': _brandType ?? 'Brand',
          'targetBadge': 'Verified Brand',
          'targetLevel': 1,
          'submittedAt': DateTime.now().toIso8601String(),
        };
      } else {
        details = {
          'sport': _sportController.text.trim(),
          'competitionName': _competitionNameController.text.trim(),
          'event': _eventController.text.trim(),
          'positionCategory': _positionController.text.trim(),
          'date': _dateController.text.trim(),
          'organizingFederation': _federationController.text.trim(),
          'country': _countryController.text.trim(),
          'achievement': _achievementController.text.trim(),
          'athleteRegNum': _regNumController.text.trim(),
          'compLink': _compLinkController.text.trim(),
          'documents': _documents.where((d) => d.hasFile).map((d) => {
            'slotKey': d.slotKey,
            'title': d.title,
            'fileName': d.fileName ?? '',
            'fileSizeBytes': d.fileSizeBytes,
            'downloadUrl': d.downloadUrl ?? '',
            'isRequired': d.isRequired,
          }).toList(),
          'uploadedFiles': _documents.where((d) => d.hasFile).map((d) => d.fileName ?? '').toList(),
          'targetBadge': _nextBadgeName,
          'targetLevel': widget.profile.verificationLevel + 1,
          'submittedAt': DateTime.now().toIso8601String(),
        };
      }

      await ref
          .read(universalProfileControllerProvider(widget.profile.id).notifier)
          .submitVerification(details, fallbackProfile: widget.profile)
          .timeout(const Duration(seconds: 8));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification application for "$_nextBadgeName" submitted successfully!'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Verification submission exception (handled gracefully): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification application for "$_nextBadgeName" submitted!'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // --- Standard Form Field Helpers & Typography ---

  InputDecoration _fieldDecoration({
    required String labelText,
    String? hintText,
    Widget? suffixIcon,
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$labelText *' : labelText,
      labelStyle: GoogleFonts.outfit(
        fontSize: 13,
        color: Colors.white70,
        fontWeight: FontWeight.w500,
      ),
      hintText: hintText,
      hintStyle: GoogleFonts.outfit(
        fontSize: 12.5,
        color: Colors.white30,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF18181D),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      errorStyle: const TextStyle(fontSize: 11, color: Colors.redAccent),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String labelText,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
      decoration: _fieldDecoration(
        labelText: labelText,
        hintText: 'DD/MM/YYYY',
        isRequired: isRequired,
        suffixIcon: IconButton(
          icon: const Icon(AthIcons.calendar, size: 18, color: AppTheme.primaryColor),
          onPressed: () => _selectDate(context, controller),
          constraints: const BoxConstraints(),
          padding: const EdgeInsets.only(right: 8),
        ),
      ),
      onTap: () => _selectDate(context, controller),
      validator: isRequired
          ? (v) => (v == null || v.trim().isEmpty) ? '$labelText is required' : null
          : null,
    );
  }

  Widget _buildSectionCard({
    required String number,
    required String title,
    String? subtitle,
    bool isOptional = false,
    Widget? leadingIcon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF131316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                leadingIcon,
                const SizedBox(width: 10),
              ] else ...[
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    number,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              if (isOptional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OPTIONAL',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white54,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white60, height: 1.35),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDocumentSlotCard(VerificationDocumentItem item, {int? index}) {
    final hasFile = item.hasFile;
    final slotNumber = index != null ? (index + 1).toString() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasFile
              ? Colors.greenAccent.withValues(alpha: 0.35)
              : (item.isRequired ? AppTheme.primaryColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (slotNumber != null) ...[
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    slotNumber,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              if (item.icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Icon(item.icon, size: 18, color: item.iconColor ?? AppTheme.primaryColor),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: item.isRequired
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.isRequired ? 'Required' : 'Optional',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: item.isRequired ? Colors.redAccent : Colors.white54,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!hasFile && !item.isUploading)
                InkWell(
                  onTap: () => _pickDocument(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AthIcons.cloudArrowUp, size: 15, color: AppTheme.primaryColor),
                        SizedBox(width: 5),
                        Text(
                          'Upload',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (item.isUploading) ...[
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                  SizedBox(width: 10),
                  Text('Uploading to Cloudflare R2...', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ] else if (hasFile) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(AthIcons.checkCircleSolid, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName!,
                          style: const TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Size: ${_formatFileSize(item.fileSizeBytes)} • Max 1 MB limit checked',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AthIcons.xMark, size: 18, color: Colors.white60),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Remove document',
                    onPressed: () {
                      setState(() {
                        item.fileName = null;
                        item.fileSizeBytes = null;
                        item.downloadUrl = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Generic Dropdown Field Helper
  Widget _buildDropdownField({
    required String? value,
    required String labelText,
    required String hintText,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: (value != null && items.contains(value)) ? value : null,
      dropdownColor: const Color(0xFF1E1E24),
      style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
      icon: const Icon(AthIcons.chevronDown, color: Colors.white54, size: 20),
      isExpanded: true,
      decoration: _fieldDecoration(
        labelText: labelText,
        hintText: hintText,
        isRequired: isRequired,
      ),
      items: items.map((t) {
        return DropdownMenuItem<String>(
          value: t,
          child: Text(
            t,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: isRequired
          ? (v) => (v == null || v.isEmpty) ? '$labelText is required' : null
          : null,
    );
  }

  // Section 1 Dropdown
  Widget _buildFederationTypeDropdown() {
    final types = [
      'National Sports Federation (NSF)',
      'State Sports Association',
      'District Sports Association',
      'International Sports Federation',
    ];

    return DropdownButtonFormField<String>(
      initialValue: _federationType,
      dropdownColor: const Color(0xFF1E1E24),
      style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
      decoration: _fieldDecoration(
        labelText: 'Federation Type',
        isRequired: true,
      ),
      items: types.map((t) {
        return DropdownMenuItem<String>(
          value: t,
          child: Text(t, style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white)),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) {
          setState(() => _federationType = val);
        }
      },
      validator: (v) => (v == null || v.isEmpty) ? 'Federation Type is required' : null,
    );
  }

  // --- 5 SECTIONS FOR FEDERATION ---
  List<Widget> _buildFederationSections() {
    return [
      // 1. FEDERATION DETAILS
      _buildSectionCard(
        number: '1',
        title: 'FEDERATION DETAILS',
        children: [
          TextFormField(
            controller: _federationNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Federation Name', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Federation Name is required' : null,
          ),
          const SizedBox(height: 10),
          _buildFederationTypeDropdown(),
          const SizedBox(height: 10),
          TextFormField(
            controller: _sportController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Sport / Discipline', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Sport / Discipline is required' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _stateRegionController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'State / Region'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _countryController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Country', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Country is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _yearEstablishedController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Year Established', hintText: 'YYYY (e.g. 1946)', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Year Established is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _officialAddressController,
            maxLines: 2,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Official Address', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Official Address is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _officialWebsiteController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Official Website', hintText: 'https://...'),
          ),
        ],
      ),

      // 2. LEGAL REGISTRATION
      _buildSectionCard(
        number: '2',
        title: 'LEGAL REGISTRATION',
        children: [
          TextFormField(
            controller: _regNumController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Registration Number', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Registration Number is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _regAuthorityController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Registration Authority',
              hintText: 'e.g. Registrar of Societies, MCA',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Registration Authority is required' : null,
          ),
          const SizedBox(height: 10),
          _buildDateField(
            controller: _regDateController,
            labelText: 'Registration Date',
            isRequired: true,
          ),
        ],
      ),

      // 3. RECOGNITION & AFFILIATION (Optional)
      _buildSectionCard(
        number: '3',
        title: 'RECOGNITION & AFFILIATION',
        isOptional: true,
        subtitle: 'Fill if the federation holds Olympic, Continental, or Government affiliation.',
        children: [
          TextFormField(
            controller: _affiliationTypeController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Affiliation Type',
              hintText: 'e.g. IOA / World Athletics / Continental',
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _recognizingAuthorityController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Recognizing Authority',
              hintText: 'e.g. Ministry of Youth Affairs and Sports (MYAS)',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _affiliationNumController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Affiliation Number'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateField(
                  controller: _affiliationDateController,
                  labelText: 'Affiliation Date',
                  isRequired: false,
                ),
              ),
            ],
          ),
        ],
      ),

      // 4. GOVERNANCE & OFFICE BEARERS
      _buildSectionCard(
        number: '4',
        title: 'GOVERNANCE & OFFICE BEARERS',
        children: [
          TextFormField(
            controller: _presidentNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'President Name', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'President Name is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _secretaryGeneralController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Secretary General Name', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Secretary General Name is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _treasurerNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Treasurer Name'),
          ),
          const SizedBox(height: 10),
          _buildDateField(
            controller: _electionDateController,
            labelText: 'Latest Election Date',
            isRequired: false,
          ),
        ],
      ),

      // 5. REQUIRED PROOF DOCUMENTS
      _buildSectionCard(
        number: '5',
        title: 'REQUIRED PROOF DOCUMENTS',
        subtitle: 'Max file size: 1 MB per document. Supported formats: PDF, JPG, PNG.',
        children: [
          ..._documents.map((d) => _buildDocumentSlotCard(d)),
        ],
      ),
    ];
  }

  // --- COACH SECTIONS ---
  List<Widget> _buildCoachSections() {
    return [
      _buildSectionCard(
        number: '1',
        title: 'COACHING SPECIALTY & ACADEMY',
        children: [
          TextFormField(
            controller: _sportController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Coaching Sport Specialties', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Sport specialty is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _competitionNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Current Academy / Club Affiliation', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Academy affiliation is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _achievementController,
            maxLines: 3,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Professional Experience & Certifications Overview',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Experience summary is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _regNumController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Coaching License Number'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _regAuthorityController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Certifying Body'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _compLinkController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Coaching Portfolio / Website URL (Optional)'),
          ),
        ],
      ),
      _buildSectionCard(
        number: '2',
        title: 'REQUIRED PROOF DOCUMENTS',
        subtitle: 'Max file size: 1 MB per document. Supported formats: PDF, JPG, PNG.',
        children: [
          ..._documents.map((d) => _buildDocumentSlotCard(d)),
        ],
      ),
    ];
  }

  // --- BRAND SECTIONS (5 Full Sections matching Spec) ---
  List<Widget> _buildBrandSections() {
    return [
      // 1. BRAND DETAILS
      _buildSectionCard(
        number: '1',
        leadingIcon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(AthIcons.buildingLibrary, color: AppTheme.primaryColor, size: 15),
        ),
        title: '1. BRAND DETAILS',
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandNameController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Brand Name', hintText: 'Enter brand name', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Brand Name is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdownField(
                  value: _brandType,
                  labelText: 'Brand Type',
                  hintText: 'Select type',
                  items: _brandTypeOptions,
                  onChanged: (val) => setState(() => _brandType = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  value: _brandIndustryCategory,
                  labelText: 'Industry / Category',
                  hintText: 'Select category',
                  items: _brandIndustryOptions,
                  onChanged: (val) => setState(() => _brandIndustryCategory = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdownField(
                  value: _brandCountry,
                  labelText: 'Country',
                  hintText: 'Select country',
                  items: _brandCountryOptions,
                  onChanged: (val) => setState(() => _brandCountry = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandYearEstablishedController,
                  readOnly: true,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(
                    labelText: 'Year Established',
                    hintText: 'YYYY',
                    isRequired: true,
                    suffixIcon: IconButton(
                      icon: const Icon(AthIcons.calendar, size: 16, color: AppTheme.primaryColor),
                      onPressed: () => _selectYear(context, _brandYearEstablishedController),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 8),
                    ),
                  ),
                  onTap: () => _selectYear(context, _brandYearEstablishedController),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Year Established is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _brandStateRegionController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'State / Region', hintText: 'Enter state/region'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandAddressController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Official Address', hintText: 'Enter full address', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandWebsiteController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Official Website',
              hintText: 'Enter website URL',
              isRequired: true,
              suffixIcon: const Icon(AthIcons.globeAlt, size: 16, color: Colors.white38),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Website is required' : null,
          ),
        ],
      ),

      // 2. BUSINESS / LEGAL REGISTRATION
      _buildSectionCard(
        number: '2',
        leadingIcon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(AthIcons.documentText, color: AppTheme.primaryColor, size: 15),
        ),
        title: '2. BUSINESS / LEGAL REGISTRATION',
        children: [
          TextFormField(
            controller: _brandBusinessRegNumController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Business / Company Registration No.',
              hintText: 'Enter registration number',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Registration No. is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandLegalNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Legal Business Name',
              hintText: 'Enter legal business name',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Legal name is required' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandRegAuthorityController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(
                    labelText: 'Registration Authority',
                    hintText: 'Enter authority name',
                    isRequired: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Authority is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateField(
                  controller: _brandRegDateController,
                  labelText: 'Registration Date',
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDropdownField(
            value: _brandBusinessType,
            labelText: 'Business Type',
            hintText: 'Select business type',
            items: _brandBusinessTypeOptions,
            onChanged: (val) => setState(() => _brandBusinessType = val),
          ),
        ],
      ),

      // 3. BRAND OWNERSHIP & SPORTS PRESENCE
      _buildSectionCard(
        number: '3',
        leadingIcon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(AthIcons.checkBadge, color: AppTheme.primaryColor, size: 15),
        ),
        title: '3. BRAND OWNERSHIP & SPORTS PRESENCE',
        children: [
          TextFormField(
            controller: _brandTrademarkNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Brand / Trademark Name',
              hintText: 'Enter brand/trademark name',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Trademark name is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandTrademarkRegNumController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Trademark / Brand Registration No.',
              hintText: 'Enter registration number',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Registration number is required' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildDropdownField(
                  value: _brandOwnershipType,
                  labelText: 'Brand Ownership Type',
                  hintText: 'Select ownership type',
                  items: _brandOwnershipOptions,
                  onChanged: (val) => setState(() => _brandOwnershipType = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdownField(
                  value: _brandSportsProductsServices,
                  labelText: 'Sports Products / Services',
                  hintText: 'Select products/services',
                  items: _brandProductsServicesOptions,
                  onChanged: (val) => setState(() => _brandSportsProductsServices = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDropdownField(
            value: _brandPrimarySportsCategory,
            labelText: 'Primary Sports / Categories',
            hintText: 'Select sports / categories',
            items: _brandSportsCategoriesOptions,
            onChanged: (val) => setState(() => _brandPrimarySportsCategory = val),
          ),
        ],
      ),

      // 4. AUTHORIZED REPRESENTATIVE & BUSINESS PRESENCE
      _buildSectionCard(
        number: '4',
        leadingIcon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(AthIcons.userGroup, color: AppTheme.primaryColor, size: 15),
        ),
        title: '4. AUTHORIZED REPRESENTATIVE & BUSINESS PRESENCE',
        children: [
          TextFormField(
            controller: _brandRepNameController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Authorized Representative Name',
              hintText: 'Enter full name',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Representative name is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandRepDesignationController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Designation / Position',
              hintText: 'Enter designation',
              isRequired: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Designation is required' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandRepEmailController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(
                    labelText: 'Official Business Email',
                    hintText: 'Enter email address',
                    isRequired: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _brandRepPhoneController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(
                    labelText: 'Business Contact Number',
                    hintText: 'Enter mobile number',
                    isRequired: true,
                    suffixIcon: const Icon(AthIcons.phone, size: 16, color: Colors.white38),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _brandSocialUrlController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(
                    labelText: 'Official Social / Business Profile',
                    hintText: 'Enter URL',
                    suffixIcon: const Icon(AthIcons.link, size: 16, color: Colors.white38),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDropdownField(
                  value: _brandPartnershipTier,
                  labelText: 'Primary Sports / Categories',
                  hintText: 'Select sports / categories',
                  items: _brandSportsCategoriesOptions,
                  onChanged: (val) => setState(() => _brandPartnershipTier = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brandDescriptionController,
            maxLines: 3,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(
              labelText: 'Brief Description of Brand',
              hintText: 'Enter brand description',
              isRequired: true,
              suffixIcon: const Padding(
                padding: EdgeInsets.only(top: 8.0, right: 8.0),
                child: Icon(AthIcons.documentText, size: 16, color: Colors.white38),
              ),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
          ),
        ],
      ),

      // 5. REQUIRED PROOF DOCUMENTS
      _buildSectionCard(
        number: '5',
        leadingIcon: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(AthIcons.folderOpen, color: AppTheme.primaryColor, size: 15),
        ),
        title: '5. REQUIRED PROOF DOCUMENTS',
        subtitle: 'Upload the following documents (PDF, JPG, PNG - Max 1MB each)',
        children: [
          for (int i = 0; i < _documents.length; i++)
            _buildDocumentSlotCard(_documents[i], index: i),
          const SizedBox(height: 6),
          InkWell(
            onTap: _addSupportingDocument,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AthIcons.plusCircle, size: 18, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'Add Supporting Document (Optional)',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  // --- ATHLETE SECTIONS ---
  List<Widget> _buildAthleteSections() {
    return [
      _buildSectionCard(
        number: '1',
        title: 'COMPETITION & PERFORMANCE DETAILS',
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _sportController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Sport', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Sport is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _competitionNameController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Competition Name', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Competition name is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _eventController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Event / Category', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Event is required' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _positionController,
                  style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
                  decoration: _fieldDecoration(labelText: 'Position / Medal', isRequired: true),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Position is required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDateField(
            controller: _dateController,
            labelText: 'Event Date',
            isRequired: true,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _federationController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Organizing Federation', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Federation is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _achievementController,
            maxLines: 2,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Description of Accomplishment', isRequired: true),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _regNumController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Athlete Reg Number (Optional)'),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _compLinkController,
            style: GoogleFonts.outfit(fontSize: 13.5, color: Colors.white),
            decoration: _fieldDecoration(labelText: 'Official Results Link (Optional)'),
          ),
        ],
      ),
      _buildSectionCard(
        number: '2',
        title: 'REQUIRED PROOF DOCUMENTS',
        subtitle: 'Max file size: 1 MB per document. Supported formats: PDF, JPG, PNG.',
        children: [
          ..._documents.map((d) => _buildDocumentSlotCard(d)),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final status = p.verificationStatus;
    final isFederation = p.role == 'Federation';
    final isCoach = p.role == 'Coach';
    final isBrand = p.role == 'Brand';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121216),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const Icon(AthIcons.shieldCheck, color: AppTheme.primaryColor, size: 22),
            const SizedBox(width: 10),
            Text(
              'PORTFOLIO VERIFICATION',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AthIcons.xMark, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Status / Banner card
            _buildTopBanner(status),
            const SizedBox(height: 14),

            if (status == 'rejected' && widget.profile.verificationRejectedReason.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PREVIOUS APPLICATION REJECTED',
                        style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.profile.verificationRejectedReason,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],

            if (status == 'moreInfoRequired' && widget.profile.verificationRejectedReason.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ADDITIONAL INFORMATION REQUESTED',
                        style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(widget.profile.verificationRejectedReason,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],

            // Active or editable single-page form
            if (status == 'none' || status == 'rejected' || status == 'moreInfoRequired') ...[
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFederation) ..._buildFederationSections(),
                    if (isCoach) ..._buildCoachSections(),
                    if (isBrand) ..._buildBrandSections(),
                    if (!isFederation && !isCoach && !isBrand) ..._buildAthleteSections(),

                    // Prominent Submit Button at the bottom of the single scrollable page
                    Container(
                      padding: const EdgeInsets.only(top: 8, bottom: 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        onPressed: _isSubmitting ? null : _submitRequest,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'SUBMIT VERIFICATION APPLICATION',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13.5,
                                      letterSpacing: 0.6,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(AthIcons.arrowRight, size: 18, color: Colors.black),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _buildStatusOverview(status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(AthIcons.sparkles, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'APPLYING FOR NEXT LEVEL',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _nextBadgeName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
              ],
            ),
          ),
          if (status == 'none' || status == 'rejected' || status == 'moreInfoRequired')
            TextButton(
              onPressed: _prefillForm,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: Text(
                'AUTO PRE-FILL',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusOverview(String status) {
    Color statusColor = Colors.amber;
    IconData statusIcon = AthIcons.clock;
    String statusTitle = 'Pending Review';
    String desc = 'Your verification request has been received and is waiting in the administrative review queue.';

    if (status == 'underReview') {
      statusColor = Colors.blueAccent;
      statusIcon = AthIcons.search;
      statusTitle = 'Under Review';
      desc = 'An administrative reviewer is currently analyzing your credentials and registered documentation.';
    } else if (status == 'approved') {
      statusColor = AppTheme.primaryColor;
      statusIcon = AthIcons.checkCircleSolid;
      statusTitle = 'Approved';
      desc = 'Congratulations! Your verification is approved. Your official verified status is active across ATHELEOS.';
    }

    final details = widget.profile.verificationRequestDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusTitle.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.white70),
              ),
              if (status == 'approved' && widget.profile.verificationDate.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Verification Date', style: TextStyle(color: Colors.white38, fontSize: 10.5)),
                    Text(widget.profile.verificationDate,
                        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (details.isNotEmpty) ...[
          Text(
            'SUBMITTED APPLICATION DETAILS',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 10.5, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestItem('Badge Target', details['targetBadge'] ?? ''),
                if (details['brandName'] != null)
                  _buildRequestItem('Brand Name', details['brandName']),
                if (details['brandType'] != null)
                  _buildRequestItem('Brand Type', details['brandType']),
                if (details['industryCategory'] != null)
                  _buildRequestItem('Industry', details['industryCategory']),
                if (details['country'] != null && details['brandName'] != null)
                  _buildRequestItem('Country', details['country']),
                if (details['businessRegNumber'] != null)
                  _buildRequestItem('Registration #', details['businessRegNumber']),
                if (details['trademarkName'] != null)
                  _buildRequestItem('Trademark', details['trademarkName']),
                if (details['representativeName'] != null)
                  _buildRequestItem('Representative', '${details['representativeName']} (${details['representativeDesignation'] ?? ''})'),
                if (details['officialBusinessEmail'] != null)
                  _buildRequestItem('Official Email', details['officialBusinessEmail']),
                if (details['federationName'] != null)
                  _buildRequestItem('Federation', details['federationName']),
                if (details['competitionName'] != null && details['federationName'] == null && details['brandName'] == null)
                  _buildRequestItem('Entity Name', details['competitionName']),
                if (details['federationType'] != null)
                  _buildRequestItem('Type', details['federationType']),
                if (details['sport'] != null && details['brandName'] == null)
                  _buildRequestItem('Sport / Discipline', details['sport']),
                if (details['regNumber'] != null && details['brandName'] == null)
                  _buildRequestItem('Registration #', details['regNumber']),
                if (details['regAuthority'] != null)
                  _buildRequestItem('Authority', details['regAuthority']),
                if (details['presidentName'] != null)
                  _buildRequestItem('President', details['presidentName']),
                if (details['secretaryGeneralName'] != null)
                  _buildRequestItem('Sec. General', details['secretaryGeneralName']),
                if (details['uploadedFiles'] != null) ...[
                  const SizedBox(height: 8),
                  const Text('Attached Proof Files:', style: TextStyle(fontSize: 10, color: Colors.white38)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List<String>.from(details['uploadedFiles']).map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(f, style: const TextStyle(fontSize: 9.5, color: Colors.white70)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRequestItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
          ),
          Expanded(
            child: Text(
              val,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
