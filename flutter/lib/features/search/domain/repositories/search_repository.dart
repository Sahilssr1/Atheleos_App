import '../../../profile/domain/models/profile_model.dart';

abstract class SearchRepository {
  Future<List<ProfileModel>> searchAthletes({
    required String query,
    required String sport,
    required String state,
    required bool onlyVerified,
  });
}
