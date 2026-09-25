import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import '../controllers/profile_controller.dart';
import '../screens/edit_profile_screen.dart';
import 'profile_posts_grid.dart';
import '../screens/settings_screen.dart';
import '../../../../core/widgets/mention_text.dart';
import '../../../../core/services/messaging_access_service.dart';
import 'profile_share_helper.dart';
import '../screens/following_list_screen.dart';
class BrandProfileWidget extends ConsumerWidget {
  final ProfileModel profile;

  const BrandProfileWidget({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedInUserId = ref.watch(loggedInUserIdProvider);
    final isOwner = profile.id == loggedInUserId;

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
                                const Icon(Icons.verified, size: 22, color: AppTheme.primaryColor),
                                if (profile.verificationBadge.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3), width: 0.5),
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
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    // Role Badge Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        border: Border.all(color: AppTheme.primaryColor, width: 1),
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
                    const Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.city}, ${profile.state}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (profile.industry != null && profile.industry!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      const Text('•', style: TextStyle(color: Colors.white24)),
                      const SizedBox(width: 12),
                      Text(
                        profile.industry!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 20),

                // 3. Stats Bar
                _buildStatsBar(context, profile),
                const SizedBox(height: 20),

                // 4. Action Buttons
                _buildActionButtons(context, profile, isOwner, ref),
                const SizedBox(height: 24),

                if (profile.verified && profile.verificationBadge.isNotEmpty) ...[
                  _buildVerifiedCredentialsCard(profile),
                  const SizedBox(height: 24),
                ],

                // 5. Bio Block
                _buildSectionLabel('BRAND MISSION & OVERVIEW'),
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
                    text: profile.bio.isEmpty ? 'No description added yet.' : profile.bio,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Organization Classification details
                _buildSectionLabel('ORGANIZATION CLASSIFICATION'),
                const SizedBox(height: 8),
                if (profile.organizationName != null && profile.organizationName!.isNotEmpty)
                  _buildDetailTile(Icons.business_center, 'Official Brand Name', profile.organizationName!),
                if (profile.industry != null && profile.industry!.isNotEmpty)
                  _buildDetailTile(Icons.category, 'Industry Focus', profile.industry!),
                if (profile.website.isNotEmpty)
                  _buildDetailTile(Icons.language, 'Official Website', profile.website),
                const SizedBox(height: 24),

                // 7. Brand Accomplishments/Milestones
                if (profile.achievements.isNotEmpty) ...[
                  _buildSectionLabel('ATHLETIC SPONSORSHIPS & MILESTONES'),
                  const SizedBox(height: 8),
                  ...profile.achievements.map((ach) => _buildBulletItem(ach, icon: Icons.campaign_outlined)).toList(),
                  const SizedBox(height: 24),
                ],
                // 8. Statistics section
                if (profile.statistics.isNotEmpty) ...[
                  _buildStatisticsDisplay(profile.statistics),
                  const SizedBox(height: 24),
                ],

                // 9. Interactive Posts Grid
                ProfilePostsGrid(userId: profile.id),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStack(BuildContext context, ProfileModel profile, bool isOwner, WidgetRef ref) {
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
                colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.8)],
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
                      Icons.business_outlined,
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
          style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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

  Widget _buildActionButtons(BuildContext context, ProfileModel profile, bool isOwner, WidgetRef ref) {
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
                      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
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
                  icon: const Icon(Icons.share_outlined, color: AppTheme.primaryColor, size: 18),
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
                backgroundColor: profile.isFollowing ? const Color(0xFF1E1E1E) : AppTheme.primaryColor,
                foregroundColor: profile.isFollowing ? Colors.white : Colors.black,
              ),
              icon: Icon(profile.isFollowing ? Icons.check : Icons.person_add, size: 16),
              label: Text(profile.isFollowing ? 'FOLLOWING' : 'FOLLOW'),
              onPressed: () async {
                await ref.read(universalProfileControllerProvider(profile.id).notifier).toggleFollow();
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
              icon: const Icon(Icons.message_outlined, size: 16, color: Colors.white),
              label: const Text('MESSAGE'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                context.push('/chat/room?receiverId=${Uri.encodeQueryComponent(profile.id)}');
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

  void _shareProfileDialog(BuildContext context, ProfileModel profile, WidgetRef ref) {
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
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.white38, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBulletItem(String content, {required IconData icon}) {
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
          Icon(icon, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              content,
              style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsDisplay(List<StatEntry> stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('STATISTICS',
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold, fontSize: 11,
                color: AppTheme.primaryColor, letterSpacing: 1.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${stats.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 9, fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121212),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            children: stats.asMap().entries.map((e) =>
              _buildStatDisplayRow(e.value, isLast: e.key == stats.length - 1),
            ).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDisplayRow(StatEntry stat, {required bool isLast}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(stat.name,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.white70))),
          SizedBox(
            width: 60,
            child: LayoutBuilder(builder: (context, constraints) {
              final dotCount = (constraints.maxWidth / 5).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(dotCount,
                  (_) => const Text('.', style: TextStyle(color: Colors.white24, fontSize: 12))),
              );
            }),
          ),
          Text(stat.displayValue,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
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
}
