import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../domain/models/profile_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/domain/models/notification_model.dart';

// Provider for the Firestore UserRepository
final firestoreUserRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

// Primary UserRepository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return ref.watch(firestoreUserRepositoryProvider);
});

// Profile list state notifier
class ProfileListNotifier extends StateNotifier<AsyncValue<List<ProfileModel>>> {
  final UserRepository _repository;

  ProfileListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadAllProfiles();
  }

  Future<void> loadAllProfiles() async {
    try {
      if (_repository is FirestoreUserRepository) {
        unawaited((_repository as FirestoreUserRepository).deleteLegacyBrandFederationProfiles());
      }
      final profiles = await _repository.getAllUsers();
      state = AsyncValue.data(profiles);
    } catch (err, stack) {
      state = AsyncValue.error(err, stack);
    }
  }

  Future<void> updateProfile(ProfileModel updated) async {
    if (state is AsyncData<List<ProfileModel>>) {
      final currentList = state.asData!.value;
      final updatedList =
          currentList.map((p) => p.id == updated.id ? updated : p).toList();
      state = AsyncValue.data(updatedList);
    }

    try {
      await _repository.updateUser(updated);
    } catch (err) {
      loadAllProfiles();
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await loadAllProfiles();
  }
}

final profileListProvider =
    StateNotifierProvider<ProfileListNotifier, AsyncValue<List<ProfileModel>>>(
        (ref) {
  final repo = ref.watch(userRepositoryProvider);
  return ProfileListNotifier(repo);
});

// State provider for the ID of the profile currently being viewed (defaults to authenticated user UID)
final currentProfileIdProvider = StateProvider<String>((ref) {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
  } catch (_) {}
  return '';
});

// Provider for the currently logged-in user ID (to distinguish own profile vs others)
final loggedInUserIdProvider = StateProvider<String>((ref) {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
  } catch (_) {}
  return '';
});

// Provider for the active logged-in user's profile model
final currentUserProvider = Provider<AsyncValue<ProfileModel?>>((ref) {
  final loggedInId = ref.watch(loggedInUserIdProvider);
  if (loggedInId.isNotEmpty) {
    return ref.watch(universalProfileControllerProvider(loggedInId));
  }

  // Fallback: If not logged in via Firebase Auth, use active profile or first available
  final activeId = ref.watch(currentProfileIdProvider);
  if (activeId.isNotEmpty) {
    return ref.watch(universalProfileControllerProvider(activeId));
  }

  return const AsyncValue.data(null);
});

// Reactive provider for the active profile being viewed (compatible with profile_screen.dart)
final activeProfileProvider = Provider<AsyncValue<ProfileModel?>>((ref) {
  final activeId = ref.watch(currentProfileIdProvider);
  final targetId = activeId.isNotEmpty ? activeId : ref.watch(loggedInUserIdProvider);

  if (targetId.isNotEmpty) {
    return ref.watch(universalProfileControllerProvider(targetId));
  }

  return const AsyncValue.data(null);
});

// === NEW REQUESTED PROVIDERS & CONTROLLERS ===

// UserProvider: Exposes any user profile by ID as a StreamProvider with instant cache loading
final userProvider = StreamProvider.family<ProfileModel?, String>((ref, id) async* {
  if (id.isEmpty) {
    yield null;
    return;
  }

  // 1. Instant in-memory resolution from profileListProvider (0ms)
  final allProfiles = ref.watch(profileListProvider).valueOrNull ?? [];
  try {
    final memoryMatch = allProfiles.firstWhere((p) => p.id == id || p.username == id);
    yield memoryMatch;
  } catch (_) {}

  final repository = ref.watch(userRepositoryProvider);
  final isOnline = ref.watch(networkServiceProvider.select((net) => net.isOnline));

  ProfileModel? cachedProfile;
  try {
    final cachedMap = CacheManager().loadProfile(id);
    if (cachedMap != null) {
      cachedProfile = ProfileModel.fromMap(cachedMap);
      yield cachedProfile;
    }
  } catch (_) {}

  if (isOnline) {
    try {
      final profile = await repository.getUserById(id);
      if (profile != null) {
        CacheManager().saveProfile(id, profile.toMap());
        if (cachedProfile == null ||
            cachedProfile.avatarUrl != profile.avatarUrl ||
            cachedProfile.name != profile.name ||
            cachedProfile.username != profile.username) {
          yield profile;
        }
      }
    } catch (_) {
      if (cachedProfile == null) {
        yield null;
      }
    }
  } else {
    if (cachedProfile == null) {
      yield null;
    }
  }
});

// UniversalProfileController: StateNotifier that manages follow/unfollow and loads any profile
class UniversalProfileController
    extends StateNotifier<AsyncValue<ProfileModel?>> {
  final UserRepository _repository;
  final String _userId;
  final Ref _ref;

  UniversalProfileController(this._repository, this._userId, this._ref)
      : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    // Check local cache first for instant load
    try {
      final cachedMap = CacheManager().loadProfile(_userId);
      if (cachedMap != null) {
        state = AsyncValue.data(ProfileModel.fromMap(cachedMap));
      }
    } catch (_) {}

    final isOnline = _ref.read(networkServiceProvider).isOnline;
    if (!isOnline && state is AsyncData<ProfileModel?>) {
      return; // Stop here if offline and cache loaded
    }

    try {
      final user = await _repository.getUserById(_userId);
      if (user != null) {
        CacheManager().saveProfile(_userId, user.toMap());
        state = AsyncValue.data(user);
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (err, stack) {
      if (state is! AsyncData<ProfileModel?>) {
        state = AsyncValue.error(err, stack);
      }
    }
  }

  Future<void> toggleFollow() async {
    if (state is AsyncData<ProfileModel?>) {
      final currentProfile = state.asData!.value;
      if (currentProfile == null) return;

      final nextFollowState = !currentProfile.isFollowing;
      final newFollowers = nextFollowState
          ? currentProfile.followersCount + 1
          : currentProfile.followersCount - 1;

      // Optimistically update UI
      final updatedProfile = currentProfile.copyWith(
        isFollowing: nextFollowState,
        followersCount: newFollowers,
      );
      state = AsyncValue.data(updatedProfile);

      final isOnline = _ref.read(networkServiceProvider).isOnline;
      if (!isOnline) {
        await _ref.read(offlineSyncProvider.notifier).queueAction(
          actionType: 'follow',
          targetId: _userId,
          data: {'isFollowing': nextFollowState},
        );
        return;
      }

      try {
        await _repository.updateFollowState(_userId, nextFollowState);
        final updated = await _repository.getUserById(_userId);
        if (updated != null) {
          CacheManager().saveProfile(_userId, updated.toMap());
          _ref.read(profileListProvider.notifier).updateProfile(updated);
        }
        state = AsyncValue.data(updated);

        // Emit a follow notification to the target only when following (not on unfollow).
        if (nextFollowState) {
          final me = _ref.read(currentUserProvider).valueOrNull;
          unawaited(NotificationService.instance.follow(
            receiverId: _userId,
            actor: NotificationActor(
              id: _ref.read(loggedInUserIdProvider),
              name: me?.name ?? 'Someone',
              avatar: me?.avatarUrl ?? '',
            ),
          ));
        }
      } catch (_) {
        await _ref.read(offlineSyncProvider.notifier).queueAction(
          actionType: 'follow',
          targetId: _userId,
          data: {'isFollowing': nextFollowState},
        );
      }
    }
  }

  /// Directly push an updated [ProfileModel] into this controller's state.
  /// Called by EditProfileScreen after saving so the ProfileLoader re-renders
  /// immediately without waiting for a Firestore round-trip.
  void syncProfile(ProfileModel updated) {
    if (updated.id == _userId) {
      state = AsyncValue.data(updated);
    }
  }

  /// Submit a verification request
  Future<void> submitVerification(
    Map<String, dynamic> requestDetails, {
    ProfileModel? fallbackProfile,
  }) async {
    ProfileModel? targetProfile = state.valueOrNull ?? fallbackProfile;

    if (targetProfile == null) {
      try {
        targetProfile = await _repository
            .getUserById(_userId)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    // Baseline fallback so we never fail silently
    targetProfile ??= ProfileModel(
      id: _userId,
      name: FirebaseAuth.instance.currentUser?.displayName ?? 'User',
      username: '',
      avatarUrl: FirebaseAuth.instance.currentUser?.photoURL ?? '',
      coverUrl: '',
      role: 'Athlete',
      verified: false,
      sport: '',
      primaryPosition: '',
      clubOrAcademy: '',
      city: '',
      state: '',
      bio: '',
      email: FirebaseAuth.instance.currentUser?.email ?? '',
      phoneNumber: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      dateOfBirth: '',
      gender: '',
      personalNotes: '',
      website: '',
      socialLinks: {},
      mediaGallery: [],
      followersCount: 0,
      followingCount: 0,
      postsCount: 0,
      clipsCount: 0,
      achievements: [],
      certifications: [],
    );

    final updatedProfile = targetProfile.copyWith(
      verificationStatus: 'pending',
      verificationRequestDetails: requestDetails,
      verificationRejectedReason: '',
    );

    // 1. Optimistically update local controller state, cache & active profile list
    state = AsyncValue.data(updatedProfile);
    try {
      CacheManager().saveProfile(_userId, updatedProfile.toMap());
    } catch (e) {
      debugPrint('CacheManager saveProfile note: $e');
    }
    _ref.read(profileListProvider.notifier).updateProfile(updatedProfile);

    // 2. Persist application to Firestore subcollection with safe timeout
    final targetUid = FirebaseAuth.instance.currentUser?.uid ?? _userId;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('verification_applications')
          .add({
        ...requestDetails,
        'userId': targetUid,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
      debugPrint('submitVerification: Added application to Firestore for $targetUid');
    } catch (e) {
      debugPrint('submitVerification: Subcollection write note (non-fatal): $e');
    }

    // 3. Persist profile document update with safe timeout
    try {
      await _repository.updateUser(updatedProfile).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('submitVerification: Repository updateUser note (non-fatal): $e');
    }

    // 4. Self-notification confirming submission (unawaited, non-blocking)
    try {
      unawaited(NotificationService.instance.system(
        receiverId: targetUid,
        type: NotificationType.verificationSubmitted,
        title: 'Verification submitted',
        body: 'Your verification request was submitted and is under review.',
        emailSubject: 'ATHELEOS — Verification request received',
        emailHtml:
            '<p>Your verification request was submitted and is now under review. '
            'We will notify you once a decision has been made.</p>',
      ));
    } catch (e) {
      debugPrint('submitVerification: Notification note: $e');
    }
  }

  /// Perform an administrative action (simulation)
  Future<void> adminAction({
    required String status,
    String? badge,
    int? level,
    String? rejectedReason,
    ProfileModel? fallbackProfile,
  }) async {
    ProfileModel? currentProfile = state.valueOrNull ?? fallbackProfile;
    if (currentProfile == null) {
      try {
        currentProfile = await _repository
            .getUserById(_userId)
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    if (currentProfile == null) return;

    final isApproved = status == 'approved';
    final updatedProfile = currentProfile.copyWith(
      verificationStatus: status,
      verified: isApproved ? true : currentProfile.verified,
      verificationBadge: isApproved
          ? (badge ?? currentProfile.verificationBadge)
          : currentProfile.verificationBadge,
      verificationLevel: isApproved
          ? (level ?? currentProfile.verificationLevel)
          : currentProfile.verificationLevel,
      verificationDate: isApproved
          ? DateTime.now().toIso8601String().split('T')[0]
          : currentProfile.verificationDate,
      verificationRejectedReason: status == 'rejected'
          ? (rejectedReason ?? 'Documents did not meet criteria.')
          : '',
    );

    // Immediate reactive updates
    state = AsyncValue.data(updatedProfile);
    try {
      CacheManager().saveProfile(_userId, updatedProfile.toMap());
    } catch (_) {}
    _ref.read(profileListProvider.notifier).updateProfile(updatedProfile);

    // Safe repository update
    try {
      await _repository.updateUser(updatedProfile).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('adminAction: updateUser note (non-fatal): $e');
    }

    // Update latest application in subcollection if exists
    try {
      final targetUid = FirebaseAuth.instance.currentUser?.uid ?? _userId;
      final apps = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('verification_applications')
          .orderBy('submittedAt', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      if (apps.docs.isNotEmpty) {
        await apps.docs.first.reference.update({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          if (rejectedReason != null) 'rejectedReason': rejectedReason,
        }).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('adminAction: subcollection update note: $e');
    }

    // Notify the applicant of the decision
    final decisionType = switch (status) {
      'approved' => NotificationType.verificationApproved,
      'rejected' => NotificationType.verificationRejected,
      'more_info' => NotificationType.verificationMoreInfo,
      _ => null,
    };
    if (decisionType != null) {
      try {
        unawaited(NotificationService.instance.system(
          receiverId: _userId,
          type: decisionType,
          body: status == 'rejected'
              ? 'Your verification request was declined: '
                  '${rejectedReason ?? 'Documents did not meet criteria.'}'
              : null,
          emailSubject: 'ATHELEOS — Verification update',
        ));
      } catch (_) {}
    }
  }
}

// Global provider for UniversalProfileController family
final universalProfileControllerProvider = StateNotifierProvider.family<
    UniversalProfileController,
    AsyncValue<ProfileModel?>,
    String>((ref, userId) {
  final repository = ref.watch(userRepositoryProvider);
  return UniversalProfileController(repository, userId, ref);
});
