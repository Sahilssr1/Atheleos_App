import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/upload_queue_coordinator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../controllers/profile_controller.dart';
import '../controllers/settings_controller.dart';

class SafetyUsersScreen extends ConsumerStatefulWidget {
  final bool blocked;

  const SafetyUsersScreen.blocked({super.key}) : blocked = true;
  const SafetyUsersScreen.muted({super.key}) : blocked = false;

  @override
  ConsumerState<SafetyUsersScreen> createState() => _SafetyUsersScreenState();
}

class _SafetyUsersScreenState extends ConsumerState<SafetyUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final idsAsync = ref.watch(
      widget.blocked ? blockedUsersStreamProvider : mutedUsersStreamProvider,
    );
    final profiles = ref.watch(profileListProvider).valueOrNull ?? [];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.blocked ? 'BLOCKED USERS' : 'MUTED USERS'),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search users',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: idsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    UserFacingError.message(error, fallback: 'Unable to load list. Please try again.'),
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (ids) {
                final filteredIds = ids.where((id) {
                  final profile =
                      profiles.where((item) => item.id == id).firstOrNull;
                  final searchable =
                      '${profile?.name ?? ''} ${profile?.username ?? ''} $id'
                          .toLowerCase();
                  return searchable.contains(_query);
                }).toList();
                if (filteredIds.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? widget.blocked
                              ? 'No blocked users.'
                              : 'No muted users.'
                          : 'No matching users.',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filteredIds.length,
                  itemBuilder: (context, index) {
                    final userId = filteredIds[index];
                    final profile =
                        profiles.where((item) => item.id == userId).firstOrNull;
                    return ListTile(
                      onTap: () => context.push('/profile/$userId'),
                      leading: CircleAvatar(
                        backgroundImage: (profile?.avatarUrl ?? '').isEmpty
                            ? null
                            : NetworkImage(profile!.avatarUrl),
                        child: (profile?.avatarUrl ?? '').isEmpty
                            ? const Icon(Icons.person_outline)
                            : null,
                      ),
                      title: Text(profile?.name ?? 'Atheleos user'),
                      subtitle: Text(
                          profile == null ? userId : '@${profile.username}'),
                      trailing: TextButton(
                        onPressed: () async {
                          final actions = ref.read(settingsActionsProvider);
                          if (widget.blocked) {
                            await actions.unblockUser(userId);
                          } else {
                            await actions.unmuteUser(userId);
                          }
                        },
                        child: Text(widget.blocked ? 'Unblock' : 'Unmute'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class HiddenKeywordsScreen extends ConsumerStatefulWidget {
  const HiddenKeywordsScreen({super.key});

  @override
  ConsumerState<HiddenKeywordsScreen> createState() =>
      _HiddenKeywordsScreenState();
}

class _HiddenKeywordsScreenState extends ConsumerState<HiddenKeywordsScreen> {
  final _keywordController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keywordsAsync = ref.watch(hiddenKeywordsStreamProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text('HIDDEN KEYWORDS'), backgroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordController,
                    decoration: const InputDecoration(labelText: 'Add keyword'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  tooltip: 'Add keyword',
                  onPressed: _add,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search keywords',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: keywordsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      UserFacingError.message(error, fallback: 'Unable to load keywords. Please try again.'),
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (keywords) {
                  final filtered = keywords
                      .where(
                          (keyword) => keyword.toLowerCase().contains(_query))
                      .toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No hidden keywords.',
                          style: TextStyle(color: Colors.white54)),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final keyword = filtered[index];
                      return ListTile(
                        leading: const Icon(Icons.filter_alt_outlined),
                        title: Text(keyword),
                        trailing: IconButton(
                          tooltip: 'Remove keyword',
                          onPressed: () => ref
                              .read(settingsActionsProvider)
                              .removeHiddenKeyword(keyword),
                          icon: const Icon(Icons.close),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add() async {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) return;
    await ref.read(settingsActionsProvider).addHiddenKeyword(keyword);
    _keywordController.clear();
  }
}

class ReportHistoryScreen extends ConsumerWidget {
  const ReportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(reportHistoryProvider);
    final preferences = ref.watch(appPreferencesProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text('REPORT HISTORY'), backgroundColor: Colors.black),
      body: reportsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              UserFacingError.message(error, fallback: 'Unable to load report history. Please try again.'),
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (reports) {
          if (reports.isEmpty) {
            return const Center(
              child: Text('No reports submitted.',
                  style: TextStyle(color: Colors.white54)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const Divider(color: Colors.white12),
            itemBuilder: (context, index) {
              final report = reports[index];
              final status = report['status'] as String? ?? 'submitted';
              final resolution = report['resolution'] as String? ?? '';
              final createdAt = report['createdAt'] as Timestamp?;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined,
                    color: AppTheme.primaryColor),
                title: Text(report['description'] as String? ?? 'Report'),
                subtitle: Text([
                  if (createdAt != null)
                    formatSettingsDateTime(createdAt.toDate(), preferences),
                  if (resolution.isNotEmpty) resolution,
                ].join('\n')),
                trailing: Chip(label: Text(status.toUpperCase())),
              );
            },
          );
        },
      ),
    );
  }
}

class ReportProblemScreen extends ConsumerStatefulWidget {
  final bool supportRequest;

  const ReportProblemScreen({super.key, this.supportRequest = false});

  @override
  ConsumerState<ReportProblemScreen> createState() =>
      _ReportProblemScreenState();
}

class _ReportProblemScreenState extends ConsumerState<ReportProblemScreen> {
  final _descriptionController = TextEditingController();
  final List<String> _screenshots = [];
  bool _loading = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _attachScreenshot() async {
    if (_screenshots.length >= 3) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    setState(() => _loading = true);
    try {
      final idempotencyKey = const Uuid().v4();
      final queue = ref.read(uploadQueueProvider.notifier);
      final taskId = await queue.addTask(
        bytes: kIsWeb ? await image.readAsBytes() : null,
        filePath: kIsWeb ? null : image.path,
        fileName: image.name,
        ownerType: 'report',
        idempotencyKey: idempotencyKey,
      );

      UploadTask? completedTask;
      await for (final tasks in ref.read(uploadQueueProvider.notifier).stream) {
        final t = tasks.where((t) => t.id == taskId).firstOrNull;
        if (t == null) break;
        if (t.status == UploadStatus.completed) {
          completedTask = t;
          break;
        }
        if (t.status == UploadStatus.failed || t.status == UploadStatus.cancelled) {
          throw Exception(t.errorMessage ?? 'Upload failed');
        }
      }

      if (completedTask == null || completedTask.mediaId == null) {
        throw Exception('Report screenshot task failed to return media ID');
      }

      final doc = await FirebaseFirestore.instance.collection('media').doc(completedTask.mediaId).get();
      final urls = doc.data()?['urls'] as Map?;
      final url = urls?['original'] as String?;
      if (url == null) {
        throw Exception('Report image variant URL is missing.');
      }
      if (!mounted) return;
      setState(() {
        _screenshots.add(url);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserFacingError.message(error, fallback: 'Screenshot upload failed. Please try again.'))),
      );
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least 10 characters.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(accountActionsProvider).reportProblem(
            description,
            currentScreen: widget.supportRequest
                ? '/settings/contact-support'
                : '/settings/report-problem',
            screenshotUrls: _screenshots,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.supportRequest
              ? 'Support request submitted.'
              : 'Problem report submitted.'),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(UserFacingError.message(error, fallback: 'Failed to submit report. Please try again.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            widget.supportRequest ? 'CONTACT SUPPORT' : 'REPORT A PROBLEM'),
        backgroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _descriptionController,
            minLines: 6,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: widget.supportRequest
                  ? 'How can we help?'
                  : 'Describe the problem',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed:
                _loading || _screenshots.length >= 3 ? null : _attachScreenshot,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Attach Screenshot (${_screenshots.length}/3)'),
          ),
          if (_screenshots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _screenshots
                    .map((url) => Stack(
                          children: [
                            Image.network(url,
                                width: 88, height: 88, fit: BoxFit.cover),
                            Positioned(
                              right: 0,
                              child: IconButton.filled(
                                tooltip: 'Remove screenshot',
                                onPressed: () =>
                                    setState(() => _screenshots.remove(url)),
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Your user ID, device, OS, app version, current screen, and submission time are included automatically.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const topics = <(String, String)>[
      (
        'Account access',
        'Use password reset, verified phone, or your connected Google account to recover access.'
      ),
      (
        'Profile and portfolio',
        'Keep identity, athletic details, links, and privacy controls current from Settings.'
      ),
      (
        'Messaging and safety',
        'Control message access, block or mute accounts, and manage hidden keywords.'
      ),
      (
        'Verification',
        'Review eligibility, documents, application status, and history in the Verification Dashboard.'
      ),
      (
        'Reports and support',
        'Report safety concerns or technical issues. Submitted reports remain visible in Report History.'
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text('HELP CENTER'), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: topics
            .map((topic) => ExpansionTile(
                  title: Text(topic.$1),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(topic.$2,
                        style:
                            const TextStyle(color: Colors.white70, height: 1.5))
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class SettingsDocumentScreen extends StatelessWidget {
  final String title;
  final List<(String, String)> sections;

  const SettingsDocumentScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(title), backgroundColor: Colors.black),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.$1.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(section.$2,
                  style: const TextStyle(color: Colors.white70, height: 1.6)),
            ],
          );
        },
      ),
    );
  }

  static const communityGuidelines = <(String, String)>[
    (
      'Be authentic',
      'Use accurate identity and athletic information. Do not impersonate athletes, teams, coaches, or organizations.'
    ),
    (
      'Respect others',
      'Harassment, threats, hate, sexual exploitation, and targeted abuse are not permitted.'
    ),
    (
      'Protect safety',
      'Do not share private information without permission. Report urgent risks to local authorities and use in-app reporting.'
    ),
    (
      'Keep competition fair',
      'Do not falsify results, credentials, affiliations, media, or verification documents.'
    ),
    (
      'Enforcement',
      'Content may be restricted and accounts may be suspended or marked deleted after review.'
    ),
  ];

  static const verificationGuidelines = <(String, String)>[
    (
      'Eligibility',
      'Applicants must represent themselves or an authorized sports organization and maintain a substantially complete profile.'
    ),
    (
      'Documents',
      'Submit clear, current documents from official issuers. Sensitive information not required for review should be redacted.'
    ),
    (
      'Review',
      'Applications may be pending, under review, approved, rejected, or returned for more information.'
    ),
    (
      'Badges',
      'Badges represent the evidence reviewed at the time of approval and may be removed if information becomes inaccurate.'
    ),
    (
      'Reapplication',
      'Rejected applicants may reapply when eligible with corrected or additional evidence.'
    ),
  ];

  static const privacyPolicy = <(String, String)>[
    (
      'Information collected',
      'We process account identifiers, profile details, athletic content, messages, device diagnostics, and verification materials needed to operate Atheleos.'
    ),
    (
      'How information is used',
      'Information supports authentication, discovery, communication, safety, verification, analytics, and service improvement.'
    ),
    (
      'Visibility controls',
      'Profiles support field-level privacy controls. Settings changes are applied to public profile rendering in real time.'
    ),
    (
      'Retention',
      'Account deletion marks the account deleted and prevents access. Some records are retained for security, integrity, legal, and future server-side cleanup workflows.'
    ),
    (
      'Contact',
      'Use Contact Support for privacy requests or questions about account information.'
    ),
  ];

  static const terms = <(String, String)>[
    (
      'Using Atheleos',
      'You must provide accurate information, secure your credentials, and use the service lawfully.'
    ),
    (
      'Your content',
      'You retain ownership of your content and grant Atheleos the rights needed to host, display, and deliver it through the service.'
    ),
    (
      'Prohibited conduct',
      'Do not abuse the platform, evade safety controls, scrape private data, upload unlawful material, or interfere with service operation.'
    ),
    (
      'Availability',
      'Features may change and connected-service integrations may depend on third-party availability.'
    ),
    (
      'Account action',
      'We may restrict access to protect users, comply with law, or enforce platform rules.'
    ),
  ];

  static const releaseNotes = <(String, String)>[
    (
      'Version 1.0.0',
      'Initial Atheleos release with athlete profiles, portfolio analytics, posts and clips, messaging, events, verification workflows, privacy controls, and account recovery settings.'
    ),
    (
      'Settings and safety',
      'Added real-time preference sync, blocked and muted user management, hidden keywords, report history, device information, and verified account mutation flows.'
    ),
  ];
}
