import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/user_settings_model.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';
import 'verification_dashboard_screen.dart';
import 'portfolio_analytics_screen.dart';
import '../../../../core/utils/user_facing_error.dart';

// ── Settings Categories Definition ──────────────────────────────────────────

enum SettingsCategory {
  account(
    title: 'ACCOUNT',
    displayName: 'Account',
    subtitle: 'Edit profile, password, phone, username, email, sign out',
    icon: Icons.person_outline,
    keywords: [
      'profile',
      'edit',
      'username',
      'email',
      'phone',
      'password',
      'sign out',
      'logout',
      'delete',
      'following'
    ],
  ),
  privacy(
    title: 'PRIVACY & VISIBILITY',
    displayName: 'Privacy & Visibility',
    subtitle: 'Show following on profile, hide personal details',
    icon: Icons.visibility_outlined,
    keywords: [
      'privacy',
      'visibility',
      'email',
      'phone',
      'dob',
      'birth',
      'height',
      'weight',
      'rating',
      'notes',
      'following'
    ],
  ),
  messaging(
    title: 'MESSAGING',
    displayName: 'Messaging',
    subtitle: 'Who can message you, message requests, read receipts',
    icon: Icons.chat_bubble_outline_rounded,
    keywords: [
      'messaging',
      'messages',
      'chat',
      'requests',
      'read receipts',
      'dms'
    ],
  ),
  notifications(
    title: 'NOTIFICATIONS',
    displayName: 'Notifications',
    subtitle: 'Push alerts & email notification preferences',
    icon: Icons.notifications_outlined,
    keywords: [
      'notifications',
      'alerts',
      'push',
      'email',
      'likes',
      'comments',
      'mentions',
      'invites'
    ],
  ),
  safety(
    title: 'SAFETY',
    displayName: 'Safety',
    subtitle: 'Blocked users, muted users, hidden keywords, reports',
    icon: Icons.shield_outlined,
    keywords: [
      'safety',
      'blocked',
      'muted',
      'keywords',
      'filter',
      'report'
    ],
  ),
  verification(
    title: 'VERIFICATION',
    displayName: 'Verification',
    subtitle: 'Athlete verification dashboard & badge status',
    icon: Icons.verified_outlined,
    keywords: ['verification', 'badge', 'verify', 'athlete', 'review'],
  ),
  portfolio(
    title: 'PORTFOLIO & ANALYTICS',
    displayName: 'Portfolio & Analytics',
    subtitle: 'Views, shares, analytics & portfolio performance',
    icon: Icons.bar_chart_rounded,
    keywords: ['portfolio', 'analytics', 'stats', 'views', 'shares'],
  ),
  helpSupport(
    title: 'HELP & SUPPORT',
    displayName: 'Help & Support',
    subtitle: 'Help center, guidelines, clear cache, report a problem',
    icon: Icons.help_outline_rounded,
    keywords: [
      'help',
      'support',
      'contact',
      'guidelines',
      'report',
      'problem',
      'cache'
    ],
  ),
  about(
    title: 'ABOUT',
    displayName: 'About',
    subtitle: 'App version, release notes, open source licenses, terms',
    icon: Icons.info_outline_rounded,
    keywords: [
      'about',
      'version',
      'release notes',
      'licenses',
      'terms',
      'privacy policy'
    ],
  );

  final String title;
  final String displayName;
  final String subtitle;
  final IconData icon;
  final List<String> keywords;

  const SettingsCategory({
    required this.title,
    required this.displayName,
    required this.subtitle,
    required this.icon,
    required this.keywords,
  });
}

// ── Shared UI Widgets ────────────────────────────────────────────────────────

class SettingsWidgets {
  static Widget sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white10, height: 1),
        ]),
      );

  static Widget divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Divider(color: Colors.white10, height: 1),
      );

  static Widget tile(
    IconData icon,
    String label, {
    String? subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) =>
      ListTile(
        leading: Icon(
          icon,
          color: danger ? Colors.redAccent : AppTheme.primaryColor,
          size: 20,
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: danger ? Colors.redAccent : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              )
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.white24, size: 18)
            : null,
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        dense: true,
        horizontalTitleGap: 12,
      );

  static Widget futureTile(IconData icon, String label, {VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon, color: Colors.white24, size: 20),
        title: Text(
          label,
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'SOON',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        dense: true,
        horizontalTitleGap: 12,
        onTap: onTap,
      );

  static Widget toggleTile(
    String label,
    bool value, {
    String? subtitle,
    required void Function(bool) onChanged,
  }) =>
      SwitchListTile.adaptive(
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              )
            : null,
        value: value,
        activeTrackColor: AppTheme.primaryColor,
        onChanged: onChanged,
        dense: true,
      );

  static Widget prefDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.containsKey(value) ? value : items.keys.first,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              items: items.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]);
}

// ── Main Categorized Settings Screen ────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  final ProfileModel? profile;
  const SettingsScreen({super.key, this.profile});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ProfileModel? get _effectiveProfile =>
      widget.profile ??
      ref.watch(currentUserProvider).valueOrNull ??
      ref.watch(activeProfileProvider).valueOrNull;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onCategoryTap(SettingsCategory category) {
    final effectiveProfile = widget.profile ??
        ref.read(currentUserProvider).valueOrNull ??
        ref.read(activeProfileProvider).valueOrNull;

    if (category == SettingsCategory.verification) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationDashboardScreen(profile: effectiveProfile),
        ),
      );
      return;
    }
    if (category == SettingsCategory.portfolio) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PortfolioAnalyticsScreen(profile: effectiveProfile),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsCategoryScreen(category: category, profile: effectiveProfile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final categories = SettingsCategory.values.where((cat) {
      if (query.isEmpty) return true;
      final searchable =
          '${cat.displayName} ${cat.subtitle} ${cat.keywords.join(' ')}'
              .toLowerCase();
      return searchable.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'SETTINGS',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Search Field ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search settings, privacy, account...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white38, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
              ),
            ),

            // ── Categories List ──────────────────────────────────────────────
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded,
                          color: Colors.white24, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'No settings matching "$_searchQuery"',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...categories.map((cat) => _buildCategoryTile(cat)),

            const SizedBox(height: 16),

            // ── Main Screen Sign Out Tile ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.25)),
                ),
                tileColor: Colors.redAccent.withValues(alpha: 0.06),
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                title: Text(
                  'Sign Out',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: const Text(
                  'Log out of your ATHELEOS account',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
                onTap: () => _confirmLogoutDialog(context, ref),
              ),
            ),

            const SizedBox(height: 24),

            // ── Branding Footer ──────────────────────────────────────────────
            Center(
              child: Text(
                'ATHELEOS • Professional Sports Network',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white24,
                  fontSize: 10,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(SettingsCategory cat) {
    if (cat == SettingsCategory.verification) {
      final profile = _effectiveProfile;
      final rawRole = (profile?.role ?? '').trim().toLowerCase();
      String title = 'Verification';
      String subtitle = 'Athlete verification dashboard & badge status';
      if (rawRole == 'coach') {
        title = 'Coach Accreditation';
        subtitle = 'Coach license & accreditation status';
      } else if (rawRole == 'federation' || rawRole.contains('federation')) {
        title = 'Federation Verification';
        subtitle = 'Sports governing body verification status';
      } else if (rawRole == 'brand' || rawRole.contains('brand')) {
        title = 'Brand Verification';
        subtitle = 'Official business verification status';
      }
      return SettingsWidgets.tile(
        cat.icon,
        title,
        subtitle: subtitle,
        onTap: () => _onCategoryTap(cat),
      );
    }
    return SettingsWidgets.tile(
      cat.icon,
      cat.displayName,
      subtitle: cat.subtitle,
      onTap: () => _onCategoryTap(cat),
    );
  }
}

// Reusable Sign Out Dialog
Future<void> _confirmLogoutDialog(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        'Sign Out',
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'Are you sure you want to sign out of ATHELEOS?',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(dialogCtx).pop(true),
          child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    try {
      await ref.read(accountActionsProvider).signOut();
    } catch (e) {
      debugPrint('Sign out error via accountActions: $e');
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out successfully.')),
      );
      context.go('/login');
    }
  }
}

// ── Category Detail Subscreen ───────────────────────────────────────────────

class SettingsCategoryScreen extends ConsumerStatefulWidget {
  final SettingsCategory category;
  final ProfileModel? profile;

  const SettingsCategoryScreen({
    super.key,
    required this.category,
    this.profile,
  });

  @override
  ConsumerState<SettingsCategoryScreen> createState() =>
      _SettingsCategoryScreenState();
}

class _SettingsCategoryScreenState
    extends ConsumerState<SettingsCategoryScreen> {
  final Map<String, bool> _optimisticToggles = {};
  String? _optimisticAllowedSenders;

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _getToggleValue(String key, bool serverValue) {
    return _optimisticToggles[key] ?? serverValue;
  }

  void _onToggle(
      String key, bool newValue, Future<void> Function() asyncAction) {
    setState(() {
      _optimisticToggles[key] = newValue;
    });
    asyncAction().catchError((err) {
      if (mounted) {
        setState(() {
          _optimisticToggles.remove(key);
        });
        _snack(context, UserFacingError.message(err, fallback: 'Failed to update setting. Please try again.'));
      }
    });
  }

  String _getAllowedSenders(String serverValue) {
    const valid = {'everyone', 'followers', 'nobody'};
    final current = _optimisticAllowedSenders ?? serverValue;
    return valid.contains(current) ? current : 'everyone';
  }

  void _onAllowedSendersChanged(String newValue, SettingsActions actions) {
    setState(() {
      _optimisticAllowedSenders = newValue;
    });
    actions.updateAllowedSenders(newValue).catchError((err) {
      if (mounted) {
        setState(() {
          _optimisticAllowedSenders = null;
        });
        _snack(context, UserFacingError.message(err, fallback: 'Failed to update permission. Please try again.'));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsStreamProvider);
    final actions = ref.read(settingsActionsProvider);
    final userProfile = widget.profile ??
        ref.watch(currentUserProvider).valueOrNull ??
        ref.watch(activeProfileProvider).valueOrNull;
    final packageInfo = ref.watch(packageInfoProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.category.title,
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            fontSize: 15,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                UserFacingError.message(e, fallback: 'Unable to load settings right now.'),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (settings) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _buildCategoryItems(
              context: context,
              ref: ref,
              settings: settings,
              actions: actions,
              userProfile: userProfile,
              packageInfo: packageInfo,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategoryItems({
    required BuildContext context,
    required WidgetRef ref,
    required UserSettingsModel settings,
    required SettingsActions actions,
    required ProfileModel? userProfile,
    required PackageInfo? packageInfo,
  }) {
    switch (widget.category) {
      case SettingsCategory.account:
        return [
          SettingsWidgets.tile(
            Icons.person_outline,
            'Edit Profile',
            onTap: () => context.push('/settings/edit-profile'),
          ),
          SettingsWidgets.tile(
            Icons.people_outline,
            'Following',
            subtitle: 'Manage accounts you follow privately',
            onTap: () => context.push('/settings/following'),
          ),
          SettingsWidgets.tile(
            Icons.alternate_email,
            'Change Username',
            onTap: () => context.push('/settings/username'),
          ),
          SettingsWidgets.tile(
            Icons.mail_outline,
            'Change Email Address',
            onTap: () => context.push('/settings/email'),
          ),
          SettingsWidgets.tile(
            Icons.phone_android_outlined,
            'Change Phone Number',
            onTap: () => context.push('/settings/phone'),
          ),
          SettingsWidgets.tile(
            Icons.lock_outline,
            'Change Password',
            onTap: () => context.push('/settings/password'),
          ),
          SettingsWidgets.divider(),
          SettingsWidgets.tile(
            Icons.logout_rounded,
            'Sign Out',
            danger: true,
            onTap: () => _confirmLogoutDialog(context, ref),
          ),
          SettingsWidgets.tile(
            Icons.delete_outline_rounded,
            'Delete Account',
            danger: true,
            onTap: () => context.push('/settings/delete-account'),
          ),
        ];

      case SettingsCategory.privacy:
        return [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Your profile is always public on ATHELEOS so scouts and coaches can discover you. You may hide specific personal details below.',
              style: GoogleFonts.inter(
                  color: Colors.white38, fontSize: 11, height: 1.5),
            ),
          ),
          const SizedBox(height: 4),
          SettingsWidgets.toggleTile(
            'Show Following on Profile',
            _getToggleValue('showFollowing', settings.privacy.showFollowing),
            subtitle:
                'Allow others to see the accounts you follow on your profile',
            onChanged: (v) {
              _onToggle('showFollowing', v, () async {
                await actions.updatePrivacy('showFollowing', v);
                if (userProfile != null) {
                  final updated = userProfile.copyWith(showFollowing: v);
                  await ref.read(userRepositoryProvider).updateUser(updated);
                  ref.read(profileListProvider.notifier).updateProfile(updated);
                }
              });
            },
          ),
          SettingsWidgets.toggleTile(
            'Show Email Address',
            _getToggleValue('showEmail', !settings.privacy.hideEmail),
            onChanged: (v) => _onToggle('showEmail', v,
                () => actions.updatePrivacy('hideEmail', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Phone Number',
            _getToggleValue('showPhone', !settings.privacy.hidePhone),
            onChanged: (v) => _onToggle('showPhone', v,
                () => actions.updatePrivacy('hidePhone', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Date of Birth',
            _getToggleValue('showDob', !settings.privacy.hideDob),
            subtitle: 'Hidden by default',
            onChanged: (v) => _onToggle(
                'showDob', v, () => actions.updatePrivacy('hideDob', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Height',
            _getToggleValue('showHeight', !settings.privacy.hideHeight),
            subtitle: 'Hidden by default',
            onChanged: (v) => _onToggle('showHeight', v,
                () => actions.updatePrivacy('hideHeight', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Weight',
            _getToggleValue('showWeight', !settings.privacy.hideWeight),
            subtitle: 'Hidden by default',
            onChanged: (v) => _onToggle('showWeight', v,
                () => actions.updatePrivacy('hideWeight', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Performance Rating',
            _getToggleValue(
                'showPerformanceRating', !settings.privacy.hidePerformanceRating),
            onChanged: (v) => _onToggle('showPerformanceRating', v,
                () => actions.updatePrivacy('hidePerformanceRating', !v)),
          ),
          SettingsWidgets.toggleTile(
            'Show Personal Notes',
            _getToggleValue(
                'showPersonalNotes', !settings.privacy.hidePersonalNotes),
            onChanged: (v) => _onToggle('showPersonalNotes', v,
                () => actions.updatePrivacy('hidePersonalNotes', !v)),
          ),
        ];

      case SettingsCategory.messaging:
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who can send you messages',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value:
                          _getAllowedSenders(settings.messaging.allowedSenders),
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F172A),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'everyone', child: Text('Everyone')),
                        DropdownMenuItem(
                            value: 'followers', child: Text('Followers Only')),
                        DropdownMenuItem(
                            value: 'nobody', child: Text('Nobody')),
                      ],
                      onChanged: (v) {
                        if (v != null) _onAllowedSendersChanged(v, actions);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SettingsWidgets.toggleTile(
            'Allow Message Requests',
            _getToggleValue('allowMessageRequests',
                settings.messaging.allowMessageRequests),
            onChanged: (v) => _onToggle(
                'allowMessageRequests',
                v,
                () => actions.updateMessagingBool(
                    'allowMessageRequests', v)),
          ),
          SettingsWidgets.toggleTile(
            'Read Receipts',
            _getToggleValue('readReceipts', settings.messaging.readReceipts),
            onChanged: (v) => _onToggle('readReceipts', v,
                () => actions.updateMessagingBool('readReceipts', v)),
          ),
        ];

      case SettingsCategory.notifications:
        return [
          SettingsWidgets.sectionHeader('Push Notifications'),
          SettingsWidgets.toggleTile(
            'Likes',
            _getToggleValue('likes', settings.notifications.likes),
            onChanged: (v) => _onToggle('likes', v,
                () => actions.toggleNotification('likes', v)),
          ),
          SettingsWidgets.toggleTile(
            'Comments',
            _getToggleValue('comments', settings.notifications.comments),
            onChanged: (v) => _onToggle('comments', v,
                () => actions.toggleNotification('comments', v)),
          ),
          SettingsWidgets.toggleTile(
            'Replies',
            _getToggleValue('replies', settings.notifications.replies),
            onChanged: (v) => _onToggle('replies', v,
                () => actions.toggleNotification('replies', v)),
          ),
          SettingsWidgets.toggleTile(
            'New Followers',
            _getToggleValue('newFollowers', settings.notifications.newFollowers),
            onChanged: (v) => _onToggle('newFollowers', v,
                () => actions.toggleNotification('newFollowers', v)),
          ),
          SettingsWidgets.toggleTile(
            'Direct Messages',
            _getToggleValue(
                'directMessages', settings.notifications.directMessages),
            onChanged: (v) => _onToggle('directMessages', v,
                () => actions.toggleNotification('directMessages', v)),
          ),
          SettingsWidgets.toggleTile(
            'Verification Updates',
            _getToggleValue('verificationUpdates',
                settings.notifications.verificationUpdates),
            onChanged: (v) => _onToggle('verificationUpdates', v,
                () => actions.toggleNotification('verificationUpdates', v)),
          ),
          SettingsWidgets.toggleTile(
            'Coach Invitations',
            _getToggleValue(
                'coachInvitations', settings.notifications.coachInvitations),
            onChanged: (v) => _onToggle('coachInvitations', v,
                () => actions.toggleNotification('coachInvitations', v)),
          ),
          SettingsWidgets.toggleTile(
            'Federation Announcements',
            _getToggleValue('federationAnnouncements',
                settings.notifications.federationAnnouncements),
            onChanged: (v) => _onToggle(
                'federationAnnouncements',
                v,
                () => actions.toggleNotification(
                    'federationAnnouncements', v)),
          ),
          SettingsWidgets.toggleTile(
            'Tournament Invitations',
            _getToggleValue('tournamentInvitations',
                settings.notifications.tournamentInvitations),
            onChanged: (v) => _onToggle(
                'tournamentInvitations',
                v,
                () => actions.toggleNotification(
                    'tournamentInvitations', v)),
          ),
          SettingsWidgets.toggleTile(
            'Event Reminders',
            _getToggleValue(
                'eventReminders', settings.notifications.eventReminders),
            onChanged: (v) => _onToggle('eventReminders', v,
                () => actions.toggleNotification('eventReminders', v)),
          ),
          SettingsWidgets.toggleTile(
            'Collaboration Requests',
            _getToggleValue('collaborationRequests',
                settings.notifications.collaborationRequests),
            onChanged: (v) => _onToggle(
                'collaborationRequests',
                v,
                () => actions.toggleNotification(
                    'collaborationRequests', v)),
          ),
          SettingsWidgets.toggleTile(
            'Mentions',
            _getToggleValue('mentions', settings.notifications.mentions),
            onChanged: (v) => _onToggle('mentions', v,
                () => actions.toggleNotification('mentions', v)),
          ),
          SettingsWidgets.sectionHeader('Email Notifications'),
          SettingsWidgets.toggleTile(
            'Enable Email Notifications',
            _getToggleValue('emailNotifications',
                settings.notifications.emailNotifications),
            onChanged: (v) => _onToggle('emailNotifications', v,
                () => actions.toggleNotification('emailNotifications', v)),
          ),
        ];

      case SettingsCategory.safety:
        return [
          SettingsWidgets.tile(
            Icons.block_outlined,
            'Blocked Users',
            onTap: () => context.push('/settings/blocked-users'),
          ),
          SettingsWidgets.tile(
            Icons.volume_off_outlined,
            'Muted Users',
            onTap: () => context.push('/settings/muted-users'),
          ),
          SettingsWidgets.tile(
            Icons.filter_list_outlined,
            'Hidden Keywords',
            onTap: () => context.push('/settings/hidden-keywords'),
          ),
          SettingsWidgets.tile(
            Icons.flag_outlined,
            'Report History',
            onTap: () => context.push('/settings/report-history'),
          ),
        ];

      case SettingsCategory.helpSupport:
        return [
          SettingsWidgets.tile(Icons.help_outline, 'Help Center',
              onTap: () => context.push('/settings/help')),
          SettingsWidgets.tile(Icons.support_agent_outlined, 'Contact Support',
              onTap: () => context.push('/settings/contact-support')),
          SettingsWidgets.tile(Icons.cleaning_services_outlined, 'Clear App Cache',
              subtitle: 'Free up storage and clear cached files',
              onTap: () async {
            await ref.read(accountActionsProvider).clearAppCache();
            if (context.mounted) {
              _snack(context, 'Cache cleared successfully.');
            }
          }),
          SettingsWidgets.tile(Icons.people_outline, 'Community Guidelines',
              onTap: () => context.push('/settings/community-guidelines')),
          SettingsWidgets.tile(
              Icons.stars_outlined, 'Athlete Verification Guidelines',
              onTap: () => context.push('/settings/verification-guidelines')),
          SettingsWidgets.tile(Icons.privacy_tip_outlined, 'Privacy Policy',
              onTap: () => context.push('/settings/privacy-policy')),
          SettingsWidgets.tile(Icons.article_outlined, 'Terms & Conditions',
              onTap: () => context.push('/settings/terms')),
          SettingsWidgets.tile(Icons.flag_outlined, 'Report a Problem',
              onTap: () => context.push('/settings/report-problem')),
        ];

      case SettingsCategory.about:
        return [
          SettingsWidgets.tile(
            Icons.info_outline,
            'App Version',
            subtitle: packageInfo == null
                ? 'Loading...'
                : 'ATHELEOS v${packageInfo.version} (Build ${packageInfo.buildNumber})',
          ),
          SettingsWidgets.tile(Icons.new_releases_outlined, 'Release Notes',
              onTap: () => context.push('/settings/release-notes')),
          SettingsWidgets.tile(Icons.code_outlined, 'Open Source Licenses',
              onTap: () => showLicensePage(context: context)),
          SettingsWidgets.tile(Icons.privacy_tip_outlined, 'Privacy Policy',
              onTap: () => context.push('/settings/privacy-policy')),
          SettingsWidgets.tile(Icons.article_outlined, 'Terms & Conditions',
              onTap: () => context.push('/settings/terms')),
        ];

      case SettingsCategory.verification:
        final profile = widget.profile ??
            ref.watch(currentUserProvider).valueOrNull ??
            ref.watch(activeProfileProvider).valueOrNull;
        final rawRole = (profile?.role ?? '').trim().toLowerCase();
        String actionLabel = 'Open Verification Dashboard';
        if (rawRole == 'coach') {
          actionLabel = 'Open Coach Accreditation Dashboard';
        } else if (rawRole == 'federation' || rawRole.contains('federation')) {
          actionLabel = 'Open Federation Verification Dashboard';
        } else if (rawRole == 'brand' || rawRole.contains('brand')) {
          actionLabel = 'Open Brand Verification Dashboard';
        }
        return [
          SettingsWidgets.tile(
            Icons.verified_outlined,
            actionLabel,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerificationDashboardScreen(profile: profile),
              ),
            ),
          ),
        ];

      case SettingsCategory.portfolio:
        final profile = widget.profile ??
            ref.watch(currentUserProvider).valueOrNull ??
            ref.watch(activeProfileProvider).valueOrNull;
        return [
          SettingsWidgets.tile(
            Icons.bar_chart_rounded,
            'Open Portfolio Analytics',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PortfolioAnalyticsScreen(profile: profile),
              ),
            ),
          ),
        ];
    }
  }
}

// ── Phone Change Dialog ─────────────────────────────────────────────────────

class _PhoneChangeDialog extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PhoneChangeDialog> createState() => _PhoneChangeDialogState();
}

class _PhoneChangeDialogState extends ConsumerState<_PhoneChangeDialog> {
  final _phoneC = TextEditingController();
  final _otpC = TextEditingController();
  bool _otpSent = false;
  String? _verificationId;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneC.dispose();
    _otpC.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        'Change Phone Number',
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phoneC,
            enabled: !_otpSent && !_isLoading,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '+1 (555) 000-0000',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_otpSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otpC,
              enabled: !_isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter OTP Code',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
          ),
          onPressed: _isLoading
              ? null
              : () async {
                  final phone = _phoneC.text.trim();
                  if (phone.isEmpty) return;

                  final actions = ref.read(accountActionsProvider);
                  setState(() => _isLoading = true);

                  try {
                    if (!_otpSent) {
                      await actions.sendPhoneUpdateOTP(
                        phoneNumber: phone,
                        onCodeSent: (verId) {
                          setState(() {
                            _verificationId = verId;
                            _otpSent = true;
                            _isLoading = false;
                          });
                          _snack('OTP sent to $phone');
                        },
                        onFailed: (err) {
                          setState(() => _isLoading = false);
                          _snack(UserFacingError.message(err, fallback: 'Failed to send verification code. Please try again.'));
                        },
                      );
                    } else {
                      final code = _otpC.text.trim();
                      if (code.isEmpty || _verificationId == null) {
                        setState(() => _isLoading = false);
                        return;
                      }

                      await actions.verifyPhoneUpdateOTP(
                          _verificationId!, code, phone);
                      if (mounted) {
                        Navigator.pop(context);
                        _snack('Phone number updated successfully.');
                      }
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _snack(UserFacingError.message(e, fallback: 'Action failed. Please try again.'));
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 2,
                  ),
                )
              : Text(_otpSent ? 'Verify' : 'Send Code',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
