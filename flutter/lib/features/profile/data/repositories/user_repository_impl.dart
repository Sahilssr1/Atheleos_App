import '../../domain/models/profile_model.dart';
import '../../domain/repositories/user_repository.dart';
import 'dummy_user_repository.dart';

/// Concrete implementation of [UserRepository] that delegates to the in-memory
/// [DummyUserRepository].  Kept for backwards-compatibility; prefer using
/// [DummyUserRepository] or [FirestoreUserRepository] directly via the
/// providers defined in profile_controller.dart.
class UserRepositoryImpl implements UserRepository {
  final DummyUserRepository _delegate = DummyUserRepository();

  @override
  Future<ProfileModel?> getUserById(String id) => _delegate.getUserById(id);

  @override
  Future<ProfileModel?> getCurrentUser() => _delegate.getCurrentUser();

  @override
  Future<List<ProfileModel>> getAllUsers() => _delegate.getAllUsers();

  @override
  Future<List<ProfileModel>> getUsersByRole(String role) =>
      _delegate.getUsersByRole(role);

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) =>
      _delegate.updateFollowState(userId, isFollowing);

  @override
  Future<void> updateUser(ProfileModel user) => _delegate.updateUser(user);

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) =>
      _delegate.toggleFollow(currentUserId, targetUserId);

  @override
  Future<void> incrementProfileViews(String uid) =>
      _delegate.incrementProfileViews(uid);

  @override
  Future<void> incrementPortfolioShares(String uid) =>
      _delegate.incrementPortfolioShares(uid);

  @override
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  }) =>
      _delegate.searchUsers(
        query: query,
        sport: sport,
        role: role,
        state: state,
        city: city,
        onlyVerified: onlyVerified,
      );
}

