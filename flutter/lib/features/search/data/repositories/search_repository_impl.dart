import '../../../../core/data/dummy/users_dummy.dart';
import '../../domain/repositories/search_repository.dart';

class SearchRepositoryImpl implements SearchRepository {
  @override
  Future<List<DummyUser>> searchAthletes({
    required String query,
    required String sport,
    required String state,
    required bool onlyVerified,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250)); // Simulate networking
    return dummyUsers.where((athlete) {
      final matchesSearch = query.isEmpty ||
          athlete.name.toLowerCase().contains(query.toLowerCase()) ||
          athlete.position.toLowerCase().contains(query.toLowerCase());
      final matchesSport = sport == 'All' || athlete.sport == sport;
      final matchesState = state == 'All' || athlete.state == state;
      final matchesVerified = !onlyVerified || athlete.verified == true;
      return matchesSearch && matchesSport && matchesState && matchesVerified;
    }).toList();
  }
}
