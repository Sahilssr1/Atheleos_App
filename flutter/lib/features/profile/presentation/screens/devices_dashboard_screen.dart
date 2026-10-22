import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/user_facing_error.dart';
import '../controllers/profile_controller.dart';
import 'package:atheleos/core/widgets/ath_icons.dart';

final currentDeviceSessionProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(loggedInUserIdProvider);
  if (userId.isEmpty) {
    throw StateError('Sign in to view active devices.');
  }
  final device = await DeviceInfoPlugin().deviceInfo;
  final packageInfo = await PackageInfo.fromPlatform();
  final data = device.data;
  final identifier = (data['identifierForVendor'] ??
          data['id'] ??
          data['deviceId'] ??
          data['userAgent'] ??
          'current-device')
      .toString();
  final sessionId = identifier.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
  final name = (data['name'] ??
          data['model'] ??
          data['device'] ??
          data['browserName'] ??
          platform)
      .toString();
  final session = <String, dynamic>{
    'id': sessionId,
    'name': name,
    'platform': platform,
    'osVersion':
        (data['systemVersion'] ?? data['version'] ?? data['osRelease'] ?? '')
            .toString(),
    'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
    'isCurrent': true,
    'lastActive': FieldValue.serverTimestamp(),
  };
  await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('sessions')
      .doc(sessionId)
      .set(session, SetOptions(merge: true));
  return {...session, 'lastActive': DateTime.now()};
});

class DevicesDashboardScreen extends ConsumerWidget {
  const DevicesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(currentDeviceSessionProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text('ACTIVE DEVICES'), backgroundColor: Colors.black),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  UserFacingError.message(error, fallback: 'Unable to load device details. Please try again.'),
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        data: (session) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'ACTIVE SESSION',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: Icon(
                session['platform'] == 'macos' ||
                        session['platform'] == 'windows'
                    ? AthIcons.cpuChip
                    : AthIcons.devicePhoneMobile,
                color: AppTheme.primaryColor,
              ),
              title: Text(session['name'] as String),
              subtitle: Text([
                session['platform'],
                if ((session['osVersion'] as String).isNotEmpty)
                  session['osVersion'],
                'Atheleos ${session['appVersion']}',
                'Active now',
              ].join(' · ')),
              trailing: const Chip(label: Text('THIS DEVICE')),
            ),
            const SizedBox(height: 24),
            const Text(
              'The session schema supports multiple device records, last-active timestamps, and server-revoked sessions. Remote sign-out will be enabled when token revocation moves to Cloud Functions.',
              style:
                  TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
