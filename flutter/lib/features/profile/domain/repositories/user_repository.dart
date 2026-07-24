import '../../domain/models/profile_model.dart';

abstract class UserRepository {
  Future<ProfileModel?> getUserById(String id);
  Future<ProfileModel?> getCurrentUser();
  Future<List<ProfileModel>> getAllUsers();
  Future<List<ProfileModel>> getUsersByRole(String role);
  Future<void> updateFollowState(String userId, bool isFollowing);
  Future<void> updateUser(ProfileModel user);
  Future<void> toggleFollow(String currentUserId, String targetUserId);
  Future<void> incrementProfileViews(String uid);
  Future<void> incrementPortfolioShares(String uid);
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  });
}
