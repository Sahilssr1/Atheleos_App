import '../models/profile_model.dart';

abstract class ProfileRepository {
  Future<ProfileModel?> getProfileById(String id);
  Future<List<ProfileModel>> getAllProfiles();
  Future<void> updateProfile(ProfileModel profile);
}
