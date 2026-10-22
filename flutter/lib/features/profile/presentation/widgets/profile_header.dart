import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../screens/following_list_screen.dart';
import '../../../feed/presentation/controllers/feed_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

const double _coverHeight = 144;
const double _avatarSize = 84;
const double _avatarOverlap = 40;

/// Minimal profile hero: short cover, gold-ringed avatar overlapping it, and
/// the role label aligned to the avatar's baseline.
class ProfileCoverHeader extends StatelessWidget {
  final ProfileModel profile;

  /// Owner-only camera buttons; hidden when null.
  final VoidCallback? onChangeCover;
  final VoidCallback? onChangeAvatar;

  const ProfileCoverHeader({
    super.key,
    required this.profile,
    this.onChangeCover,
    this.onChangeAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final cover = profile.coverUrl.trim();
    final avatar = profile.avatarUrl.trim();

    return SizedBox(
      height: _coverHeight + _avatarSize - _avatarOverlap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: _coverHeight,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover.startsWith('http'))
                  CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                else
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1408), Colors.black],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Color(0x33000000), Colors.black],
                      stops: [0, 0.5, 1],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (onChangeCover != null)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: _CameraButton(
                      onTap: onChangeCover!,
                      background: const Color(0xB3000000),
                      foreground: Colors.white,
                      iconSize: 16,
                      padding: 8,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black,
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatar.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          memCacheWidth: 252,
                        )
                      : const Icon(
                          AthIcons.user,
                          size: 40,
                          color: Colors.white38,
                        ),
                ),
                    if (onChangeAvatar != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: _CameraButton(
                          onTap: onChangeAvatar!,
                          background: AppTheme.primaryColor,
                          foreground: Colors.black,
                          iconSize: 14,
                          padding: 4,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    profile.role.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: AppTheme.primaryColor,
                    ),
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

class _CameraButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final double iconSize;
  final double padding;

  const _CameraButton({
    required this.onTap,
    required this.background,
    required this.foreground,
    required this.iconSize,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Icon(AthIcons.camera, size: iconSize, color: foreground),
        ),
      ),
    );
  }
}

/// Followers / Following / Posts row separated by hairlines, as on the website.
class ProfileStatsRow extends ConsumerWidget {
  final ProfileModel profile;

  const ProfileStatsRow({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const hairline = BorderSide(color: Color(0x1AFFFFFF));
    final postsAsync = ref.watch(userPostsProvider(profile.id));
    final actualCount = postsAsync.valueOrNull?.length ?? 0;
    final effectivePostsCount = math.max(profile.postsCount, actualCount);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: hairline, bottom: hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                value: profile.followersCount,
                label: 'FOLLOWERS',
                highlight: true,
              ),
            ),
            if (profile.showFollowing) ...[
              const VerticalDivider(width: 1, thickness: 1, color: Color(0x1AFFFFFF)),
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FollowingListScreen(
                        userId: profile.id,
                        userName: profile.name,
                      ),
                    ),
                  ),
                  child: _Stat(
                    value: profile.followingCount,
                    label: 'FOLLOWING',
                  ),
                ),
              ),
            ],
            const VerticalDivider(width: 1, thickness: 1, color: Color(0x1AFFFFFF)),
            Expanded(
              child: _Stat(value: effectivePostsCount, label: 'POSTS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int value;
  final String label;
  final bool highlight;

  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });

  String get _formatted {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatted,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: highlight ? AppTheme.primaryColor : Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
