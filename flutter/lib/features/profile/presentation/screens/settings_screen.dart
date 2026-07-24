import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keywordController = TextEditingController();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  // ignore: unused_element
  Future<void> _showChangeDialog({
    required String title,
    required String hint,
    bool obscure = false,
    required void Function(String) onSave,
  }) async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title,
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: c,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black),
            onPressed: () {
              final val = c.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(context);
                onSave(val);
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showPasswordChangeDialog() async {
    final currentC = TextEditingController();
    final newC = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Change Password',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentC,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Current password',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newC,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'New password',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black),
            onPressed: () async {
              final current = currentC.text;
              final newPass = newC.text;
              if (current.isNotEmpty && newPass.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await ref
                      .read(accountActionsProvider)
                      .changePassword(current, newPass);
                  _snack('Password updated successfully.');
                } catch (e) {
                  _snack('Error: $e');
                }
              }
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Logout confirm ─────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Sign Out',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of ATHELEOS?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(accountActionsProvider).signOut();
      _snack('Signed out successfully.');
      context.go('/login');
    }
  }

  // ignore: unused_element
  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Delete Account',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'This action is permanent and cannot be undone. All your posts, clips, events, and profile data will be deleted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Permanently',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(accountActionsProvider).deleteAccount();
        _snack('Account soft deleted. You have been signed out.');
        context.go('/login');
      } catch (e) {
        _snack('Failed to delete account: $e');
      }
    }
  }

  // ── Keyword sheet ──────────────────────────────────────────────────────────

  // ignore: unused_element
  void _showKeywordsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HIDDEN KEYWORDS',
                  style: GoogleFonts.spaceGrotesk(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5)),
              const SizedBox(height: 4),
              const Text(
                  'Posts containing these words will be hidden from your feed.',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 16),

              // Watch the stream provider here
              Consumer(builder: (context, cRef, child) {
                final kwsAsync = cRef.watch(hiddenKeywordsStreamProvider);
                return kwsAsync.when(
                  data: (keywords) => Wrap(
                    spacing: 8,
                    children: keywords
                        .map((kw) => Chip(
                              label: Text(kw,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: Colors.white10,
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              deleteIconColor: Colors.white38,
                              onDeleted: () {
                                cRef
                                    .read(settingsActionsProvider)
                                    .removeHiddenKeyword(kw);
                              },
                            ))
                        .toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading keywords',
                      style: TextStyle(color: Colors.red)),
                );
              }),

              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a keyword…',
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Consumer(builder: (context, cRef, child) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black),
                    onPressed: () {
                      final kw = _keywordController.text.trim();
                      if (kw.isNotEmpty) {
                        cRef.read(settingsActionsProvider).addHiddenKeyword(kw);
                        _keywordController.clear();
                      }
                    },
                    child: const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  );
                }),
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showBlockedUsersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BLOCKED USERS',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text(
                'These users cannot see your profile, send messages, or interact with you.',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 16),
            Consumer(builder: (context, cRef, child) {
              final blockedAsync = cRef.watch(blockedUsersStreamProvider);
              final allProfiles =
                  cRef.watch(profileListProvider).valueOrNull ?? [];

              return blockedAsync.when(
                data: (uids) {
                  if (uids.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No blocked users.',
                          style: TextStyle(color: Colors.white38)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: uids.length,
                    itemBuilder: (ctx, i) {
                      final uid = uids[i];
                      final p =
                          allProfiles.where((e) => e.id == uid).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(p?.avatarUrl ??
                              'https://ui-avatars.com/api/?name=?&background=random'),
                          radius: 16,
                        ),
                        title: Text(p?.name ?? uid,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            p != null ? '@${p.username}' : 'Unknown User',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white),
                          onPressed: () => cRef
                              .read(settingsActionsProvider)
                              .unblockUser(uid),
                          child: const Text('Unblock',
                              style: TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading blocked users',
                    style: TextStyle(color: Colors.red)),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  void _showMutedUsersSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MUTED USERS',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5)),
            const SizedBox(height: 4),
            const Text('Posts from these users will not appear in your feed.',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 16),
            Consumer(builder: (context, cRef, child) {
              final mutedAsync = cRef.watch(mutedUsersStreamProvider);
              final allProfiles =
                  cRef.watch(profileListProvider).valueOrNull ?? [];

              return mutedAsync.when(
                data: (uids) {
                  if (uids.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No muted users.',
                          style: TextStyle(color: Colors.white38)),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: uids.length,
                    itemBuilder: (ctx, i) {
                      final uid = uids[i];
                      final p =
                          allProfiles.where((e) => e.id == uid).firstOrNull;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(p?.avatarUrl ??
                              'https://ui-avatars.com/api/?name=?&background=random'),
                          radius: 16,
                        ),
                        title: Text(p?.name ?? uid,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            p != null ? '@${p.username}' : 'Unknown User',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white10,
                              foregroundColor: Colors.white),
                          onPressed: () => cRef
                              .read(settingsActionsProvider)
                              .unmuteUser(uid),
                          child: const Text('Unmute',
                              style: TextStyle(fontSize: 11)),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('Error loading muted users',
                    style: TextStyle(color: Colors.red)),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsStreamProvider);
    final actions = ref.read(settingsActionsProvider);
    final userProfile = ref.watch(activeProfileProvider).valueOrNull;
    final packageInfo = ref.watch(packageInfoProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('SETTINGS',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 15)),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: settingsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        error: (e, _) => Center(
            child:
                Text('Error: $e', style: const TextStyle(color: Colors.red))),
        data: (settings) => ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── 1. ACCOUNT ────────────────────────────────────────────────
            _sectionHeader('Account'),
            _tile(Icons.person_outline, 'Edit Profile',
                onTap: () => context.push('/settings/edit-profile')),
            _tile(Icons.alternate_email, 'Change Username',
                onTap: () => context.push('/settings/username')),
            _tile(Icons.mail_outline, 'Change Email Address',
                onTap: () => context.push('/settings/email')),
            _tile(Icons.phone_android_outlined, 'Change Phone Number',
                onTap: () => context.push('/settings/phone')),
            _tile(Icons.logout_rounded, 'Sign Out',
                danger: true, onTap: _confirmLogout),
            _tile(Icons.delete_outline_rounded, 'Delete Account',
                danger: true,
                onTap: () => context.push('/settings/delete-account')),
            _divider(),

            // ── 2. SECURITY ───────────────────────────────────────────────
            _sectionHeader('Security'),
            _tile(Icons.lock_outline, 'Change Password',
                onTap: () => context.push('/settings/password')),
            _tile(Icons.email_outlined, 'Change Alternate Email',
                onTap: () => context.push('/settings/alternate-email')),
            _tile(Icons.phone_outlined, 'Change Phone Number',
                subtitle: 'Used for account recovery & 2FA',
                onTap: () => context.push('/settings/recovery-phone')),
            _futureTile(Icons.security_outlined, 'Two-Factor Authentication',
                onTap: () => context.push('/settings/two-factor')),
            _tile(Icons.devices_outlined, 'Active Login Sessions',
                onTap: () => context.push('/settings/devices')),
            _divider(),

            // ── 3. ACCOUNT RECOVERY ───────────────────────────────────────
            _sectionHeader('Account Recovery Methods'),
            _tile(Icons.manage_accounts_outlined, 'Google Account',
                subtitle: userProfile?.name ?? 'Not connected',
                onTap: () => context.push('/settings/connected-account')),
            _tile(Icons.alternate_email, 'Alternate Email',
                subtitle: 'Add a backup recovery email',
                onTap: () => context.push('/settings/alternate-email')),
            _tile(Icons.phone_outlined, 'Verified Phone Number',
                subtitle: 'Add a verified recovery phone',
                onTap: () => context.push('/settings/recovery-phone')),
            _divider(),

            // ── 4. PRIVACY & VISIBILITY ────────────────────────────────────
            _sectionHeader('Privacy & Visibility'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Your profile is always public on ATHELEOS so scouts and coaches can discover you. You may hide specific personal details below.',
                style: GoogleFonts.inter(
                    color: Colors.white38, fontSize: 11, height: 1.5),
              ),
            ),
            const SizedBox(height: 4),
            _toggleTile('Show Email Address', !settings.privacy.hideEmail,
                onChanged: (v) => actions.updatePrivacy('hideEmail', !v)),
            _toggleTile('Show Phone Number', !settings.privacy.hidePhone,
                onChanged: (v) => actions.updatePrivacy('hidePhone', !v)),
            _toggleTile('Show Date of Birth', !settings.privacy.hideDob,
                subtitle: 'Hidden by default',
                onChanged: (v) => actions.updatePrivacy('hideDob', !v)),
            _toggleTile('Show Height', !settings.privacy.hideHeight,
                subtitle: 'Hidden by default',
                onChanged: (v) => actions.updatePrivacy('hideHeight', !v)),
            _toggleTile('Show Weight', !settings.privacy.hideWeight,
                subtitle: 'Hidden by default',
                onChanged: (v) => actions.updatePrivacy('hideWeight', !v)),
            _toggleTile('Show Performance Rating',
                !settings.privacy.hidePerformanceRating,
                onChanged: (v) =>
                    actions.updatePrivacy('hidePerformanceRating', !v)),
            _toggleTile(
                'Show Personal Notes', !settings.privacy.hidePersonalNotes,
                onChanged: (v) =>
                    actions.updatePrivacy('hidePersonalNotes', !v)),
            _divider(),

            // ── 5. MESSAGING ──────────────────────────────────────────────
            _sectionHeader('Messaging'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Who can send you messages',
                      style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.white60)),
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
                        value: settings.messaging.allowedSenders,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(
                              value: 'everyone', child: Text('Everyone')),
                          DropdownMenuItem(
                              value: 'followers',
                              child: Text('Followers Only')),
                          DropdownMenuItem(
                              value: 'nobody', child: Text('Nobody')),
                        ],
                        onChanged: (v) {
                          if (v != null) actions.updateAllowedSenders(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _toggleTile('Allow Message Requests',
                settings.messaging.allowMessageRequests,
                onChanged: (v) =>
                    actions.updateMessagingBool('allowMessageRequests', v)),
            _toggleTile('Read Receipts', settings.messaging.readReceipts,
                onChanged: (v) =>
                    actions.updateMessagingBool('readReceipts', v)),
            _divider(),

            // ── 6. NOTIFICATIONS ──────────────────────────────────────────
            _sectionHeader('Push Notifications'),
            _toggleTile('Likes', settings.notifications.likes,
                onChanged: (v) => actions.toggleNotification('likes', v)),
            _toggleTile('Comments', settings.notifications.comments,
                onChanged: (v) => actions.toggleNotification('comments', v)),
            _toggleTile('Replies', settings.notifications.replies,
                onChanged: (v) => actions.toggleNotification('replies', v)),
            _toggleTile('New Followers', settings.notifications.newFollowers,
                onChanged: (v) =>
                    actions.toggleNotification('newFollowers', v)),
            _toggleTile(
                'Direct Messages', settings.notifications.directMessages,
                onChanged: (v) =>
                    actions.toggleNotification('directMessages', v)),
            _toggleTile('Verification Updates',
                settings.notifications.verificationUpdates,
                onChanged: (v) =>
                    actions.toggleNotification('verificationUpdates', v)),
            _toggleTile(
                'Coach Invitations', settings.notifications.coachInvitations,
                onChanged: (v) =>
                    actions.toggleNotification('coachInvitations', v)),
            _toggleTile('Federation Announcements',
                settings.notifications.federationAnnouncements,
                onChanged: (v) =>
                    actions.toggleNotification('federationAnnouncements', v)),
            _toggleTile('Tournament Invitations',
                settings.notifications.tournamentInvitations,
                onChanged: (v) =>
                    actions.toggleNotification('tournamentInvitations', v)),
            _toggleTile(
                'Event Reminders', settings.notifications.eventReminders,
                onChanged: (v) =>
                    actions.toggleNotification('eventReminders', v)),
            _toggleTile('Collaboration Requests',
                settings.notifications.collaborationRequests,
                onChanged: (v) =>
                    actions.toggleNotification('collaborationRequests', v)),
            _toggleTile('Mentions', settings.notifications.mentions,
                onChanged: (v) => actions.toggleNotification('mentions', v)),
            _sectionHeader('Email Notifications'),
            _toggleTile('Enable Email Notifications',
                settings.notifications.emailNotifications,
                onChanged: (v) =>
                    actions.toggleNotification('emailNotifications', v)),
            _divider(),

            // ── 7. SAFETY ─────────────────────────────────────────────────
            _sectionHeader('Safety'),
            _tile(Icons.block_outlined, 'Blocked Users',
                onTap: () => context.push('/settings/blocked-users')),
            _tile(Icons.volume_off_outlined, 'Muted Users',
                onTap: () => context.push('/settings/muted-users')),
            _tile(Icons.filter_list_outlined, 'Hidden Keywords',
                onTap: () => context.push('/settings/hidden-keywords')),
            _tile(Icons.flag_outlined, 'Report History',
                onTap: () => context.push('/settings/report-history')),
            _futureTile(Icons.shield_outlined, 'Account Security Alerts'),
            _divider(),

            // ── 8. VERIFICATION ───────────────────────────────────────────
            _sectionHeader('Verification'),
            _tile(Icons.verified_outlined, 'Verification Dashboard',
                subtitle: 'Status, badges, requirements & history',
                onTap: () => context.push('/settings/verification')),
            _divider(),

            // ── 9. PORTFOLIO ──────────────────────────────────────────────
            _sectionHeader('Portfolio'),
            _tile(Icons.analytics_outlined, 'Portfolio Analytics & Links',
                subtitle: 'Views, shares, copy portfolio link',
                onTap: () => context.push('/settings/portfolio')),
            _divider(),

            // ── 10. APP PREFERENCES ───────────────────────────────────────
            _sectionHeader('App Preferences'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _prefDropdown(
                    label: 'Theme',
                    value: settings.appPreferences.theme,
                    items: const {
                      'dark': 'Dark',
                      'light': 'Light',
                      'system': 'System Default'
                    },
                    onChanged: (v) {
                      if (v != null) actions.updateTheme(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _prefDropdown(
                    label: 'Language',
                    value: settings.appPreferences.language,
                    items: const {
                      'en': 'English',
                      'es': 'Español',
                      'fr': 'Français',
                      'pt': 'Português'
                    },
                    onChanged: (v) {
                      if (v != null) actions.updateLanguage(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _prefDropdown(
                    label: 'Units',
                    value: settings.appPreferences.units,
                    items: const {
                      'metric': 'Metric (kg, cm)',
                      'imperial': 'Imperial (lbs, ft)'
                    },
                    onChanged: (v) {
                      if (v != null) actions.updateUnits(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _prefDropdown(
                    label: 'Time Zone',
                    value: settings.appPreferences.timeZone,
                    items: const {
                      'UTC': 'UTC',
                      'America/New_York': 'Eastern (ET)',
                      'America/Chicago': 'Central (CT)',
                      'America/Los_Angeles': 'Pacific (PT)',
                      'Europe/London': 'London (GMT)',
                      'Asia/Kolkata': 'India (IST)',
                      'Asia/Dubai': 'Dubai (GST)',
                    },
                    onChanged: (v) {
                      if (v != null) actions.updateTimeZone(v);
                    },
                  ),
                ],
              ),
            ),
            _divider(),

            // ── 11. DATA MANAGEMENT ───────────────────────────────────────
            _sectionHeader('Data Management'),
            _tile(Icons.download_outlined, 'Download My Data', onTap: () async {
              try {
                _snack('Preparing data export...');
                final result =
                    await ref.read(accountActionsProvider).downloadMyData();
                _snack(result);
              } catch (e) {
                _snack('Error: $e');
              }
            }),
            _tile(Icons.upload_file_outlined, 'Export Portfolio',
                onTap: () => context.push('/settings/portfolio')),
            _tile(
                Icons.workspace_premium_outlined, 'Request Verification Status',
                onTap: () => context.push('/settings/verification')),
            _tile(Icons.cleaning_services_outlined, 'Clear App Cache',
                onTap: () async {
              await ref.read(accountActionsProvider).clearAppCache();
              _snack('Cache cleared successfully.');
            }),
            _divider(),

            // ── 12. CONNECTED SERVICES (future) ───────────────────────────
            _sectionHeader('Connected Services'),
            _futureTile(Icons.favorite_border, 'Apple Health',
                onTap: () => context.push('/settings/connected/apple-health')),
            _futureTile(Icons.run_circle_outlined, 'Google Fit',
                onTap: () => context.push('/settings/connected/google-fit')),
            _futureTile(Icons.watch_outlined, 'Garmin',
                onTap: () => context.push('/settings/connected/garmin')),
            _futureTile(Icons.watch_later_outlined, 'Fitbit',
                onTap: () => context.push('/settings/connected/fitbit')),
            _futureTile(Icons.directions_bike_outlined, 'Strava',
                onTap: () => context.push('/settings/connected/strava')),
            _divider(),

            // ── 13. MANAGE DEVICES (future) ───────────────────────────────
            _sectionHeader('Manage Devices'),
            _tile(Icons.devices_rounded, 'Active Devices',
                subtitle: 'View all devices with active sessions',
                onTap: () => context.push('/settings/devices')),
            _divider(),

            // ── 14. HELP & SUPPORT ────────────────────────────────────────
            _sectionHeader('Help & Support'),
            _tile(Icons.help_outline, 'Help Center',
                onTap: () => context.push('/settings/help')),
            _tile(Icons.support_agent_outlined, 'Contact Support',
                onTap: () => context.push('/settings/contact-support')),
            _tile(Icons.people_outline, 'Community Guidelines',
                onTap: () => context.push('/settings/community-guidelines')),
            _tile(Icons.stars_outlined, 'Athlete Verification Guidelines',
                onTap: () => context.push('/settings/verification-guidelines')),
            _tile(Icons.privacy_tip_outlined, 'Privacy Policy',
                onTap: () => context.push('/settings/privacy-policy')),
            _tile(Icons.article_outlined, 'Terms & Conditions',
                onTap: () => context.push('/settings/terms')),
            _tile(Icons.flag_outlined, 'Report a Problem',
                onTap: () => context.push('/settings/report-problem')),
            _divider(),

            // ── 15. ABOUT ─────────────────────────────────────────────────
            _sectionHeader('About'),
            _tile(Icons.info_outline, 'App Version',
                subtitle: packageInfo == null
                    ? 'Loading...'
                    : 'ATHELEOS v${packageInfo.version} (Build ${packageInfo.buildNumber})',
                onTap: null),
            _tile(Icons.new_releases_outlined, 'Release Notes',
                onTap: () => context.push('/settings/release-notes')),
            _tile(Icons.code_outlined, 'Open Source Licenses',
                onTap: () => showLicensePage(context: context)),
            const SizedBox(height: 32),

            // Branding footer
            Center(
              child: Text(
                'ATHELEOS • Professional Sports Network',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white12, fontSize: 10, letterSpacing: 0.5),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Divider(color: Colors.white10, height: 1),
        ]),
      );

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Divider(color: Colors.white10, height: 1),
      );

  Widget _tile(
    IconData icon,
    String label, {
    String? subtitle,
    VoidCallback? onTap,
    bool danger = false,
  }) =>
      ListTile(
        leading: Icon(icon,
            color: danger ? Colors.redAccent : AppTheme.primaryColor, size: 20),
        title: Text(label,
            style: GoogleFonts.inter(
                color: danger ? Colors.redAccent : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11))
            : null,
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: Colors.white24, size: 18)
            : null,
        onTap: onTap,
        dense: true,
        horizontalTitleGap: 12,
      );

  Widget _futureTile(IconData icon, String label, {VoidCallback? onTap}) =>
      ListTile(
        leading: Icon(icon, color: Colors.white24, size: 20),
        title: Text(label,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 13)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('SOON',
              style: TextStyle(
                  color: Colors.white24,
                  fontSize: 8,
                  fontWeight: FontWeight.bold)),
        ),
        dense: true,
        horizontalTitleGap: 12,
        onTap: onTap,
      );

  Widget _toggleTile(String label, bool value,
          {String? subtitle, required void Function(bool) onChanged}) =>
      SwitchListTile.adaptive(
        title: Text(label,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11))
            : null,
        value: value,
        activeColor: AppTheme.primaryColor,
        onChanged: onChanged,
        dense: true,
      );

  Widget _prefDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white60)),
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
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
              items: items.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]);
}

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
      title: Text('Change Phone Number',
          style: GoogleFonts.spaceGrotesk(
              color: Colors.white, fontWeight: FontWeight.bold)),
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
                  borderSide: BorderSide.none),
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
                    borderSide: BorderSide.none),
              ),
            ),
          ]
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white38))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black),
          onPressed: _isLoading
              ? null
              : () async {
                  final phone = _phoneC.text.trim();
                  if (phone.isEmpty) return;

                  final actions = ref.read(accountActionsProvider);
                  setState(() => _isLoading = true);

                  try {
                    if (!_otpSent) {
                      // Send OTP
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
                          _snack('Failed: $err');
                        },
                      );
                    } else {
                      // Verify OTP
                      final code = _otpC.text.trim();
                      if (code.isEmpty || _verificationId == null) {
                        setState(() => _isLoading = false);
                        return;
                      }

                      await actions.verifyPhoneUpdateOTP(
                          _verificationId!, code, phone);
                      Navigator.pop(context);
                      _snack('Phone number updated successfully.');
                    }
                  } catch (e) {
                    setState(() => _isLoading = false);
                    _snack('Error: $e');
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2))
              : Text(_otpSent ? 'Verify' : 'Send Code',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
