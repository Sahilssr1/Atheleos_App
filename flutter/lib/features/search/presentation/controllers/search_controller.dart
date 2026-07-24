import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/domain/models/profile_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

// Search filter state model
class SearchFilters {
  final String query;
  final String sport;
  final String role; // 'All', 'Athlete', 'Coach', 'Brand', 'Federation'
  final String state;
  final String city;
  final bool onlyVerified;

  const SearchFilters({
    this.query = '',
    this.sport = 'All',
    this.role = 'All',
    this.state = 'All',
    this.city = '',
    this.onlyVerified = false,
  });

  SearchFilters copyWith({
    String? query,
    String? sport,
    String? role,
    String? state,
    String? city,
    bool? onlyVerified,
  }) {
    return SearchFilters(
      query: query ?? this.query,
      sport: sport ?? this.sport,
      role: role ?? this.role,
      state: state ?? this.state,
      city: city ?? this.city,
      onlyVerified: onlyVerified ?? this.onlyVerified,
    );
  }
}

// Controller to update search criteria
class SearchFiltersNotifier extends StateNotifier<SearchFilters> {
  SearchFiltersNotifier() : super(const SearchFilters());

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setSport(String sport) {
    state = state.copyWith(sport: sport);
  }

  void setRole(String role) {
    state = state.copyWith(role: role);
  }

  void setStateCode(String stateCode) {
    state = state.copyWith(state: stateCode);
  }

  void setCity(String city) {
    state = state.copyWith(city: city);
  }

  void setOnlyVerified(bool onlyVerified) {
    state = state.copyWith(onlyVerified: onlyVerified);
  }
}

// Provide search filter parameters
final searchFiltersProvider = StateNotifierProvider<SearchFiltersNotifier, SearchFilters>((ref) {
  return SearchFiltersNotifier();
});

// Async search results matching the current filters
final searchResultsProvider = FutureProvider<List<ProfileModel>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final filters = ref.watch(searchFiltersProvider);

  return repository.searchUsers(
    query: filters.query,
    sport: filters.sport,
    role: filters.role,
    state: filters.state,
    city: filters.city,
    onlyVerified: filters.onlyVerified,
  );
});
