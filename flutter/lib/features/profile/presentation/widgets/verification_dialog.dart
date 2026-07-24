import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';

class VerificationDialog extends ConsumerStatefulWidget {
  final ProfileModel profile;

  const VerificationDialog({super.key, required this.profile});

  @override
  ConsumerState<VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends ConsumerState<VerificationDialog> {
  final _formKey = GlobalKey<FormState>();

  // General Form fields
  late TextEditingController _sportController;
  final _competitionNameController = TextEditingController();
  final _eventController = TextEditingController();
  final _positionController = TextEditingController();
  final _dateController = TextEditingController();
  final _federationController = TextEditingController();
  final _countryController = TextEditingController();
  final _achievementController = TextEditingController();
  final _regNumController = TextEditingController();
  final _compLinkController = TextEditingController();

  // Document states
  final List<String> _uploadedFiles = [];
  bool _isUploadingDoc = false;

  // Predefined Athlete Badge Progression
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

  // Get the next badge based on level
  String get _nextBadgeName {
    if (widget.profile.role == 'Coach') return 'Verified Coach';
    if (widget.profile.role == 'Federation') return 'Verified Federation';
    
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
    _countryController.text = widget.profile.state.isNotEmpty ? 'India' : '';
  }

  @override
  void dispose() {
    _sportController.dispose();
    _competitionNameController.dispose();
    _eventController.dispose();
    _positionController.dispose();
    _dateController.dispose();
    _federationController.dispose();
    _countryController.dispose();
    _achievementController.dispose();
    _regNumController.dispose();
    _compLinkController.dispose();
    super.dispose();
  }

  // Pick / Add document simulation
  void _addMockDocument(String category) {
    setState(() {
      _uploadedFiles.add('$category-${DateTime.now().millisecondsSinceEpoch % 10000}.pdf');
    });
  }

  // Pre-fill forms for demo evaluation
  void _prefillForm() {
    setState(() {
      _competitionNameController.text = 'National Athletics Championship 2026';
      _eventController.text = '100m Sprint Sprinting';
      _positionController.text = 'Gold Medalist';
      _dateController.text = '2026-06-12';
      _federationController.text = 'Athletics Federation of India';
      _countryController.text = 'India';
      _achievementController.text = 'Finished first place with national record speed.';
      _regNumController.text = 'ATH-2026-9843';
      _compLinkController.text = 'https://results.athleticsfederation.org/100m';
      
      _uploadedFiles.clear();
      _uploadedFiles.add('Official_Certificate.pdf');
      _uploadedFiles.add('Gold_Medal_Proof.png');
      _uploadedFiles.add('Result_Sheet_100m.pdf');
      _uploadedFiles.add('Tournament_ID.pdf');
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_uploadedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one certificate or proof document is required.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final details = {
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
      'uploadedFiles': _uploadedFiles,
      'targetBadge': _nextBadgeName,
      'targetLevel': widget.profile.role == 'Athlete' 
          ? widget.profile.verificationLevel + 1 
          : 1,
    };

    setState(() => _isUploadingDoc = true);
    await ref.read(universalProfileControllerProvider(widget.profile.id).notifier).submitVerification(details);
    setState(() => _isUploadingDoc = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verification application for "$_nextBadgeName" submitted successfully!'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final status = p.verificationStatus;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Stack
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.verified_user_outlined, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'PORTFOLIO VERIFICATION',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white30),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),

            // Condition Render based on application status
            if (status == 'none' || status == 'rejected' || status == 'moreInfoRequired') ...[
              _buildFormSection(status)
            ] else ...[
              _buildStatusSection(status)
            ],

            // Admin Review Simulator Control Panel
            _buildAdminSimulator(status),
          ],
        ),
      ),
    );
  }

  // 1. Application form section
  Widget _buildFormSection(String status) {
    final isAthlete = widget.profile.role == 'Athlete';
    final isCoach = widget.profile.role == 'Coach';
    final isFederation = widget.profile.role == 'Federation';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner about Badge Level
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APPLYING FOR NEXT LEVEL',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 10, color: AppTheme.primaryColor),
                      ),
                      Text(
                        _nextBadgeName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _prefillForm,
                  child: const Text('AUTO PRE-FILL', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (status == 'rejected' && widget.profile.verificationRejectedReason.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PREVIOUS APPLICATION REJECTED', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.profile.verificationRejectedReason, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (status == 'moreInfoRequired' && widget.profile.verificationRejectedReason.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ADDITIONAL INFORMATION REQUESTED', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.profile.verificationRejectedReason, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Forms based on Roles
          if (isAthlete) ..._buildAthleteFields(),
          if (isCoach) ..._buildCoachFields(),
          if (isFederation) ..._buildFederationFields(),

          const SizedBox(height: 16),
          Text(
            'REQUIRED PROOF DOCUMENTS',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 8),

          // Upload list
          ..._buildDocumentUploaders(isAthlete, isCoach, isFederation),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
              onPressed: _isUploadingDoc ? null : _submitRequest,
              child: _isUploadingDoc 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('SUBMIT VERIFICATION APPLICATION', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // Athlete specific Form Fields
  List<Widget> _buildAthleteFields() {
    return [
      TextFormField(
        controller: _sportController,
        decoration: const InputDecoration(labelText: 'Sport'),
        validator: (v) => v!.isEmpty ? 'Sport is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _competitionNameController,
        decoration: const InputDecoration(labelText: 'Competition Name'),
        validator: (v) => v!.isEmpty ? 'Competition is required' : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _eventController,
              decoration: const InputDecoration(labelText: 'Event/Category (e.g. 100m, Under 80kg)'),
              validator: (v) => v!.isEmpty ? 'Event is required' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(labelText: 'Achievement Position (e.g. Gold Medalist, Rank #3)'),
              validator: (v) => v!.isEmpty ? 'Position is required' : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Event Date (YYYY-MM-DD)', hintText: '2026-06-12'),
              validator: (v) => v!.isEmpty ? 'Date is required' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _federationController,
              decoration: const InputDecoration(labelText: 'Organizing Federation'),
              validator: (v) => v!.isEmpty ? 'Federation is required' : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _countryController,
        decoration: const InputDecoration(labelText: 'Country'),
        validator: (v) => v!.isEmpty ? 'Country is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _achievementController,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Brief Description of Accomplishment'),
        validator: (v) => v!.isEmpty ? 'Description is required' : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _regNumController,
              decoration: const InputDecoration(labelText: 'Athlete Registration Number (Optional)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _compLinkController,
              decoration: const InputDecoration(labelText: 'Official Results URL Link (Optional)'),
            ),
          ),
        ],
      ),
    ];
  }

  // Coach specific fields
  List<Widget> _buildCoachFields() {
    return [
      TextFormField(
        controller: _sportController,
        decoration: const InputDecoration(labelText: 'Coaching Sport Specialties'),
        validator: (v) => v!.isEmpty ? 'Sport specialty is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _competitionNameController,
        decoration: const InputDecoration(labelText: 'Current Academy / Club Affiliation'),
        validator: (v) => v!.isEmpty ? 'Academy affiliation is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _achievementController,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Professional Experience & Certifications Overview'),
        validator: (v) => v!.isEmpty ? 'Experience summary is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _regNumController,
        decoration: const InputDecoration(labelText: 'Federation License / Registration Number (Optional)'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _compLinkController,
        decoration: const InputDecoration(labelText: 'Official Coaching Portfolio / Website URL Link (Optional)'),
      ),
    ];
  }

  // Federation specific fields
  List<Widget> _buildFederationFields() {
    return [
      TextFormField(
        controller: _competitionNameController,
        decoration: const InputDecoration(labelText: 'Official Federation / Association Name'),
        validator: (v) => v!.isEmpty ? 'Federation Name is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _regNumController,
        decoration: const InputDecoration(labelText: 'Government registration / Charter ID Number'),
        validator: (v) => v!.isEmpty ? 'Government registration number is required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _eventController,
        decoration: const InputDecoration(labelText: 'Authorized Representative Name'),
        validator: (v) => v!.isEmpty ? 'Representative name is required' : null,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _compLinkController,
              decoration: const InputDecoration(labelText: 'Official Domain Website'),
              validator: (v) => v!.isEmpty ? 'Website URL is required' : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(labelText: 'Official Contact Email'),
              validator: (v) => v!.isEmpty ? 'Official contact email is required' : null,
            ),
          ),
        ],
      ),
    ];
  }

  // Upload selectors UI
  List<Widget> _buildDocumentUploaders(bool isAthlete, bool isCoach, bool isFederation) {
    final List<Map<String, dynamic>> slots = [];
    if (isAthlete) {
      slots.add({'title': 'Official Certificate (Required)', 'required': true});
      slots.add({'title': 'Medal Proof (Optional)', 'required': false});
      slots.add({'title': 'Official Result Sheet (Required)', 'required': true});
      slots.add({'title': 'Tournament ID Card (Optional)', 'required': false});
      slots.add({'title': 'Newspaper Article (Optional)', 'required': false});
    } else if (isCoach) {
      slots.add({'title': 'Coaching Certification (Required)', 'required': true});
      slots.add({'title': 'Club or Academy Affiliation letter (Required)', 'required': true});
      slots.add({'title': 'Government Identity Proof (Required)', 'required': true});
      slots.add({'title': 'Federation Coach License (Optional)', 'required': false});
    } else if (isFederation) {
      slots.add({'title': 'Registration / Charter Documents (Required)', 'required': true});
      slots.add({'title': 'Government Registration Document (Required)', 'required': true});
      slots.add({'title': 'Authorized Representative Authorization Letter (Required)', 'required': true});
    }

    return [
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ...slots.map((s) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['title'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          if (s['required'])
                            const Text('Mandatory upload', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E2E2E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () => _addMockDocument(s['title'].split(' ')[0]),
                      child: const Text('Add Document', style: TextStyle(fontSize: 10)),
                    )
                  ],
                ),
              );
            }).toList(),
            if (_uploadedFiles.isNotEmpty) ...[
              const Divider(color: Colors.white10),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Uploaded Proof Documents:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white60)),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _uploadedFiles.map((f) {
                  return Chip(
                    backgroundColor: const Color(0xFF2A2A2A),
                    label: Text(f, style: const TextStyle(fontSize: 10, color: Colors.white)),
                    deleteIcon: const Icon(Icons.cancel, size: 14, color: Colors.white60),
                    onDeleted: () {
                      setState(() {
                        _uploadedFiles.remove(f);
                      });
                    },
                  );
                }).toList(),
              )
            ]
          ],
        ),
      )
    ];
  }

  // 2. Status display section
  Widget _buildStatusSection(String status) {
    Color statusColor = Colors.amber;
    IconData statusIcon = Icons.hourglass_empty;
    String statusTitle = 'Pending Review';
    String desc = 'Your verification request has been received and is waiting in the administrative review queue. A platform administrator will check the submitted official certificates.';

    if (status == 'underReview') {
      statusColor = Colors.blueAccent;
      statusIcon = Icons.search;
      statusTitle = 'Under Review';
      desc = 'An administrative reviewer is currently analyzing the tournament brackets, result sheets, and checking with organizing sport federations.';
    } else if (status == 'approved') {
      statusColor = AppTheme.primaryColor;
      statusIcon = Icons.check_circle;
      statusTitle = 'Approved';
      desc = 'Congratulations! Your portfolio is verified. Your badge "${widget.profile.verificationBadge}" is now visible on your public sports profile.';
    }

    final details = widget.profile.verificationRequestDetails;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    statusTitle.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: statusColor, fontSize: 16, letterSpacing: 1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70),
              ),
              if (status == 'approved' && widget.profile.verificationDate.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(color: Colors.white10),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Verification Date', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text(widget.profile.verificationDate, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Verified by', style: TextStyle(color: Colors.white38, fontSize: 11)),
                    Text('Platform Admins', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ]
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (details.isNotEmpty) ...[
          Text('SUBMITTED REQUEST DETAILS', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primaryColor)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestItem('Next Badge', details['targetBadge'] ?? ''),
                if (details['competitionName'] != null)
                  _buildRequestItem('Competition', details['competitionName']),
                if (details['event'] != null)
                  _buildRequestItem('Event/Category', details['event']),
                if (details['positionCategory'] != null)
                  _buildRequestItem('Position', details['positionCategory']),
                if (details['date'] != null)
                  _buildRequestItem('Date', details['date']),
                if (details['organizingFederation'] != null)
                  _buildRequestItem('Federation', details['organizingFederation']),
                if (details['athleteRegNum'] != null && details['athleteRegNum'].toString().isNotEmpty)
                  _buildRequestItem('Registration Num', details['athleteRegNum']),
                const SizedBox(height: 8),
                const Text('Uploaded Documents:', style: TextStyle(fontSize: 10, color: Colors.white38)),
                const SizedBox(height: 4),
                if (details['uploadedFiles'] != null)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List<String>.from(details['uploadedFiles']).map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(f, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      );
                    }).toList(),
                  ),
              ],
            ),
          )
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRequestItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11))),
          Expanded(child: Text(val, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  // 3. Admin Simulator panel
  Widget _buildAdminSimulator(String status) {
    if (status == 'none') return const SizedBox.shrink();

    final details = widget.profile.verificationRequestDetails;
    final targetBadge = details['targetBadge'] ?? _nextBadgeName;
    final targetLevel = details['targetLevel'] ?? 1;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_mode, color: Colors.deepPurpleAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'ADMIN WORKFLOW SIMULATOR',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.deepPurpleAccent,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Since every badge verification requires manual review by platform administrators, use these actions to test each verification outcome status directly.',
            style: TextStyle(fontSize: 10, color: Colors.white54, height: 1.3),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.12),
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Under Review', style: TextStyle(fontSize: 10)),
                onPressed: () {
                  ref.read(universalProfileControllerProvider(widget.profile.id).notifier).adminAction(status: 'underReview');
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.12),
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Approve', style: TextStyle(fontSize: 10)),
                onPressed: () {
                  ref.read(universalProfileControllerProvider(widget.profile.id).notifier).adminAction(
                    status: 'approved',
                    badge: targetBadge,
                    level: targetLevel,
                  );
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withOpacity(0.12),
                  foregroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.info_outline, size: 14),
                label: const Text('Request More Info', style: TextStyle(fontSize: 10)),
                onPressed: () => _showAdminReasonDialog('moreInfoRequired'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.12),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Reject', style: TextStyle(fontSize: 10)),
                onPressed: () => _showAdminReasonDialog('rejected'),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _showAdminReasonDialog(String targetStatus) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            targetStatus == 'rejected' ? 'REJECT APPLICATION' : 'REQUEST INFORMATION',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryColor),
          ),
          content: TextField(
            controller: reasonController,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: InputDecoration(
              hintText: targetStatus == 'rejected' 
                ? 'Enter reason for rejection...'
                : 'Enter documents or details required...',
              hintStyle: const TextStyle(color: Colors.white24),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white30, fontSize: 11)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final reason = reasonController.text.trim().isNotEmpty
                    ? reasonController.text.trim()
                    : (targetStatus == 'rejected' ? 'Provided result sheets could not be verified.' : 'Please upload a valid newspaper article clipping.');
                
                ref.read(universalProfileControllerProvider(widget.profile.id).notifier).adminAction(
                  status: targetStatus,
                  rejectedReason: reason,
                );
                Navigator.pop(ctx);
              },
              child: const Text('SUBMIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}
