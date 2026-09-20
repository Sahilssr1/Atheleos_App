import '../../domain/models/profile_model.dart';
import '../../domain/repositories/user_repository.dart';
import 'dummy_profile_repository.dart';

/// A dummy in-memory implementation of [UserRepository] that delegates to
/// [DummyProfileRepository] for its data.  State persists for the lifetime of
/// the object so follow/unfollow actions are reflected within a session.
class DummyUserRepository implements UserRepository {
  final DummyProfileRepository _inner = DummyProfileRepository();

  @override
  Future<ProfileModel?> getUserById(String id) async {
    return _inner.getProfileById(id);
  }

  @override
  Future<ProfileModel?> getCurrentUser() async {
    // Default to the first seeded profile as the "logged-in" user.
    return _inner.getProfileById('user_1');
  }

  @override
  Future<List<ProfileModel>> getAllUsers({int limit = 50}) async {
    final all = await _inner.getAllProfiles();
    return all.take(limit).toList();
  }

  @override
  Future<List<ProfileModel>> getUsersByRole(String role, {int limit = 50}) async {
    final all = await _inner.getAllProfiles();
    return all.where((p) => p.role == role).take(limit).toList();
  }

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) async {
    final profile = await _inner.getProfileById(userId);
    if (profile != null) {
      await _inner.updateProfile(profile.copyWith(isFollowing: isFollowing));
    }
  }

  @override
  Future<void> updateUser(ProfileModel user) async {
    await _inner.updateProfile(user);
  }

  @override
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  }) async {
    final all = await _inner.getAllProfiles();
    return all.where((user) {
      final matchesQuery = query.isEmpty ||
          user.name.toLowerCase().contains(query.toLowerCase()) ||
          user.username.toLowerCase().contains(query.toLowerCase()) ||
          user.primaryPosition.toLowerCase().contains(query.toLowerCase()) ||
          user.bio.toLowerCase().contains(query.toLowerCase());
      final matchesSport = sport == 'All' || user.sport == sport;
      final matchesRole = role == 'All' || user.role == role;
      final matchesState = state == 'All' || user.state == state;
      final matchesCity = city.isEmpty || user.city.toLowerCase().contains(city.toLowerCase());
      final matchesVerified = !onlyVerified || user.verified;
      return matchesQuery && matchesSport && matchesRole && matchesState && matchesCity && matchesVerified;
    }).toList();
  }
  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    await updateFollowState(targetUserId, true);
  }

  @override
  Future<void> incrementProfileViews(String uid) async {
    // Dummy implementation
  }

  @override
  Future<void> incrementPortfolioShares(String uid) async {
    // Dummy implementation
  }
}
