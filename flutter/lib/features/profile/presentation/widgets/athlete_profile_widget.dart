import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import '../screens/edit_profile_screen.dart';
import 'profile_posts_grid.dart';
import '../screens/settings_screen.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/services/messaging_access_service.dart';
import 'profile_share_helper.dart';
import '../screens/following_list_screen.dart';

class AthleteProfileWidget extends ConsumerWidget {
  final ProfileModel profile;

  const AthleteProfileWidget({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedInUserId = ref.watch(loggedInUserIdProvider);
    final isOwner = profile.id == loggedInUserId;
    final preferences = ref.watch(appPreferencesProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cover Photo & Profile Picture Stack
          _buildHeaderStack(context, profile, isOwner, ref),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // 2. Name, Username & Verification Badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                profile.name,
                                style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                              if (profile.verified) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.verified,
                                    size: 22, color: AppTheme.primaryColor),
                                if (profile.verificationBadge.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppTheme.primaryColor
                                              .withOpacity(0.3),
                                          width: 0.5),
                                    ),
                                    child: Text(
                                      profile.verificationBadge.toUpperCase(),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                          Text(
                            '@${profile.username}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Role Badge Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        border:
                            Border.all(color: AppTheme.primaryColor, width: 1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.role.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Location detail
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.city}, ${profile.state}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Stats Bar
                _buildStatsBar(context, profile),
                const SizedBox(height: 20),

                // 4. Action Buttons (Follow / Unfollow / Message / Share)
                _buildActionButtons(context, profile, isOwner, ref),
                const SizedBox(height: 24),

                if (profile.verified &&
                    profile.verificationBadge.isNotEmpty) ...[
                  _buildVerifiedCredentialsCard(profile),
                  const SizedBox(height: 24),
                ],

                if (isOwner) ...[
                  _buildPrivatePerformanceRatingCard(context, profile, ref),
                  const SizedBox(height: 24),
                ],

                // 5. Bio Block
                _buildSectionLabel('ATHLETIC BIOGRAPHY'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: MentionText(
                    text:
                        profile.bio.isEmpty ? 'No bio added yet.' : profile.bio,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),

                if (profile.email.isNotEmpty ||
                    profile.phoneNumber.isNotEmpty ||
                    profile.dateOfBirth.isNotEmpty ||
                    profile.height != null ||
                    profile.weight != null ||
                    profile.personalNotes.isNotEmpty) ...[
                  _buildSectionLabel('PERSONAL DETAILS'),
                  const SizedBox(height: 8),
                  if (profile.email.isNotEmpty)
                    _buildDetailTile(
                        Icons.email_outlined, 'Email', profile.email),
                  if (profile.phoneNumber.isNotEmpty)
                    _buildDetailTile(
                        Icons.phone_outlined, 'Phone', profile.phoneNumber),
                  if (profile.dateOfBirth.isNotEmpty)
                    _buildDetailTile(Icons.cake_outlined, 'Date of Birth',
                        profile.dateOfBirth),
                  if (profile.height != null)
                    _buildDetailTile(
                      Icons.height,
                      'Height',
                      preferences.units == 'imperial'
                          ? '${(profile.height! / 2.54).toStringAsFixed(1)} in'
                          : '${profile.height!.toStringAsFixed(0)} cm',
                    ),
                  if (profile.weight != null)
                    _buildDetailTile(
                      Icons.monitor_weight_outlined,
                      'Weight',
                      preferences.units == 'imperial'
                          ? '${(profile.weight! * 2.20462).toStringAsFixed(1)} lb'
                          : '${profile.weight!.toStringAsFixed(1)} kg',
                    ),
                  if (profile.personalNotes.isNotEmpty)
                    _buildDetailTile(Icons.notes_outlined, 'Personal Notes',
                        profile.personalNotes),
                  const SizedBox(height: 24),
                ],

                // 6. Athletic Classification fields
                if (profile.sport.isNotEmpty ||
                    profile.primaryPosition.isNotEmpty) ...[
                  _buildSectionLabel('ATHLETIC CLASSIFICATION'),
                  const SizedBox(height: 8),
                  _buildDetailTile(Icons.sports, 'Sport', profile.sport),
                  _buildDetailTile(Icons.sports_soccer, 'Primary Position',
                      profile.primaryPosition),
                  if (profile.clubOrAcademy.isNotEmpty)
                    _buildDetailTile(Icons.store, 'Club / High School Team',
                        profile.clubOrAcademy),
                  const SizedBox(height: 24),
                ],

                // 7. Athletic Accomplishments
                if (profile.achievements.isNotEmpty) ...[
                  _buildSectionLabel('ATHLETIC ACCOMPLISHMENTS'),
                  const SizedBox(height: 8),
                  ...profile.achievements
                      .map((ach) => _buildBulletItem(ach))
                      .toList(),
                  const SizedBox(height: 24),
                ],

                // 8. Resume Document
                if (profile.resumeFileName != null &&
                    profile.resumeFileName!.isNotEmpty) ...[
                  _buildSectionLabel('ATHLETIC RESUME DOCUMENT'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.picture_as_pdf,
                          color: Colors.redAccent),
                      title: Text(
                        profile.resumeFileName!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.white),
                      ),
                      subtitle: const Text('Academic & Athletic Record PDF',
                          style:
                              TextStyle(fontSize: 10, color: Colors.white38)),
                      trailing: const Icon(Icons.download_rounded,
                          color: AppTheme.primaryColor),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Simulating download of ${profile.resumeFileName}...'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // 9. Statistics section
                if (profile.statistics.isNotEmpty) ...[
                  _buildStatisticsDisplay(profile.statistics),
                  const SizedBox(height: 24),
                ],

                // 10. Interactive Posts Grid
                ProfilePostsGrid(userId: profile.id),
                const SizedBox(height: 24),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStack(
      BuildContext context, ProfileModel profile, bool isOwner, WidgetRef ref) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            image: profile.coverUrl.trim().isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(profile.coverUrl.trim()),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.8)
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // Floating Profile Avatar
        Positioned(
          bottom: -40,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ],
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF141414),
              backgroundImage: profile.avatarUrl.trim().isNotEmpty
                  ? NetworkImage(profile.avatarUrl.trim())
                  : null,
              child: profile.avatarUrl.trim().isEmpty
                  ? const Icon(
                      Icons.person_outline,
                      size: 48,
                      color: Colors.white38,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(BuildContext context, ProfileModel profile) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSingleStat(profile.followersCount, 'Followers'),
          _buildDivider(),
          if (profile.showFollowing) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FollowingListScreen(
                      userId: profile.id,
                      userName: profile.name,
                    ),
                  ),
                );
              },
              child: _buildSingleStat(profile.followingCount, 'Following'),
            ),
            _buildDivider(),
          ],
          _buildSingleStat(profile.postsCount, 'Posts'),
        ],
      ),
    );
  }

  Widget _buildSingleStat(int val, String label) {
    String formattedVal = val.toString();
    if (val >= 1000) {
      formattedVal = '${(val / 1000).toStringAsFixed(1)}K';
    }
    return Column(
      children: [
        Text(
          formattedVal,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 9,
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.08),
    );
  }

  Widget _buildActionButtons(
      BuildContext context, ProfileModel profile, bool isOwner, WidgetRef ref) {
    if (isOwner) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit, size: 14, color: Colors.black),
                  label: const Text(
                    'EDIT PROFILE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => EditProfileScreen(profile: profile)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.share_outlined,
                      color: AppTheme.primaryColor, size: 18),
                  onPressed: () => _shareProfileDialog(context, profile, ref),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildVerificationNotice(context, profile),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: profile.isFollowing
                    ? const Color(0xFF1E1E1E)
                    : AppTheme.primaryColor,
                foregroundColor:
                    profile.isFollowing ? Colors.white : Colors.black,
              ),
              icon: Icon(profile.isFollowing ? Icons.check : Icons.person_add,
                  size: 16),
              label: Text(profile.isFollowing ? 'FOLLOWING' : 'FOLLOW'),
              onPressed: () async {
                await ref
                    .read(
                        universalProfileControllerProvider(profile.id).notifier)
                    .toggleFollow();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(profile.isFollowing
                        ? 'Unfollowed ${profile.name}'
                        : 'You are now following ${profile.name}!'),
                    backgroundColor: AppTheme.primaryColor,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.message_outlined,
                  size: 16, color: Colors.white),
              label: const Text('MESSAGE'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                final access = await MessagingAccessService().check(
                  senderId: ref.read(loggedInUserIdProvider),
                  receiverId: profile.id,
                );
                if (!access.allowed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(access.reason ?? 'Follow first to send a message.'),
                      backgroundColor: const Color(0xFF1E1E1E),
                      action: access.reason?.toLowerCase().contains('follow') == true
                          ? SnackBarAction(
                              label: 'FOLLOW',
                              textColor: AppTheme.primaryColor,
                              onPressed: () {
                                ref.read(universalProfileControllerProvider(profile.id).notifier).toggleFollow();
                              },
                            )
                          : null,
                    ),
                  );
                  return;
                }
                context.push(
                    '/chat/room?receiverId=${Uri.encodeQueryComponent(profile.id)}');
              },
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white70),
              onPressed: () => _shareProfileDialog(context, profile, ref),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildVerificationNotice(BuildContext context, ProfileModel profile) {
    final bool isVerified =
        profile.verified || profile.verificationStatus == 'approved';
    final bool isPending = profile.verificationStatus == 'pending' ||
        profile.verificationStatus == 'underReview';

    final String title;
    final String subtitle;
    final IconData icon;
    final Color accentColor;

    if (isVerified) {
      title = 'Verified Profile';
      subtitle =
          'You can apply for next-tier badge upgrades or manage credentials in Settings.';
      icon = Icons.verified;
      accentColor = AppTheme.primaryColor;
    } else if (isPending) {
      title = 'Verification In Progress';
      subtitle =
          'Your application is under review. You can track your status in Settings.';
      icon = Icons.hourglass_top_rounded;
      accentColor = Colors.amber;
    } else {
      title = 'Profile Verification & Badges';
      subtitle =
          'You can apply for profile verification and badge upgrades from Settings.';
      icon = Icons.verified_outlined;
      accentColor = AppTheme.primaryColor;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsScreen(profile: profile)),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF131B2A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios,
                  size: 11, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _shareProfileDialog(
      BuildContext context, ProfileModel profile, WidgetRef ref) {
    showProfileShareDialog(context, profile, ref);
  }

  Widget _buildSectionLabel(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontWeight: FontWeight.bold,
        fontSize: 11,
        color: AppTheme.primaryColor,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white38,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBulletItem(String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.star_border, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────
  // Statistics display — shared by all profile widget variants
  // ────────────────────────────────────────────────────────────────────

  Widget _buildStatisticsDisplay(List<StatEntry> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header row
        Row(
          children: [
            Text(
              'STATISTICS',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: AppTheme.primaryColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${stats.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Stat rows card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: stats.asMap().entries.map((entry) {
              final i = entry.key;
              final stat = entry.value;
              return _buildStatDisplayRow(stat, isLast: i == stats.length - 1);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDisplayRow(StatEntry stat, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: Row(
        children: [
          // Stat name
          Expanded(
            child: Text(
              stat.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),

          // Dotted leader line
          Expanded(
            flex: 0,
            child: SizedBox(
              width: 60,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dotCount = (constraints.maxWidth / 5).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      dotCount,
                      (_) => const Text(
                        '.',
                        style: TextStyle(color: Colors.white24, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Value
          Text(
            stat.displayValue,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedCredentialsCard(ProfileModel profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.verificationBadge.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verified by Platform',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
                if (profile.verificationDate.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Verification Date: ${profile.verificationDate}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivatePerformanceRatingCard(
      BuildContext context, ProfileModel profile, WidgetRef ref) {
    final metrics = profile.verificationRequestDetails['performanceMetrics']
        as Map<String, dynamic>?;
    final rating = metrics?['rating'] as String? ?? 'Not Calculated';
    final weight =
        metrics?['weight']?.toString() ?? profile.weight?.toString() ?? '75';
    final bench = metrics?['benchPress']?.toString() ?? '75';
    final sprint = metrics?['sprintTime']?.toString() ?? '12.5';
    final grip = metrics?['gripStrength']?.toString() ?? '45';

    Color ratingColor = Colors.white54;
    switch (rating) {
      case 'Bronze':
        ratingColor = Colors.brown;
        break;
      case 'Silver':
        ratingColor = Colors.grey;
        break;
      case 'Gold':
        ratingColor = Colors.amber;
        break;
      case 'Platinum':
        ratingColor = Colors.tealAccent;
        break;
      case 'Diamond':
        ratingColor = Colors.lightBlueAccent;
        break;
      case 'Elite':
        ratingColor = AppTheme.primaryColor;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.white38, size: 18),
              const SizedBox(width: 8),
              Text(
                'PRIVATE PERFORMANCE ANALYSIS (OWNER ONLY)',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('PRIVATE',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Calculated Performance Level:',
                        style: TextStyle(fontSize: 11, color: Colors.white54)),
                    const SizedBox(height: 4),
                    Text(
                      rating.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: ratingColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => _showRatingMetricsSheet(
                    context, profile, ref, weight, bench, sprint, grip),
                child: const Text('Update Metrics',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              )
            ],
          ),
          if (metrics != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricSnippet('Weight', '$weight kg'),
                _buildMetricSnippet('Bench Press', '$bench kg'),
                _buildMetricSnippet('Sprint 100m', '$sprint s'),
                _buildMetricSnippet('Grip Strength', '$grip kg'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Disclaimer: This rating is calculated using self-reported performance data and is not verified by the platform.',
            style: TextStyle(
                fontSize: 9,
                color: Colors.white24,
                fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSnippet(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70)),
      ],
    );
  }

  void _showRatingMetricsSheet(
    BuildContext context,
    ProfileModel profile,
    WidgetRef ref,
    String initWeight,
    String initBench,
    String initSprint,
    String initGrip,
  ) {
    final weightController = TextEditingController(text: initWeight);
    final benchController = TextEditingController(text: initBench);
    final sprintController = TextEditingController(text: initSprint);
    final gripController = TextEditingController(text: initGrip);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFORMANCE METRICS',
                  style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppTheme.primaryColor),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Provide your sport-specific performance inputs to calculate your private portfolio rating standard.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Body Weight (kg)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: benchController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Bench Press Lift (kg)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: sprintController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: '100m Sprint Time (sec)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: gripController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Grip Strength (kg)'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      final w = double.tryParse(weightController.text) ?? 75.0;
                      final b = double.tryParse(benchController.text) ?? 75.0;
                      final s = double.tryParse(sprintController.text) ?? 12.5;
                      final g = double.tryParse(gripController.text) ?? 45.0;

                      // Score calculation logic
                      final score = (b / w) * 100 + (15.0 - s) * 50 + g * 2;
                      String rating = 'Bronze';
                      if (score >= 550)
                        rating = 'Elite';
                      else if (score >= 450)
                        rating = 'Diamond';
                      else if (score >= 350)
                        rating = 'Platinum';
                      else if (score >= 250)
                        rating = 'Gold';
                      else if (score >= 150) rating = 'Silver';

                      final updatedDetails = Map<String, dynamic>.from(
                          profile.verificationRequestDetails);
                      updatedDetails['performanceMetrics'] = {
                        'weight': w,
                        'benchPress': b,
                        'sprintTime': s,
                        'gripStrength': g,
                        'rating': rating,
                      };

                      final updatedProfile = profile.copyWith(
                        verificationRequestDetails: updatedDetails,
                      );

                      ref
                          .read(profileListProvider.notifier)
                          .updateProfile(updatedProfile);
                      ref
                          .read(universalProfileControllerProvider(profile.id)
                              .notifier)
                          .syncProfile(updatedProfile);

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Performance standards rating updated to "$rating"!'),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    },
                    child: Text('CALCULATE & SAVE RATING',
                        style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
