import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import 'athlete_profile_widget.dart';
import 'coach_profile_widget.dart';
import 'brand_profile_widget.dart';
import 'federation_profile_widget.dart';
import '../controllers/settings_controller.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/user_settings_model.dart';
import '../../../../core/utils/user_facing_error.dart';

class ProfileLoader extends ConsumerWidget {
  final String userId;

  const ProfileLoader({super.key, required this.userId});

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E293B),
      highlightColor: const Color(0xFF334155),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner/Header block
            Container(
              height: 150,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 150,
                          height: 20,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 100,
                          height: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: 120,
                height: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the profile of the requested user ID
    final profileAsync = ref.watch(universalProfileControllerProvider(userId));

    // Watch the requested user's privacy settings
    final settingsAsync = ref.watch(publicUserSettingsProvider(userId));
    final blockedByUser = ref.watch(blockedByUserProvider(userId));
    final blockedList = ref.watch(blockedUsersStreamProvider).valueOrNull ?? [];
    final hasBlocked = blockedList.contains(userId);
    final isBlocked = (blockedByUser.valueOrNull == true) || hasBlocked;

    final loggedInId = ref.watch(loggedInUserIdProvider);
    final isOwner = userId == loggedInId;

    if (isBlocked) {
      return _buildBlockedProfileView(context, ref, hasBlocked: hasBlocked, profile: profileAsync.valueOrNull);
    }

    return profileAsync.when(
      loading: () => _buildSkeletonLoader(),
      error: (err, stack) => _buildErrorState(err.toString(), ref),
      data: (profile) {
        if (profile == null) {
          return const Center(
            child: Text(
              'Profile not found',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        Widget buildRoleView(UserSettingsModel settings) {
          ProfileModel displayProfile = profile;

          // Mask fields if not owner
          if (!isOwner) {
            final p = settings.privacy;
            displayProfile = profile.copyWith(
              height: p.hideHeight ? null : profile.height,
              weight: p.hideWeight ? null : profile.weight,
              email: p.hideEmail ? '' : profile.email,
              phoneNumber: p.hidePhone ? '' : profile.phoneNumber,
              dateOfBirth: p.hideDob ? '' : profile.dateOfBirth,
              personalNotes:
                  p.hidePersonalNotes ? '' : profile.personalNotes,
              verificationRequestDetails: p.hidePerformanceRating
                  ? {
                      ...profile.verificationRequestDetails,
                      'performanceMetrics': null
                    }
                  : profile.verificationRequestDetails,
            );
          }

          // Render appropriate widget based on role
          Widget roleWidget;
          switch (displayProfile.role) {
            case 'Athlete':
              roleWidget = AthleteProfileWidget(profile: displayProfile);
              break;
            case 'Coach':
              roleWidget = CoachProfileWidget(profile: displayProfile);
              break;
            case 'Brand':
              roleWidget = BrandProfileWidget(profile: displayProfile);
              break;
            case 'Federation':
              roleWidget = FederationProfileWidget(profile: displayProfile);
              break;
            default:
              roleWidget = AthleteProfileWidget(profile: displayProfile);
          }

          return RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: const Color(0xFF0F172A),
            onRefresh: () async {
              HapticFeedback.lightImpact();
              ref.invalidate(universalProfileControllerProvider(userId));
              ref.invalidate(publicUserSettingsProvider(userId));
            },
            child: roleWidget,
          );
        }

        return settingsAsync.when(
          loading: () => _buildSkeletonLoader(),
          error: (err, stack) {
            // Gracefully fall back to defaults if privacy settings cannot be retrieved
            return buildRoleView(UserSettingsModel.defaults());
          },
          data: (settings) => buildRoleView(settings),
        );
      },
    );
  }

  Widget _buildErrorState(dynamic error, WidgetRef ref) {
    final friendlyMessage = UserFacingError.message(
      error,
      fallback: 'Unable to load profile at this time. Please check your connection and try again.',
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              friendlyMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                ref.invalidate(universalProfileControllerProvider(userId));
                ref.invalidate(publicUserSettingsProvider(userId));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedProfileView(
    BuildContext context,
    WidgetRef ref, {
    required bool hasBlocked,
    ProfileModel? profile,
  }) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Atheleos User';
    final username = profile?.username.isNotEmpty == true ? '@${profile!.username}' : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          username.isNotEmpty ? username : name,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Avatar Placeholder
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(color: Colors.white12, width: 2),
              ),
              child: const Icon(Icons.person, size: 48, color: Colors.white30),
            ),
            const SizedBox(height: 14),

            // Name
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),

            if (username.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                username,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),

            // 0 Posts • 0 Followers • 0 Following Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBlockedStat('0', 'Posts'),
                _buildBlockedStat('0', 'Followers'),
                _buildBlockedStat('0', 'Following'),
              ],
            ),

            const SizedBox(height: 24),

            if (hasBlocked) ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () async {
                  await ref.read(settingsActionsProvider).unblockUser(userId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name has been unblocked.'),
                        backgroundColor: AppTheme.primaryColor,
                      ),
                    );
                  }
                },
                child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(height: 30),
            ],

            const Divider(color: Colors.white10),
            const SizedBox(height: 40),

            // Instagram-Style Restriction Card
            Icon(
              hasBlocked ? Icons.block_flipped : Icons.lock_outline_rounded,
              color: Colors.white30,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              hasBlocked ? 'You blocked this account' : 'User not found',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                hasBlocked
                    ? 'You won\'t see their posts, reels, or profile updates until you unblock them.'
                    : 'This account is unavailable or has restricted access.',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedStat(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}
