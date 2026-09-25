import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import '../widgets/verification_dialog.dart';

class VerificationDashboardScreen extends ConsumerWidget {
  final ProfileModel? profile;

  const VerificationDashboardScreen({super.key, this.profile});

  // Level definitions for Athletes -------------------------------------------
  static const List<Map<String, dynamic>> _athleteLevels = [
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

  String _effectiveStatus(
    ProfileModel profile,
    List<Map<String, dynamic>> applications,
  ) {
    if (profile.verificationStatus.isNotEmpty &&
        profile.verificationStatus != 'none') {
      return profile.verificationStatus;
    }
    if (applications.isNotEmpty) {
      final latest = applications.first['status'] as String?;
      if (latest != null && latest.isNotEmpty) {
        return latest;
      }
    }
    return 'none';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(currentProfileIdProvider);
    final loggedInId = ref.watch(loggedInUserIdProvider);
    final targetId = profile?.id ?? (activeId.isNotEmpty ? activeId : loggedInId);

    final profileFromController = targetId.isNotEmpty
        ? ref.watch(universalProfileControllerProvider(targetId))
        : null;
    final loggedInProfileAsync = ref.watch(currentUserProvider);
    final activeProfileAsync = ref.watch(activeProfileProvider);

    final resolvedProfileAsync = profile != null
        ? (profileFromController?.valueOrNull != null
            ? profileFromController!
            : AsyncValue.data(profile!))
        : (profileFromController?.valueOrNull != null
            ? profileFromController!
            : (activeProfileAsync.valueOrNull != null
                ? activeProfileAsync
                : (loggedInProfileAsync.valueOrNull != null
                    ? loggedInProfileAsync
                    : (profileFromController ?? const AsyncValue.data(null)))));

    final applications =
        ref.watch(verificationApplicationsProvider).valueOrNull ?? [];
    final preferences = ref.watch(appPreferencesProvider);

    return resolvedProfileAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('VERIFICATION',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
          backgroundColor: Colors.black,
        ),
        body: const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('VERIFICATION',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
          backgroundColor: Colors.black,
        ),
        body: Center(
            child: Text('$e', style: const TextStyle(color: Colors.red))),
      ),
      data: (rawProfile) {
        ProfileModel? effectiveUserProfile = rawProfile;
        if (effectiveUserProfile == null) {
          final profileList = ref.watch(profileListProvider).valueOrNull ?? [];
          if (targetId.isNotEmpty) {
            effectiveUserProfile = profileList.cast<ProfileModel?>().firstWhere(
              (p) => p?.id == targetId,
              orElse: () => null,
            );
          }
          effectiveUserProfile ??= this.profile;
        }

        if (effectiveUserProfile == null) {
          return Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: Text('VERIFICATION',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
              backgroundColor: Colors.black,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 48, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text(
                      'Profile Not Found',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Unable to resolve profile details for verification. Please retry or return to your profile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('RETRY LOADING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        if (targetId.isNotEmpty) {
                          ref.invalidate(universalProfileControllerProvider(targetId));
                        }
                        ref.read(profileListProvider.notifier).loadAllProfiles();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final effectiveStatus = _effectiveStatus(effectiveUserProfile, applications);
        final activeProfile = effectiveStatus != effectiveUserProfile.verificationStatus
            ? effectiveUserProfile.copyWith(verificationStatus: effectiveStatus)
            : effectiveUserProfile;

        final rawRole = activeProfile.role.trim();
        final roleLower = rawRole.toLowerCase();

        bool isCoach = roleLower == 'coach';
        bool isFederation = roleLower == 'federation' ||
            (roleLower.contains('federation') && !roleLower.contains('coach'));
        bool isBrand = roleLower == 'brand' ||
            (roleLower.contains('brand') && !roleLower.contains('federation'));

        String appBarTitle = 'VERIFICATION';
        if (isCoach) {
          appBarTitle = 'COACH ACCREDITATION';
        } else if (isFederation) {
          appBarTitle = 'FEDERATION VERIFICATION';
        } else if (isBrand) {
          appBarTitle = 'BRAND VERIFICATION';
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: Text(appBarTitle,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
            backgroundColor: Colors.black,
          ),
          body: () {
            if (isCoach) {
              return _buildCoachDashboard(
                  context, activeProfile, applications, preferences);
            } else if (isFederation) {
              return _buildFederationDashboard(
                  context, activeProfile, applications, preferences);
            } else if (isBrand) {
              return _buildBrandDashboard(
                  context, activeProfile, applications, preferences);
            }
            return _buildAthleteDashboard(
                context, activeProfile, applications, preferences);
          }(),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. ATHLETE DASHBOARD (Tiered Level Progression: Level 0–5)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildAthleteDashboard(
    BuildContext context,
    ProfileModel profile,
    List<Map<String, dynamic>> applications,
    dynamic preferences,
  ) {
    final level = profile.verificationLevel;
    final currentLevelData = _athleteLevels[level.clamp(0, 5)];
    final nextLevelData =
        level < 5 ? _athleteLevels[(level + 1).clamp(0, 5)] : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current badge card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(currentLevelData['color'] as int).withValues(alpha: 0.25),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Color(currentLevelData['color'] as int).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(currentLevelData['color'] as int).withValues(alpha: 0.15),
                  border: Border.all(
                      color: Color(currentLevelData['color'] as int), width: 2),
                ),
                child: Icon(currentLevelData['icon'] as IconData,
                    color: Color(currentLevelData['color'] as int), size: 30),
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
                            color: Color(currentLevelData['color'] as int),
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(profile.verificationStatus)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _statusColor(profile.verificationStatus)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel(profile.verificationStatus),
                        style: TextStyle(
                            color: _statusColor(profile.verificationStatus),
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

        // Level progress bar
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

        // Next badge requirements
        if (nextLevelData != null) ...[
          _sectionTitle('REQUIREMENTS FOR NEXT BADGE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(nextLevelData['icon'] as IconData,
                      color: Color(nextLevelData['color'] as int), size: 18),
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
                                          color: Colors.white60, fontSize: 12))),
                            ],
                          ),
                        )),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Apply action button
        _buildApplyButton(
          context: context,
          profile: profile,
          label: level == 0
              ? 'APPLY FOR VERIFICATION'
              : (level < 5
                  ? 'APPLY FOR LEVEL ${level + 1} (${_athleteLevels[(level + 1).clamp(0, 5)]['badge']})'
                  : 'ATHLETE FULLY VERIFIED'),
        ),

        // Rejection reason banner
        _buildRejectionBanner(profile),

        // Verification history
        _buildHistorySection(applications, preferences),

        // All level badges overview
        _sectionTitle('ALL BADGE LEVELS'),
        const SizedBox(height: 8),
        ..._athleteLevels.map((lvl) {
          final isUnlocked = level >= (lvl['level'] as int);
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? Color(lvl['color'] as int).withValues(alpha: 0.06)
                  : const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnlocked
                    ? Color(lvl['color'] as int).withValues(alpha: 0.2)
                    : const Color(0xFF262626),
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
                const Icon(Icons.lock_outlined, color: Colors.white24, size: 14),
            ]),
          );
        }),

        const SizedBox(height: 32),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. COACH DASHBOARD (Binary Legit Coach Accreditation — No 0-5 Levels)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildCoachDashboard(
    BuildContext context,
    ProfileModel profile,
    List<Map<String, dynamic>> applications,
    dynamic preferences,
  ) {
    final isVerified = profile.verified || profile.verificationStatus == 'approved';
    const badgeColor = 0xFF10B981; // Emerald green for Coach

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Coach Accreditation Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(badgeColor).withValues(alpha: isVerified ? 0.25 : 0.08),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Color(badgeColor).withValues(alpha: isVerified ? 0.4 : 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(badgeColor).withValues(alpha: 0.15),
                  border: Border.all(
                      color: Color(badgeColor), width: 2),
                ),
                child: const Icon(Icons.sports, color: Color(badgeColor), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COACH ACCREDITATION',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Verified Coach',
                        style: GoogleFonts.spaceGrotesk(
                            color: isVerified ? const Color(badgeColor) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(profile.verificationStatus)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _statusColor(profile.verificationStatus)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel(profile.verificationStatus),
                        style: TextStyle(
                            color: _statusColor(profile.verificationStatus),
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

        // Description Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(badgeColor), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVerified
                      ? 'Your coaching accreditation is verified and active. You have full scouting access and roster management authority on ATHELEOS.'
                      : 'Coach verification confirms your credentials as a legitimate trainer or team manager. Verified coaches can search athlete combine film, review benchmarks, and invite talent to camps.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Coach Accreditation Criteria Card
        _sectionTitle('COACH ACCREDITATION CRITERIA'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              _buildCriteriaItem(
                Icons.card_membership_outlined,
                'Coaching License / Degree',
                'State or National sports council coaching license, university degree, or international coaching certification.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.stadium_outlined,
                'Academy or Club Affiliation',
                'Official letter or proof confirming active coaching role at a school, college, academy, or competitive sports club.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.timeline_outlined,
                'Experience & Athlete Track Record',
                'Documented coaching background, teams trained, and past tournament appearances.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.badge_outlined,
                'Government / Sports Federation ID',
                'Valid government identity card or sports association accreditation pass.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Apply action button
        _buildApplyButton(
          context: context,
          profile: profile,
          label: isVerified
              ? 'COACH VERIFIED'
              : (profile.verificationStatus == 'rejected'
                  ? 'RE-APPLY FOR ACCREDITATION'
                  : 'APPLY FOR COACH ACCREDITATION'),
        ),

        // Rejection reason banner
        _buildRejectionBanner(profile),

        // Verified Coach Privileges
        _sectionTitle('VERIFIED COACH PRIVILEGES'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              _buildPrivilegeItem(Icons.verified, 'Official Verified Coach Badge displayed on profile'),
              _buildPrivilegeItem(Icons.analytics_outlined, 'Access to verified combine benchmarks & athlete highlight film'),
              _buildPrivilegeItem(Icons.event_available, 'Sanctioned permission to host official camps & showcases'),
              _buildPrivilegeItem(Icons.mail_outline, 'Direct priority outreach messaging to prospective athletes'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Verification history
        _buildHistorySection(applications, preferences),

        const SizedBox(height: 32),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. FEDERATION DASHBOARD (Governing Body Verification — No 0-5 Levels)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildFederationDashboard(
    BuildContext context,
    ProfileModel profile,
    List<Map<String, dynamic>> applications,
    dynamic preferences,
  ) {
    final isVerified = profile.verified || profile.verificationStatus == 'approved';
    const badgeColor = 0xFFE5A93B; // Regal Gold for Federation

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Federation Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(badgeColor).withValues(alpha: isVerified ? 0.25 : 0.08),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Color(badgeColor).withValues(alpha: isVerified ? 0.4 : 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(badgeColor).withValues(alpha: 0.15),
                  border: Border.all(
                      color: Color(badgeColor), width: 2),
                ),
                child: const Icon(Icons.account_balance, color: Color(badgeColor), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GOVERNING BODY ACCREDITATION',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Verified Federation',
                        style: GoogleFonts.spaceGrotesk(
                            color: isVerified ? const Color(badgeColor) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(profile.verificationStatus)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _statusColor(profile.verificationStatus)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel(profile.verificationStatus),
                        style: TextStyle(
                            color: _statusColor(profile.verificationStatus),
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

        // Description Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.gavel_outlined, color: Color(badgeColor), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVerified
                      ? 'Your sports federation is officially verified. You have governing authority to sanction events, manage rosters, and post state/national directives on ATHELEOS.'
                      : 'Federation verification grants legal sports governing bodies, associations, and councils authority to sanction official tournaments, certify competition records, and administer athlete rosters.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Federation Verification Criteria Card
        _sectionTitle('FEDERATION GOVERNANCE CRITERIA'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              _buildCriteriaItem(
                Icons.assignment_outlined,
                'Registration Certificate',
                'Official certificate of registration under Societies, Trust, or Non-profit Companies Act, or Sports Authority notification.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.menu_book_outlined,
                'Constitution & Bye-Laws',
                'Current ratified sports constitution, articles of association, and tournament rulebook.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.handshake_outlined,
                'Recognition & Affiliation Proof',
                'Official affiliation letter with National Olympic Committee, Ministry of Sports, or Continental/International Sport Federation.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.groups_outlined,
                'Executive Committee & Office Bearers',
                'Registered list of elected president, secretary general, and governing committee members with latest election record.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.verified_outlined,
                'Authorized Representative Letter',
                'Signed authorization letter on federation letterhead authorizing this account representative.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Apply action button
        _buildApplyButton(
          context: context,
          profile: profile,
          label: isVerified
              ? 'FEDERATION VERIFIED'
              : (profile.verificationStatus == 'rejected'
                  ? 'RE-APPLY FOR VERIFICATION'
                  : 'APPLY FOR FEDERATION VERIFICATION'),
        ),

        // Rejection reason banner
        _buildRejectionBanner(profile),

        // Verified Federation Privileges
        _sectionTitle('GOVERNING BODY PRIVILEGES'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              _buildPrivilegeItem(Icons.verified, 'Official Verified Federation Crest displayed across ATHELEOS'),
              _buildPrivilegeItem(Icons.emoji_events_outlined, 'Power to sanction state/national tournaments, meets & combines'),
              _buildPrivilegeItem(Icons.how_to_reg, 'Verify & endorse official athlete rosters and record certificates'),
              _buildPrivilegeItem(Icons.campaign_outlined, 'Broadcast official directives & circulars to all affiliated participants'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Verification history
        _buildHistorySection(applications, preferences),

        const SizedBox(height: 32),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. BRAND DASHBOARD (Business & Sponsorship Verification)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildBrandDashboard(
    BuildContext context,
    ProfileModel profile,
    List<Map<String, dynamic>> applications,
    dynamic preferences,
  ) {
    final isVerified = profile.verified || profile.verificationStatus == 'approved';
    const badgeColor = 0xFF38BDF8; // Light blue / Cyan for Brand

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Brand Status Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(badgeColor).withValues(alpha: isVerified ? 0.25 : 0.08),
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Color(badgeColor).withValues(alpha: isVerified ? 0.4 : 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(badgeColor).withValues(alpha: 0.15),
                  border: Border.all(color: Color(badgeColor), width: 2),
                ),
                child: const Icon(Icons.business_center, color: Color(badgeColor), size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CORPORATE BRAND VERIFICATION',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('Verified Brand',
                        style: GoogleFonts.spaceGrotesk(
                            color: isVerified ? const Color(badgeColor) : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(profile.verificationStatus)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _statusColor(profile.verificationStatus)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel(profile.verificationStatus),
                        style: TextStyle(
                            color: _statusColor(profile.verificationStatus),
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

        // Description Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.storefront_outlined, color: Color(badgeColor), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isVerified
                      ? 'Your brand profile is verified. You can launch athlete sponsorships, create branded combines, and issue talent endorsement contracts.'
                      : 'Brand verification authorizes companies, apparel labels, and sponsors to coordinate sports combine endorsements and contract athletic talent.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Brand Verification Criteria Card
        _sectionTitle('BRAND VERIFICATION CRITERIA'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF262626)),
          ),
          child: Column(
            children: [
              _buildCriteriaItem(
                Icons.corporate_fare,
                'Business Registration Certificate',
                'Official Certificate of Incorporation, GST/Tax Registration, or commercial license.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.copyright_outlined,
                'Trademark / Brand Ownership',
                'Registered trademark or proof of brand domain ownership.',
              ),
              const Divider(color: Colors.white10, height: 20),
              _buildCriteriaItem(
                Icons.contact_mail_outlined,
                'Corporate Domain & Authorized Agent',
                'Official corporate email domain and authorization letter.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Apply action button
        _buildApplyButton(
          context: context,
          profile: profile,
          label: isVerified
              ? 'BRAND VERIFIED'
              : (profile.verificationStatus == 'rejected'
                  ? 'RE-APPLY FOR VERIFICATION'
                  : 'APPLY FOR BRAND VERIFICATION'),
        ),

        // Rejection reason banner
        _buildRejectionBanner(profile),

        // Verification history
        _buildHistorySection(applications, preferences),

        const SizedBox(height: 32),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SHARED REUSABLE COMPONENTS
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildApplyButton({
    required BuildContext context,
    required ProfileModel profile,
    required String label,
  }) {
    final status = profile.verificationStatus;
    final isAthlete = profile.role.trim().toLowerCase() == 'athlete';
    final isMaxAthlete = isAthlete && profile.verificationLevel >= 5 && status == 'approved';
    final isFullyVerified = (!isAthlete && status == 'approved') || isMaxAthlete;

    if (isFullyVerified) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerificationDialog(profile: profile),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.greenAccent, size: 16),
              ],
            ),
          ),
        ),
      );
    }

    if (status == 'pending' || status == 'underReview') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerificationDialog(profile: profile),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.amberAccent),
                ),
                const SizedBox(width: 10),
                Text('APPLICATION UNDER REVIEW (VIEW DETAILS)',
                    style: GoogleFonts.spaceGrotesk(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Colors.amberAccent, size: 16),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerificationDialog(profile: profile),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 16, color: Colors.black),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionBanner(ProfileModel profile) {
    if (profile.verificationStatus != 'rejected' ||
        profile.verificationRejectedReason.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
    List<Map<String, dynamic>> applications,
    dynamic preferences,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: Text(
                submittedAt == null
                    ? _statusLabel(status)
                    : '${_statusLabel(status)} · ${formatSettingsDateTime(submittedAt.toDate(), preferences)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCriteriaItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 3),
              Text(description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivilegeItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
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
