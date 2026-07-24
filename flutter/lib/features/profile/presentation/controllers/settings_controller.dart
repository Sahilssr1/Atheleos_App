import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as timezone;
import '../../../../core/services/cache_manager.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/user_settings_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

// ---------------------------------------------------------------------------
// Firestore path: /users/{userId}/settings/preferences
// ---------------------------------------------------------------------------

final _firestore = FirebaseFirestore.instance;

final packageInfoProvider =
    FutureProvider<PackageInfo>((ref) => PackageInfo.fromPlatform());

/// Real-time stream from Firestore for the current user's settings.
final userSettingsStreamProvider = StreamProvider<UserSettingsModel>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('preferences')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return UserSettingsModel.defaults();
    return UserSettingsModel.fromMap(snap.data() ?? {});
  });
});

final appPreferencesProvider = Provider<AppPreferences>((ref) {
  return ref.watch(userSettingsStreamProvider).valueOrNull?.appPreferences ??
      const AppPreferences();
});

String formatSettingsDateTime(DateTime value, AppPreferences preferences) {
  timezone.Location location;
  try {
    location = timezone.getLocation(preferences.timeZone);
  } catch (_) {
    location = timezone.UTC;
  }
  final date = timezone.TZDateTime.from(value, location);
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)} ${date.timeZoneName}';
}

final publicUserSettingsProvider =
    StreamProvider.family<UserSettingsModel, String>((ref, userId) {
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('settings')
      .doc('preferences')
      .snapshots()
      .map((snap) {
    if (!snap.exists) return UserSettingsModel.defaults();
    return UserSettingsModel.fromMap(snap.data() ?? {});
  });
});

final blockedByUserProvider =
    FutureProvider.family<bool, String>((ref, profileId) async {
  final viewerId = ref.watch(loggedInUserIdProvider);
  if (viewerId.isEmpty || viewerId == profileId) return false;
  final block = await _firestore
      .collection('users')
      .doc(profileId)
      .collection('blocked_users')
      .doc(viewerId)
      .get();
  return block.exists;
});

final hiddenKeywordsStreamProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('hidden_keywords')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => (doc.data()['keyword'] ?? '') as String)
          .where((k) => k.isNotEmpty)
          .toList());
});

final blockedUsersStreamProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('blocked_users')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toList());
});

final mutedUsersStreamProvider = StreamProvider<List<String>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('muted_users')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.id).toList());
});

final reportHistoryProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('reports')
      .where('uid', isEqualTo: userId)
      .snapshots()
      .map((snapshot) {
    final reports =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    reports.sort((a, b) {
      final aTime = a['createdAt'] as Timestamp?;
      final bTime = b['createdAt'] as Timestamp?;
      return (bTime?.millisecondsSinceEpoch ?? 0)
          .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
    });
    return reports;
  });
});

final accountRecoveryProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore.collection('users').doc(userId).snapshots().map(
        (snapshot) => snapshot.data() ?? const <String, dynamic>{},
      );
});

final verificationApplicationsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return _firestore
      .collection('users')
      .doc(userId)
      .collection('verification_applications')
      .snapshots()
      .map((snapshot) {
    final applications =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    applications.sort((a, b) {
      final aTime = a['submittedAt'] as Timestamp?;
      final bTime = b['submittedAt'] as Timestamp?;
      return (bTime?.millisecondsSinceEpoch ?? 0)
          .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
    });
    return applications;
  });
});

/// Actions provider — writes changes back to Firestore.
final settingsActionsProvider = Provider<SettingsActions>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return SettingsActions(userId);
});

class SettingsActions {
  final String _userId;

  SettingsActions(this._userId);

  DocumentReference<Map<String, dynamic>> get _doc => _firestore
      .collection('users')
      .doc(_userId)
      .collection('settings')
      .doc('preferences');

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _patch(Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _doc.set(data, SetOptions(merge: true));
  }

  // ── Privacy ──────────────────────────────────────────────────────────────

  Future<void> updatePrivacy(String key, bool value) =>
      _patch({'privacy.$key': value});

  // ── Messaging ────────────────────────────────────────────────────────────

  Future<void> updateAllowedSenders(String value) =>
      _patch({'messaging.allowedSenders': value});

  Future<void> updateMessagingBool(String key, bool value) =>
      _patch({'messaging.$key': value});

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> toggleNotification(String key, bool value) =>
      _patch({'notifications.$key': value});

  // ── App Preferences ───────────────────────────────────────────────────────

  Future<void> updateTheme(String theme) =>
      _patch({'appPreferences.theme': theme});

  Future<void> updateLanguage(String lang) =>
      _patch({'appPreferences.language': lang});

  Future<void> updateUnits(String units) =>
      _patch({'appPreferences.units': units});

  Future<void> updateTimeZone(String tz) =>
      _patch({'appPreferences.timeZone': tz});

  // ── Safety — blocked / muted keywords ────────────────────────────────────

  Future<void> addHiddenKeyword(String keyword) async {
    final docId = keyword.toLowerCase().trim();
    if (docId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('hidden_keywords')
        .doc(docId)
        .set({
      'keyword': keyword.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeHiddenKeyword(String keyword) async {
    final docId = keyword.toLowerCase().trim();
    if (docId.isEmpty) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('hidden_keywords')
        .doc(docId)
        .delete();
  }

  // ── Safety — block / mute users ──────────────────────────────────────────

  Future<void> blockUser(String uid) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('blocked_users')
        .doc(uid)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unblockUser(String uid) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('blocked_users')
        .doc(uid)
        .delete();
  }

  Future<void> muteUser(String uid) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('muted_users')
        .doc(uid)
        .set({'createdAt': FieldValue.serverTimestamp()});
  }

  Future<void> unmuteUser(String uid) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('muted_users')
        .doc(uid)
        .delete();
  }

  // ── Initialise defaults for brand-new users ───────────────────────────────

  Future<void> ensureDefaults() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      await _doc.set(UserSettingsModel.defaults().toMap());
    }
  }
}

/// Actions provider — handles sensitive Account mutations (username, email, password, delete, etc.)
final accountActionsProvider = Provider<AccountSettingsActions>((ref) {
  final userId = ref.watch(loggedInUserIdProvider);
  return AccountSettingsActions(userId, ref);
});

class AccountSettingsActions {
  final String _userId;
  final Ref _ref;

  AccountSettingsActions(this._userId, this._ref);

  static const reservedUsernames = <String>{
    'admin',
    'administrator',
    'atheleos',
    'help',
    'login',
    'moderator',
    'official',
    'privacy',
    'settings',
    'support',
    'terms',
    'verified',
  };

  String validateUsername(String username) {
    final value = username.trim().toLowerCase();
    if (value.length < 3 || value.length > 30) {
      return 'Use between 3 and 30 characters.';
    }
    if (!RegExp(r'^[a-z0-9][a-z0-9._]*$').hasMatch(value)) {
      return 'Start with a letter or number and use only letters, numbers, periods, or underscores.';
    }
    if (value.contains('..') ||
        value.contains('__') ||
        value.endsWith('.') ||
        value.endsWith('_')) {
      return 'Periods and underscores cannot repeat or appear at the end.';
    }
    if (reservedUsernames.contains(value)) return 'This username is reserved.';
    return '';
  }

  Future<bool> isUsernameAvailable(String username) async {
    if (validateUsername(username).isNotEmpty) return false;
    final value = username.trim().toLowerCase();
    final usernameDoc =
        await _firestore.collection('usernames').doc(value).get();
    return !usernameDoc.exists || usernameDoc.data()?['uid'] == _userId;
  }

  // ── 1. Change Username (Transaction) ───────────────────────────────────────
  Future<void> changeUsername(String newUsername) async {
    final trimmed = newUsername.trim().toLowerCase();
    final validationError = validateUsername(trimmed);
    if (validationError.isNotEmpty) throw Exception(validationError);

    final usernamesRef = _firestore.collection('usernames').doc(trimmed);
    final userRef = _firestore.collection('users').doc(_userId);

    await _firestore.runTransaction((transaction) async {
      final usernameDoc = await transaction.get(usernamesRef);
      if (usernameDoc.exists) {
        if (usernameDoc.data()?['uid'] != _userId) {
          throw Exception('Username is already reserved by another user.');
        }
        transaction.set(
            userRef,
            {
              'username': trimmed,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        return;
      }

      final userDoc = await transaction.get(userRef);
      final oldUsername = userDoc.data()?['username'] as String?;

      if (oldUsername != null &&
          oldUsername.isNotEmpty &&
          oldUsername != trimmed) {
        transaction.delete(_firestore.collection('usernames').doc(oldUsername));
      }

      transaction.set(usernamesRef, {
        'uid': _userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(userRef, {
        'username': trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Invalidate local cache
    _ref.invalidate(universalProfileControllerProvider(_userId));
    _ref.invalidate(profileListProvider);
  }

  // ── 7. Data Management ─────────────────────────────────────────────────────

  Future<String> downloadMyData() async {
    final userDoc = await _firestore.collection('users').doc(_userId).get();
    final settingsDoc = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('settings')
        .doc('preferences')
        .get();

    final exportData = {
      'profile': userDoc.data() ?? {},
      'settings': settingsDoc.data() ?? {},
      'exportDate': DateTime.now().toIso8601String(),
    };

    final jsonString = jsonEncode(exportData);
    final fileName =
        'atheleos-data-${DateTime.now().toIso8601String().split('T').first}.json';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            utf8.encode(jsonString),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        subject: 'ATHELEOS data export',
        downloadFallbackEnabled: true,
      ),
    );
    return 'Data export ready. (${jsonString.length} bytes)';
  }

  Future<void> clearAppCache() async {
    await CacheManager().clearAll();
  }

  // ── 8. Help & Support ──────────────────────────────────────────────────────

  Future<void> reportProblem(
    String description, {
    String currentScreen = '/settings/report-problem',
    List<String> screenshotUrls = const [],
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final deviceInfo = await DeviceInfoPlugin().deviceInfo;
    final deviceData = deviceInfo.data;

    final reportData = {
      'uid': _userId,
      'description': description,
      'device': deviceData,
      'os': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'osVersion': (deviceData['systemVersion'] ??
              deviceData['version'] ??
              deviceData['osRelease'] ??
              '')
          .toString(),
      'appVersion': packageInfo.version,
      'buildNumber': packageInfo.buildNumber,
      'currentScreen': currentScreen,
      'screenshotUrls': screenshotUrls,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
      'resolution': '',
    };

    await _firestore.collection('reports').add(reportData);
  }

  // ── 2. Change Email ────────────────────────────────────────────────────────
  Future<void> changeEmail(String newEmail) async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.changeEmail(newEmail);
  }

  Future<void> completeEmailChange(String expectedEmail) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (refreshedUser?.email?.toLowerCase() !=
        expectedEmail.trim().toLowerCase()) {
      throw Exception(
          'The new email has not been verified yet. Open the verification link, then try again.');
    }
    await _firestore.collection('users').doc(_userId).set({
      'email': refreshedUser!.email,
      'googleEmail': refreshedUser.email,
      'emailVerified': refreshedUser.emailVerified,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> refreshConnectedGoogleAccount() async {
    await _ref.read(authRepositoryProvider).reauthenticate();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    await _firestore.collection('users').doc(_userId).set({
      'googleEmail': refreshed?.email ?? '',
      'googlePhotoUrl': refreshed?.photoURL ?? '',
      'googleVerified': refreshed?.emailVerified ?? false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendAlternateEmailVerification(String email) async {
    final normalized = email.trim().toLowerCase();
    await FirebaseAuth.instance.sendSignInLinkToEmail(
      email: normalized,
      actionCodeSettings: ActionCodeSettings(
        url: 'https://atheleos.com/settings/alternate-email',
        handleCodeInApp: true,
        androidPackageName: 'com.atheleos.atheleos',
        androidInstallApp: true,
        iOSBundleId: 'com.atheleos.atheleos',
      ),
    );
    await _firestore.collection('users').doc(_userId).set({
      'pendingAlternateEmail': normalized,
      'alternateEmailVerificationSentAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> verifyAlternateEmail(String email, String emailLink) async {
    final normalized = email.trim().toLowerCase();
    if (!FirebaseAuth.instance.isSignInWithEmailLink(emailLink.trim())) {
      throw Exception('Paste the complete verification link from the email.');
    }

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('alternateEmailVerification');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'alternateEmailVerification',
        options: Firebase.app().options,
      );
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    final credential = await secondaryAuth.signInWithEmailLink(
      email: normalized,
      emailLink: emailLink.trim(),
    );
    if (credential.user?.email?.toLowerCase() != normalized) {
      await secondaryAuth.signOut();
      throw Exception('The verification link does not match this email.');
    }
    if (credential.additionalUserInfo?.isNewUser == true) {
      await credential.user?.delete();
    } else {
      await secondaryAuth.signOut();
    }
    await _firestore.collection('users').doc(_userId).set({
      'alternateEmail': normalized,
      'alternateEmailVerified': true,
      'pendingAlternateEmail': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── 3. Change Phone Number (OTP Flow) ──────────────────────────────────────
  Future<void> sendPhoneUpdateOTP({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(Exception error) onFailed,
  }) async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verId, _) => onCodeSent(verId),
      onFailed: onFailed,
    );
  }

  Future<void> verifyPhoneUpdateOTP(
      String verificationId, String smsCode, String newPhoneNumber) async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.updatePhoneNumber(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    // Update user profile
    await _firestore.collection('users').doc(_userId).update({
      'phoneNumber': newPhoneNumber,
      'phoneVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _ref.invalidate(universalProfileControllerProvider(_userId));
  }

  // ── 4. Change Password ─────────────────────────────────────────────────────
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.updatePassword(currentPassword, newPassword);
  }

  Future<void> setRecoveryPhone(String phoneNumber) async {
    await _firestore.collection('users').doc(_userId).set({
      'recoveryPhone': phoneNumber,
      'recoveryPhoneVerified': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── 4. Delete Account (Soft Delete) ────────────────────────────────────────
  Future<void> deleteAccount({String? password}) async {
    await _ref.read(authRepositoryProvider).reauthenticate(password: password);
    final userRef = _firestore.collection('users').doc(_userId);

    await userRef.update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletionVersion': 1,
    });

    // Sign out to enforce the block (Auth logic blocks login if isDeleted = true)
    await signOut();
  }

  // ── 3. Sign Out ────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await clearAppCache();
    await _ref.read(authControllerProvider.notifier).signOut();
    _ref.invalidate(userSettingsStreamProvider);
    _ref.invalidate(profileListProvider);
    _ref.invalidate(universalProfileControllerProvider(_userId));
  }
}
