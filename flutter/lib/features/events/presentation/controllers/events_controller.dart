import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/events_repository.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

/// Stream provider for all events directly from Firestore
final eventsStreamProvider = StreamProvider<List<EventModel>>((ref) {
  final repository = ref.watch(eventsRepositoryProvider);
  return repository.streamEvents();
});

/// Watch joined status of a specific user for a specific event
final eventJoinedStatusProvider = StreamProvider.family<bool, String>((ref, eventId) {
  final repository = ref.watch(eventsRepositoryProvider);
  final userId = ref.watch(loggedInUserIdProvider);
  return repository.watchJoinedStatus(eventId, userId);
});

/// Watch bookmark status of a specific event for the current logged-in user
final eventBookmarkedStatusProvider = StreamProvider.family<bool, String>((ref, eventId) {
  final repository = ref.watch(eventsRepositoryProvider);
  final userId = ref.watch(loggedInUserIdProvider);
  return repository.watchBookmarkedStatus(eventId, userId);
});

/// Watch participant avatars for displaying a visual attendee list
final eventParticipantsAvatarsProvider = StreamProvider.family<List<String>, String>((ref, eventId) {
  final repository = ref.watch(eventsRepositoryProvider);
  return repository.streamParticipantsAvatars(eventId);
});

/// Filter states
final activeSportFilterProvider = StateProvider<String>((ref) => 'All');
final activeLevelFilterProvider = StateProvider<String>((ref) => 'All');
final eventSortProvider = StateProvider<String>((ref) => 'Upcoming');
final eventSearchQueryProvider = StateProvider<String>((ref) => '');

/// Computed provider for filtered and sorted events
final filteredEventsProvider = Provider<AsyncValue<List<EventModel>>>((ref) {
  final eventsAsync = ref.watch(eventsStreamProvider);
  final sportFilter = ref.watch(activeSportFilterProvider);
  final levelFilter = ref.watch(activeLevelFilterProvider);
  final sortOption = ref.watch(eventSortProvider);
  final searchQuery = ref.watch(eventSearchQueryProvider).trim().toLowerCase();
  final userProfile = ref.watch(activeProfileProvider).valueOrNull;

  return eventsAsync.whenData((events) {
    List<EventModel> filtered = List.from(events);

    // 1. Search Query filter (Title, Sport, Organizer, Venue, City, State)
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((e) {
        return e.title.toLowerCase().contains(searchQuery) ||
            e.sport.toLowerCase().contains(searchQuery) ||
            e.organizerName.toLowerCase().contains(searchQuery) ||
            e.venue.toLowerCase().contains(searchQuery) ||
            e.city.toLowerCase().contains(searchQuery) ||
            e.state.toLowerCase().contains(searchQuery);
      }).toList();
    }

    // 2. Sport Filter
    if (sportFilter != 'All') {
      filtered = filtered.where((e) => e.sport.toLowerCase() == sportFilter.toLowerCase()).toList();
    }

    // 3. Competition Level Filter
    if (levelFilter != 'All') {
      filtered = filtered.where((e) => e.competitionLevel.toLowerCase() == levelFilter.toLowerCase()).toList();
    }

    // 4. Sort Options
    switch (sortOption) {
      case 'Upcoming':
        // Show future events first, sorted by nearest date
        final now = DateTime.now();
        final upcoming = filtered.where((e) => e.startDate.isAfter(now)).toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        final past = filtered.where((e) => e.startDate.isBefore(now) || e.startDate.isAtSameMomentAs(now)).toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));
        filtered = [...upcoming, ...past];
        break;

      case 'Latest':
        // Sorted by createdAt descending
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;

      case 'Nearest Date':
        // Absolute date proximity (closest first)
        filtered.sort((a, b) => a.startDate.compareTo(b.startDate));
        break;

      case 'Free Events':
        // Free entry fee first
        filtered.sort((a, b) {
          if (a.isFree && !b.isFree) return -1;
          if (!a.isFree && b.isFree) return 1;
          return a.startDate.compareTo(b.startDate);
        });
        break;

      case 'Paid Events':
        // Paid entry fee first
        filtered.sort((a, b) {
          if (!a.isFree && b.isFree) return -1;
          if (a.isFree && !b.isFree) return 1;
          return a.startDate.compareTo(b.startDate);
        });
        break;

      case 'My Sport':
        // User's profile sport first
        if (userProfile != null && userProfile.sport.isNotEmpty) {
          final mySport = userProfile.sport.toLowerCase();
          filtered.sort((a, b) {
            final aMatch = a.sport.toLowerCase() == mySport;
            final bMatch = b.sport.toLowerCase() == mySport;
            if (aMatch && !bMatch) return -1;
            if (!aMatch && bMatch) return 1;
            return a.startDate.compareTo(b.startDate);
          });
        }
        break;

      case 'Verified Organizers':
        // Verified organizers first
        filtered.sort((a, b) {
          if (a.verifiedOrganizer && !b.verifiedOrganizer) return -1;
          if (!a.verifiedOrganizer && b.verifiedOrganizer) return 1;
          return a.startDate.compareTo(b.startDate);
        });
        break;
    }

    return filtered;
  });
});
