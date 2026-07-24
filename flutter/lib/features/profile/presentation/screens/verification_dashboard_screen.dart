import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/verification_dialog.dart';

class VerificationDashboardScreen extends ConsumerWidget {
  const VerificationDashboardScreen({super.key});

  // Level definitions --------------------------------------------------------
  static const List<Map<String, dynamic>> _levels = [
    {
      'level': 0,
      'badge': 'No Badge',
      'color': 0xFF64748B,
      'icon': Icons.help_outline,
      'requirements': [
        'Complete your profile (name, bio, sport)',
        'Upload a profile photo',
        'Link at least one social account',
      ],
    },
    {
      'level': 1,
      'badge': 'Verified Athlete',
      'color': 0xFF3B82F6,
      'icon': Icons.verified_user_outlined,
      'requirements': [
        'Government ID or Passport scan',
        'Active club/academy affiliation',
        'Minimum 10 posts or clips',
      ],
    },
    {
      'level': 2,
      'badge': 'District Athlete',
      'color': 0xFF10B981,
      'icon': Icons.stars_outlined,
      'requirements': [
        'District-level competition certificate',
        'Coach reference letter',
        'Performance statistics uploaded',
      ],
    },
    {
      'level': 3,
      'badge': 'State Athlete',
      'color': 0xFFE5A93B,
      'icon': Icons.emoji_events_outlined,
      'requirements': [
        'State-level selection certificate',
        'Federation letter or ID card',
        'Media coverage or press mentions',
      ],
    },
    {
      'level': 4,
      'badge': 'National Athlete',
      'color': 0xFFEF4444,
      'icon': Icons.military_tech_outlined,
      'requirements': [
        'National team selection proof',
        'Official federation endorsement',
        'Verified agent or manager contact',
      ],
    },
    {
      'level': 5,
      'badge': 'Elite Athlete',
      'color': 0xFF8B5CF6,
      'icon': Icons.diamond_outlined,
      'requirements': ['Invite only — reviewed by ATHELEOS team.'],
    },
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'pending':
        return Colors.amberAccent;
      case 'underReview':
        return Colors.blueAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'moreInfoRequired':
        return Colors.orangeAccent;
      default:
        return Colors.white38;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved ✓';
      case 'pending':
        return 'Pending Review';
      case 'underReview':
        return 'Under Review';
      case 'rejected':
        return 'Rejected';
      case 'moreInfoRequired':
        return 'More Info Required';
      default:
        return 'Not Applied';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(activeProfileProvider);
    final applications =
        ref.watch(verificationApplicationsProvider).valueOrNull ?? [];
    final preferences = ref.watch(appPreferencesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('VERIFICATION',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
        backgroundColor: Colors.black,
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.red))),
        data: (profile) {
          if (profile == null)
            return const Center(
                child: Text('Profile not found.',
                    style: TextStyle(color: Colors.white38)));

          final level = profile.verificationLevel;
          final currentLevelData = _levels[level.clamp(0, 5)];
          final nextLevelData =
              level < 5 ? _levels[(level + 1).clamp(0, 5)] : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Current badge card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(currentLevelData['color'] as int).withOpacity(0.25),
                      Colors.black,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: Color(currentLevelData['color'] as int)
                          .withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(currentLevelData['color'] as int)
                            .withOpacity(0.15),
                        border: Border.all(
                            color: Color(currentLevelData['color'] as int),
                            width: 2),
                      ),
                      child: Icon(currentLevelData['icon'] as IconData,
                          color: Color(currentLevelData['color'] as int),
                          size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CURRENT BADGE',
                              style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(currentLevelData['badge'] as String,
                              style: GoogleFonts.spaceGrotesk(
                                  color:
                                      Color(currentLevelData['color'] as int),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(profile.verificationStatus)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      _statusColor(profile.verificationStatus)
                                          .withOpacity(0.3)),
                            ),
                            child: Text(
                              _statusLabel(profile.verificationStatus),
                              style: TextStyle(
                                  color:
                                      _statusColor(profile.verificationStatus),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Level progress bar ─────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LEVEL PROGRESS',
                          style: GoogleFonts.spaceGrotesk(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                      Text('${level} / 5',
                          style: GoogleFonts.spaceGrotesk(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: level / 5,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Next badge requirements ────────────────────────────────
              if (nextLevelData != null) ...[
                _sectionTitle('REQUIREMENTS FOR NEXT BADGE'),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(nextLevelData['icon'] as IconData,
                            color: Color(nextLevelData['color'] as int),
                            size: 18),
                        const SizedBox(width: 8),
                        Text(nextLevelData['badge'] as String,
                            style: TextStyle(
                                color: Color(nextLevelData['color'] as int),
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                      ]),
                      const SizedBox(height: 12),
                      ...(nextLevelData['requirements'] as List<String>)
                          .map((req) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.radio_button_unchecked,
                                        size: 14, color: Colors.white24),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Text(req,
                                            style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12))),
                                  ],
                                ),
                              )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── Apply for verification ─────────────────────────────────
              if (profile.verificationStatus == 'none' ||
                  profile.verificationStatus == 'rejected') ...[
                _sectionTitle('APPLY FOR VERIFICATION'),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => VerificationDialog(profile: profile),
                    );
                  },
                  child: Text('APPLY FOR VERIFICATION',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(height: 24),
              ],

              _sectionTitle('VERIFICATION HISTORY'),
              const SizedBox(height: 8),
              if (applications.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No verification applications yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                )
              else
                ...applications.map((application) {
                  final status = application['status'] as String? ?? 'pending';
                  final submittedAt = application['submittedAt'] as Timestamp?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      status == 'approved'
                          ? Icons.verified
                          : status == 'rejected'
                              ? Icons.cancel_outlined
                              : Icons.hourglass_top,
                      color: _statusColor(status),
                    ),
                    title: Text(
                      application['targetBadge'] as String? ??
                          'Verification application',
                    ),
                    subtitle: Text(
                      submittedAt == null
                          ? _statusLabel(status)
                          : '${_statusLabel(status)} · ${formatSettingsDateTime(submittedAt.toDate(), preferences)}',
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // ── Rejection reason ──────────────────────────────────────
              if (profile.verificationStatus == 'rejected' &&
                  profile.verificationRejectedReason.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Rejection Reason',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(profile.verificationRejectedReason,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ],
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ── All level badges overview ──────────────────────────────
              _sectionTitle('ALL BADGE LEVELS'),
              const SizedBox(height: 8),
              ..._levels.map((lvl) {
                final isUnlocked = level >= (lvl['level'] as int);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Color(lvl['color'] as int).withOpacity(0.06)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUnlocked
                          ? Color(lvl['color'] as int).withOpacity(0.2)
                          : Colors.white.withOpacity(0.04),
                    ),
                  ),
                  child: Row(children: [
                    Icon(lvl['icon'] as IconData,
                        color: isUnlocked
                            ? Color(lvl['color'] as int)
                            : Colors.white24,
                        size: 20),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Level ${lvl['level']} — ${lvl['badge']}',
                              style: TextStyle(
                                  color: isUnlocked
                                      ? Color(lvl['color'] as int)
                                      : Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ])),
                    if (isUnlocked)
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.greenAccent, size: 16),
                    if (!isUnlocked)
                      const Icon(Icons.lock_outlined,
                          color: Colors.white24, size: 14),
                  ]),
                );
              }),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: GoogleFonts.spaceGrotesk(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.6),
      );
}
