import '../../../profile/domain/models/profile_model.dart';
import '../../domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  @override
  Future<List<ProfileModel>> searchAthletes({
    required String query,
    required String sport,
    required String state,
    required bool onlyVerified,
  }) async {
    return const [];
  }
}
