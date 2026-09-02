import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../domain/models/profile_model.dart';
import '../../domain/repositories/user_repository.dart';
import '../../data/repositories/dummy_user_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../../../core/services/cache_manager.dart';
import '../../../../core/services/network_service.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/domain/models/notification_model.dart';

enum UserRepositoryType { dummy, firestore }

// Create a single shared instance of DummyUserRepository to maintain session-wide state
final _sharedUserRepository = DummyUserRepository();

// Provider for the Dummy UserRepository
final dummyUserRepositoryProvider = Provider<UserRepository>((ref) {
  return _sharedUserRepository;
});

// Provider for the Firestore UserRepository
final firestoreUserRepositoryProvider = Provider<UserRepository>((ref) {
  return FirestoreUserRepository();
});

// Selector for UserRepository based on active type
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
  return 'user_1';
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
  final listAsync = ref.watch(profileListProvider);
  final loggedInId = ref.watch(loggedInUserIdProvider);

  return listAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (list) {
      try {
        final profile = list.firstWhere((p) => p.id == loggedInId);
        return AsyncValue.data(profile);
      } catch (_) {
        return const AsyncValue.data(null);
      }
    },
  );
});

// Reactive provider for the active profile being viewed (compatible with profile_screen.dart)
final activeProfileProvider = Provider<AsyncValue<ProfileModel?>>((ref) {
  final listAsync = ref.watch(profileListProvider);
  final activeId = ref.watch(currentProfileIdProvider);

  return listAsync.when(
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
    data: (list) {
      try {
        final profile = list.firstWhere((p) => p.id == activeId);
        return AsyncValue.data(profile);
      } catch (_) {
        return const AsyncValue.data(null);
      }
    },
  );
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
      }
      state = AsyncValue.data(user);
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
        }
        state = AsyncValue.data(updated);
        _ref.read(profileListProvider.notifier).loadAllProfiles();

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
  Future<void> submitVerification(Map<String, dynamic> requestDetails) async {
    if (state is AsyncData<ProfileModel?>) {
      final currentProfile = state.asData!.value;
      if (currentProfile == null) return;

      final updatedProfile = currentProfile.copyWith(
        verificationStatus: 'pending',
        verificationRequestDetails: requestDetails,
        verificationRejectedReason: '',
      );

      await _repository.updateUser(updatedProfile);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId)
          .collection('verification_applications')
          .add({
        ...requestDetails,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      state = AsyncValue.data(updatedProfile);
      _ref.read(profileListProvider.notifier).loadAllProfiles();

      // Self-notification confirming the submission (also email-eligible).
      unawaited(NotificationService.instance.system(
        receiverId: _userId,
        type: NotificationType.verificationSubmitted,
        title: 'Verification submitted',
        body: 'Your verification request was submitted and is under review.',
        emailSubject: 'ATHELEOS — Verification request received',
        emailHtml:
            '<p>Your verification request was submitted and is now under review. '
            'We will notify you once a decision has been made.</p>',
      ));
    }
  }

  /// Perform an administrative action (simulation)
  Future<void> adminAction({
    required String status,
    String? badge,
    int? level,
    String? rejectedReason,
  }) async {
    if (state is AsyncData<ProfileModel?>) {
      final currentProfile = state.asData!.value;
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

      await _repository.updateUser(updatedProfile);
      state = AsyncValue.data(updatedProfile);
      _ref.read(profileListProvider.notifier).loadAllProfiles();

      // Notify the applicant of the decision.
      final decisionType = switch (status) {
        'approved' => NotificationType.verificationApproved,
        'rejected' => NotificationType.verificationRejected,
        'more_info' => NotificationType.verificationMoreInfo,
        _ => null,
      };
      if (decisionType != null) {
        unawaited(NotificationService.instance.system(
          receiverId: _userId,
          type: decisionType,
          body: status == 'rejected'
              ? 'Your verification request was declined: '
                  '${rejectedReason ?? 'Documents did not meet criteria.'}'
              : null,
          emailSubject: 'ATHELEOS — Verification update',
        ));
      }
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
