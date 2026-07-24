import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/sports_service.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../domain/models/event_model.dart';
import '../controllers/events_controller.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  final List<String> _competitionLevels = const [
    'All',
    'District',
    'State',
    'National',
    'International',
    'School',
    'College',
    'University',
    'Professional',
    'Open'
  ];

  final List<String> _sortOptions = const [
    'Upcoming',
    'Latest',
    'Nearest Date',
    'Free Events',
    'Paid Events',
    'My Sport',
    'Verified Organizers'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredEventsAsync = ref.watch(filteredEventsProvider);
    final activeSport = ref.watch(activeSportFilterProvider);
    final activeLevel = ref.watch(activeLevelFilterProvider);
    final activeSort = ref.watch(eventSortProvider);
    final searchController = TextEditingController(text: ref.read(eventSearchQueryProvider));

    final userProfile = ref.watch(activeProfileProvider).valueOrNull;
    final canHost = userProfile != null && (
      userProfile.role == 'Coach' || 
      userProfile.role == 'Federation' || 
      userProfile.role == 'Brand'
    );

    // Keep search field text synced
    searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: searchController.text.length),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('COMBINE & EVENTS', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // 1. Search Bar Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: searchController,
              onChanged: (val) {
                ref.read(eventSearchQueryProvider.notifier).state = val;
              },
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by event name, city, state, organizer...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                        onPressed: () {
                          ref.read(eventSearchQueryProvider.notifier).state = '';
                          searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          // 2. Horizontal Sport Filters
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: SportsService.supportedSports.length + 1,
              itemBuilder: (context, index) {
                final sport = index == 0 ? 'All' : SportsService.supportedSports[index - 1];
                final isSelected = activeSport == sport;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(sport),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref.read(activeSportFilterProvider.notifier).state = sport;
                    },
                    selectedColor: AppTheme.primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // 3. Horizontal Level Filters
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _competitionLevels.length,
              itemBuilder: (context, index) {
                final level = _competitionLevels[index];
                final isSelected = activeLevel == level;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(level),
                    selected: isSelected,
                    onSelected: (selected) {
                      ref.read(activeLevelFilterProvider.notifier).state = level;
                    },
                    selectedColor: Colors.white24,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.primaryColor : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // 4. Sorting selection bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SORT BY:',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: activeSort,
                    dropdownColor: const Color(0xFF0F172A),
                    style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12),
                    items: _sortOptions.map((opt) {
                      return DropdownMenuItem(value: opt, child: Text(opt.toUpperCase()));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(eventSortProvider.notifier).state = v;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // 5. Events List Feed
          Expanded(
            child: filteredEventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
              error: (err, _) => Center(child: Text('Error loading events: $err', style: const TextStyle(color: Colors.red))),
              data: (events) {
                if (events.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No matches found for your event filters.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _buildEventCard(context, event);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canHost
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              onPressed: () => context.push('/events/create'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                'HOST EVENT',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 12),
              ),
            )
          : null,
    );
  }

  Widget _buildEventCard(BuildContext context, EventModel event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.04)),
      ),
      child: InkWell(
        onTap: () {
          context.push('/events/${event.eventId}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    event.bannerThumbnailUrl.isNotEmpty ? event.bannerThumbnailUrl : event.bannerUrl,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.competitionLevel.toUpperCase(),
                        style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.eventStatus == 'Registration Open'
                            ? Colors.green
                            : event.eventStatus == 'Upcoming'
                                ? Colors.blue
                                : Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        event.eventStatus.toUpperCase(),
                        style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${event.eventType} • ${event.sport}'.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '${event.currentParticipants} / ${event.maxParticipants} Joined',
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const SizedBox(height: 8),

                  // Location and Date Details
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppTheme.primaryColor, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${event.venue}, ${event.city}, ${event.state}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('START DATE', style: TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            '${event.startDate.month}/${event.startDate.day}/${event.startDate.year}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('ENTRY FEE', style: TextStyle(fontSize: 8, color: Colors.white38, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            event.isFree ? 'FREE' : '\$${event.entryFee.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
