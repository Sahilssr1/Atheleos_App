import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/messaging_access_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import '../controllers/profile_controller.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/settings_screen.dart';
import 'profile_header.dart';
import 'profile_posts_grid.dart';
import 'profile_share_helper.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

const _gold = AppTheme.primaryColor;
const _hairline = Color(0x1AFFFFFF);

/// Single profile layout for every role, mirroring the website's
/// `/profile/[username]` page section by section.
class WebsiteProfileView extends ConsumerWidget {
  final ProfileModel profile;

  const WebsiteProfileView({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = profile.id == ref.watch(loggedInUserIdProvider);
    final role = profile.role.isEmpty ? 'Athlete' : profile.role;

    void openEditProfile() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
        );

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProfileCoverHeader(
            profile: profile,
            onChangeCover: isOwner ? openEditProfile : null,
            onChangeAvatar: isOwner ? openEditProfile : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _Identity(profile: profile),
                const SizedBox(height: 20),
                ProfileStatsRow(profile: profile),
                const SizedBox(height: 20),
                if (isOwner)
                  _OwnerActions(profile: profile, role: role, onEdit: openEditProfile)
                else
                  _VisitorActions(profile: profile),
                const SizedBox(height: 20),
                _Bio(profile: profile, role: role),
                ..._roleSections(role),
                if (profile.statistics.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _Statistics(stats: profile.statistics),
                ],
                if (_hasLinks) ...[
                  const SizedBox(height: 24),
                  _SocialLinks(profile: profile),
                ],
                const SizedBox(height: 8),
                ProfilePostsGrid(userId: profile.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasLinks =>
      profile.website.isNotEmpty ||
      ['Instagram', 'Twitter', 'TikTok']
          .any((k) => (profile.socialLinks[k] ?? '').isNotEmpty);

  List<Widget> _roleSections(String role) {
    final p = profile;
    final sections = <Widget>[];

    void section(String title, List<Widget> children) {
      final visible = children.whereType<_Detail>().where((d) => d.value.isNotEmpty);
      if (children.isEmpty || (children.every((c) => c is _Detail) && visible.isEmpty)) {
        return;
      }
      sections
        ..add(const SizedBox(height: 24))
        ..add(_SectionTitle(title))
        ..addAll(children);
    }

    switch (role) {
      case 'Coach':
        section('COACHING STATUS', [
          _Detail(AthIcons.trophy, 'Sport Specialist', p.sport),
          _Detail(AthIcons.academicCap, 'Title', p.primaryPosition),
          _Detail(AthIcons.buildingLibrary, 'Academy Affiliation', p.clubOrAcademy),
          if (p.experienceYears != null)
            _Detail(AthIcons.user, 'Experience', '${p.experienceYears} Years Active'),
        ]);
        if (p.certifications.isNotEmpty) {
          section('PROFESSIONAL CERTIFICATIONS', [_BulletList(p.certifications)]);
        }
        if (p.achievements.isNotEmpty) {
          section('COACHING MILESTONES', [_BulletList(p.achievements)]);
        }
      case 'Brand':
      case 'Federation':
        final isBrand = role == 'Brand';
        section('ORGANIZATION CLASSIFICATION', [
          _Detail(AthIcons.buildingStorefront,
              isBrand ? 'Official Brand Name' : 'Federation Board Name', p.organizationName ?? ''),
          _Detail(AthIcons.buildingLibrary, isBrand ? 'Industry Focus' : 'Focus Domain',
              p.industry ?? ''),
          _Detail(AthIcons.globeAlt, isBrand ? 'Official Website' : 'Official Domain', p.website),
        ]);
        if (p.achievements.isNotEmpty) {
          section(
            isBrand ? 'ATHLETIC SPONSORSHIPS & MILESTONES' : 'FEDERATION DIRECTIVES & MILESTONES',
            [_BulletList(p.achievements)],
          );
        }
      default:
        if (p.sport.isNotEmpty || p.primaryPosition.isNotEmpty) {
          section('ATHLETIC CLASSIFICATION', [
            _Detail(AthIcons.trophy, 'Sport', p.sport),
            _Detail(AthIcons.user, 'Primary Position', p.primaryPosition),
            _Detail(AthIcons.buildingLibrary, 'Club / High School Team', p.clubOrAcademy),
          ]);
        }
        if (p.achievements.isNotEmpty) {
          section('ATHLETIC ACCOMPLISHMENTS', [_BulletList(p.achievements)]);
        }
        if ((p.resumeFileName ?? '').isNotEmpty) {
          section('ATHLETIC RESUME DOCUMENT', [_ResumeCard(fileName: p.resumeFileName!)]);
        }
    }
    return sections;
  }
}

class _Identity extends StatelessWidget {
  final ProfileModel profile;

  const _Identity({required this.profile});

  @override
  Widget build(BuildContext context) {
    final place = [profile.city, profile.state].where((s) => s.isNotEmpty).join(', ');
    final meta = [profile.sport, place].where((s) => s.isNotEmpty).join(' · ');
    final name = profile.name.isNotEmpty ? profile.name : profile.username;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ),
            if (profile.verified) ...[
              const SizedBox(width: 6),
              const Icon(AthIcons.checkBadgeSolid, size: 16, color: _gold),
            ],
          ],
        ),
        Text(
          '@${profile.username}',
          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(AthIcons.mapPin, size: 14, color: _gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool filled;

  const _PillButton({required this.label, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _gold : Colors.transparent,
      shape: StadiumBorder(
        side: filled ? BorderSide.none : const BorderSide(color: Color(0x33FFFFFF)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: filled ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCircle extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  const _ShareCircle({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(side: BorderSide(color: Color(0x26FFFFFF))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(AthIcons.share, size: 16, color: color),
        ),
      ),
    );
  }
}

class _OwnerActions extends ConsumerWidget {
  final ProfileModel profile;
  final String role;
  final VoidCallback onEdit;

  const _OwnerActions({required this.profile, required this.role, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = profile.verificationStatus;
    final verificationLabel = profile.verified || status == 'approved'
        ? 'Verified profile'
        : (status == 'pending' || status == 'underReview')
            ? 'Verification in progress'
            : 'Profile verification';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _PillButton(label: 'EDIT PROFILE', filled: true, onTap: onEdit)),
            const SizedBox(width: 8),
            _ShareCircle(
              color: _gold,
              onTap: () => showProfileShareDialog(context, profile, ref),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen(profile: profile)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(AthIcons.checkBadge, size: 16, color: _gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    verificationLabel,
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                const Text('Settings', style: TextStyle(fontSize: 12, color: _gold)),
              ],
            ),
          ),
        ),
        if (role == 'Athlete') ...[
          const SizedBox(height: 12),
          _PerformanceCard(profile: profile),
        ],
      ],
    );
  }
}

class _VisitorActions extends ConsumerWidget {
  final ProfileModel profile;

  const _VisitorActions({required this.profile});

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    final access = await MessagingAccessService().check(
      senderId: ref.read(loggedInUserIdProvider),
      receiverId: profile.id,
    );
    if (!context.mounted) return;
    if (!access.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(access.reason ?? 'Follow first to send a message.'),
          action: access.reason?.toLowerCase().contains('follow') == true
              ? SnackBarAction(
                  label: 'FOLLOW',
                  textColor: _gold,
                  onPressed: () => ref
                      .read(universalProfileControllerProvider(profile.id).notifier)
                      .toggleFollow(),
                )
              : null,
        ),
      );
      return;
    }
    context.push('/chat/room?receiverId=${Uri.encodeQueryComponent(profile.id)}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _PillButton(
            label: profile.isFollowing ? 'FOLLOWING' : 'FOLLOW',
            filled: !profile.isFollowing,
            onTap: () => ref
                .read(universalProfileControllerProvider(profile.id).notifier)
                .toggleFollow(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _PillButton(label: 'MESSAGE', onTap: () => _message(context, ref))),
        const SizedBox(width: 8),
        _ShareCircle(
          color: Colors.white.withValues(alpha: 0.7),
          onTap: () => showProfileShareDialog(context, profile, ref),
        ),
      ],
    );
  }
}

class _PerformanceCard extends ConsumerWidget {
  final ProfileModel profile;

  const _PerformanceCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = profile.verificationRequestDetails['performanceMetrics'];
    final rating = metrics is Map ? (metrics['rating'] as String? ?? '') : '';

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _hairline))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Label('PERFORMANCE'),
                const SizedBox(height: 4),
                Text(
                  rating.isEmpty ? 'Not calculated' : rating,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _gold,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _showMetricsSheet(context, ref, profile),
            child: Text(
              'Update',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String _ratingFromScore(double score) {
  if (score >= 550) return 'Elite';
  if (score >= 450) return 'Diamond';
  if (score >= 350) return 'Platinum';
  if (score >= 250) return 'Gold';
  if (score >= 150) return 'Silver';
  return 'Bronze';
}

void _showMetricsSheet(BuildContext context, WidgetRef ref, ProfileModel profile) {
  final raw = profile.verificationRequestDetails['performanceMetrics'];
  final current = raw is Map ? raw : const {};
  final weight = TextEditingController(
      text: '${current['weight'] ?? profile.weight?.toStringAsFixed(0) ?? 75}');
  final bench = TextEditingController(text: '${current['benchPress'] ?? 75}');
  final sprint = TextEditingController(text: '${current['sprintTime'] ?? 12.5}');
  final grip = TextEditingController(text: '${current['gripStrength'] ?? 45}');

  Widget field(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14, color: Colors.white),
          decoration: const InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Color(0x66000000),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      String error = '';
      return StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'PERFORMANCE METRICS',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _gold),
              ),
              const SizedBox(height: 4),
              Text(
                'Provide your sport-specific performance inputs to calculate your private portfolio rating standard.',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: field('Body Weight (kg)', weight)),
                const SizedBox(width: 12),
                Expanded(child: field('Bench Press Lift (kg)', bench)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: field('100m Sprint Time (sec)', sprint)),
                const SizedBox(width: 12),
                Expanded(child: field('Grip Strength (kg)', grip)),
              ]),
              if (error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(error, style: const TextStyle(fontSize: 12, color: AppTheme.errorColor)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final w = double.tryParse(weight.text);
                  final b = double.tryParse(bench.text);
                  final s = double.tryParse(sprint.text);
                  final g = double.tryParse(grip.text);
                  if (w == null || b == null || s == null || g == null || w <= 0) {
                    setState(() => error = 'Required');
                    return;
                  }
                  final rating = _ratingFromScore((b / w) * 100 + (15 - s) * 50 + g * 2);
                  final details = Map<String, dynamic>.from(profile.verificationRequestDetails)
                    ..['performanceMetrics'] = {
                      'weight': w,
                      'benchPress': b,
                      'sprintTime': s,
                      'gripStrength': g,
                      'rating': rating,
                    };
                  final updated = profile.copyWith(verificationRequestDetails: details);
                  ref.read(profileListProvider.notifier).updateProfile(updated);
                  ref.read(universalProfileControllerProvider(profile.id).notifier).syncProfile(updated);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Performance standards rating updated to "$rating"!')),
                  );
                },
                child: const Text('CALCULATE & SAVE RATING'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Close',
                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: _gold,
      ),
    );
  }
}

class _Bio extends StatelessWidget {
  final ProfileModel profile;
  final String role;

  const _Bio({required this.profile, required this.role});

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'Coach' => 'COACHING MISSION & BIOGRAPHY',
      'Brand' => 'BRAND MISSION & OVERVIEW',
      'Federation' => 'FEDERATION MISSION & CONSTITUTION',
      _ => 'ATHLETIC BIOGRAPHY',
    };
    final empty = switch (role) {
      'Brand' => 'No description added yet.',
      'Federation' => 'No mission statement added yet.',
      _ => 'No bio added yet.',
    };

    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _hairline))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          const SizedBox(height: 8),
          MentionText(
            text: profile.bio.isEmpty ? empty : profile.bio,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: _gold,
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Detail(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0FFFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
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

class _BulletList extends StatelessWidget {
  final List<String> items;

  const _BulletList(this.items);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0AFFFFFF)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('★', style: TextStyle(fontSize: 14, height: 1.1, color: _gold)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  final String fileName;

  const _ResumeCard({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0AFFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(AthIcons.documentArrowDown, size: 24, color: Color(0xFFF87171)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Academic & Athletic Record PDF',
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
          const Icon(AthIcons.documentArrowDown, size: 20, color: _gold),
        ],
      ),
    );
  }
}

class _Statistics extends StatelessWidget {
  final List<StatEntry> stats;

  const _Statistics({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'STATISTICS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: _gold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.length}',
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _gold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x0DFFFFFF)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < stats.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: i == stats.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          stats[i].name,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        stats[i].displayValue,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SocialLinks extends StatelessWidget {
  final ProfileModel profile;

  const _SocialLinks({required this.profile});

  static const _hosts = {
    'Instagram': 'https://instagram.com/',
    'Twitter': 'https://twitter.com/',
    'TikTok': 'https://tiktok.com/@',
  };

  Widget _chip(String url, Widget child) {
    return Material(
      color: const Color(0xFF121212),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x0AFFFFFF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 12, color: Colors.white),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final site = profile.website;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (site.isNotEmpty)
          _chip(
            site.startsWith('http') ? site : 'https://$site',
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AthIcons.globeAlt, size: 14, color: _gold),
                SizedBox(width: 6),
                Text('Website Link'),
              ],
            ),
          ),
        for (final entry in _hosts.entries)
          if ((profile.socialLinks[entry.key] ?? '').isNotEmpty)
            _chip(
              '${entry.value}${profile.socialLinks[entry.key]!.replaceAll('@', '')}',
              Text('${entry.key} ${profile.socialLinks[entry.key]}'),
            ),
      ],
    );
  }
}
