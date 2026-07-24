import '../../../../core/data/dummy/users_dummy.dart';

abstract class SearchRepository {
  Future<List<DummyUser>> searchAthletes({
    required String query,
    required String sport,
    required String state,
    required bool onlyVerified,
  });
}
