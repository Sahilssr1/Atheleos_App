import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../controllers/profile_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

class PortfolioAnalyticsScreen extends ConsumerWidget {
  final ProfileModel? profile;
  const PortfolioAnalyticsScreen({super.key, this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeProfileAsync = ref.watch(activeProfileProvider);
    final profileAsync = profile != null
        ? AsyncValue.data(profile)
        : (activeProfileAsync.valueOrNull != null
            ? activeProfileAsync
            : ref.watch(currentUserProvider));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('PORTFOLIO',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, letterSpacing: 1.2, fontSize: 15)),
        backgroundColor: Colors.black,
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        error: (e, _) => Center(
            child: Text('$e', style: const TextStyle(color: Colors.red))),
        data: (profile) {
          if (profile == null) {
            return const Center(
                child: Text('Profile not found.',
                    style: TextStyle(color: Colors.white38)));
          }

          final portfolioLink = 'https://atheleos.com/@${profile.username}';

          // Actual analytics values from ProfileModel
          final int profileViews = profile.profileViews;
          final int portfolioViews = profile.portfolioViews;
          final int portfolioShares = profile.portfolioShares;
          final int searchAppearances = profile.searchAppearances;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Portfolio Link Box ─────────────────────────────────────
              _sectionTitle('YOUR PORTFOLIO LINK'),
              const SizedBox(height: 10),
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
                      const Icon(AthIcons.link,
                          color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          portfolioLink,
                          style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(AthIcons.documentDuplicate, size: 14),
                          label: const Text('Copy Link',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side:
                                const BorderSide(color: AppTheme.primaryColor),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () {
                            Clipboard.setData(
                                ClipboardData(text: portfolioLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Portfolio link copied to clipboard!')),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(AthIcons.share, size: 14),
                          label: const Text('Share',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white60,
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            await SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Check out my athlete profile on ATHELEOS: $portfolioLink',
                                subject: '${profile.name} on ATHELEOS',
                              ),
                            );
                            await ref
                                .read(userRepositoryProvider)
                                .incrementPortfolioShares(profile.id);
                          },
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // QR Code future placeholder
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(children: [
                  const Icon(AthIcons.qrCode,
                      color: Colors.white24, size: 20),
                  const SizedBox(width: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QR Code',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('Coming soon',
                            style: GoogleFonts.outfit(
                                color: Colors.white24, fontSize: 10)),
                      ]),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('SOON',
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              // ── Analytics Section ──────────────────────────────────────
              _sectionTitle('PORTFOLIO ANALYTICS'),
              const SizedBox(height: 4),
              Text(
                'Based on the last 30 days of activity.',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _statCard('Profile Views', profileViews,
                      AthIcons.eye, const Color(0xFF3B82F6)),
                  _statCard('Portfolio Views', portfolioViews,
                      AthIcons.globeAlt, const Color(0xFF8B5CF6)),
                  _statCard('Portfolio Shares', portfolioShares,
                      AthIcons.share, const Color(0xFFE5A93B)),
                  _statCard('Search Appearances', searchAppearances,
                      AthIcons.search, const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 28),

              // ── Profile Strength ───────────────────────────────────────
              _sectionTitle('PROFILE STRENGTH'),
              const SizedBox(height: 10),
              _profileStrengthBar(profile),
              const SizedBox(height: 28),

              // ── Content Summary ────────────────────────────────────────
              _sectionTitle('CONTENT OVERVIEW'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: _contentTile(
                        'Posts', profile.postsCount, AthIcons.squares2X2)),
                const SizedBox(width: 12),
                Expanded(
                    child: _contentTile('Following', profile.followingCount,
                        AthIcons.userPlus)),
                const SizedBox(width: 12),
                Expanded(
                    child: _contentTile('Followers', profile.followersCount,
                        AthIcons.userGroup)),
              ]),
              const SizedBox(height: 28),

              // ── PDF Export ────────────────────────────────────────────
              _sectionTitle('EXPORT'),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(children: [
                  const Icon(AthIcons.documentArrowDown,
                      color: Colors.white24, size: 20),
                  const SizedBox(width: 14),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Download Portfolio as PDF',
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        Text('Printable athlete resume format',
                            style: GoogleFonts.outfit(
                                color: Colors.white24, fontSize: 10)),
                      ]),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.white12),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('SOON',
                        style: TextStyle(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: GoogleFonts.outfit(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 0.6),
      );

  Widget _statCard(String label, int value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value >= 1000
                      ? '${(value / 1000).toStringAsFixed(1)}k'
                      : value.toString(),
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22),
                ),
                Text(label,
                    style:
                        GoogleFonts.outfit(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ],
        ),
      );

  Widget _contentTile(String label, int value, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 18),
            const SizedBox(height: 6),
            Text('$value',
                style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9)),
          ],
        ),
      );

  Widget _profileStrengthBar(dynamic profile) {
    int score = 0;
    if (profile.name.isNotEmpty) score += 10;
    if (profile.bio.isNotEmpty) score += 15;
    if (profile.avatarUrl.isNotEmpty) score += 15;
    if (profile.sport.isNotEmpty) score += 10;
    if (profile.primaryPosition.isNotEmpty) score += 10;
    if (profile.postsCount > 0) score += 15;
    if (profile.website.isNotEmpty) score += 5;
    if (profile.verified) score += 15;
    score = score.clamp(0, 100);

    Color barColor = score < 40
        ? Colors.redAccent
        : score < 70
            ? Colors.amberAccent
            : Colors.greenAccent;
    String label = score < 40
        ? 'Beginner'
        : score < 70
            ? 'Intermediate'
            : score < 90
                ? 'Strong'
                : 'Elite';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
          Text('$score%',
              style: TextStyle(
                  color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
            'Complete your profile, add media, and get verified to increase your discovery score.',
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10)),
      ],
    );
  }
}
