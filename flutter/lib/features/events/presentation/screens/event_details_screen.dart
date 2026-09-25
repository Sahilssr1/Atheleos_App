import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../../../core/theme/app_theme.dart';
import '../../../notifications/data/notification_service.dart';
import '../../../notifications/domain/models/notification_model.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../chat/presentation/widgets/share_content_bottom_sheet.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/events_repository.dart';
import '../controllers/events_controller.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/utils/user_facing_error.dart';

class EventDetailsScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  Future<void> _launchExternalUrl(BuildContext context, String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch external registration page: $urlString')),
        );
      }
    }
  }

  void _showShareOptions(BuildContext context, EventModel event, List<dynamic> profiles) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF262626)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARE EVENT',
                  style: GoogleFonts.spaceGrotesk(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.link, color: Colors.white),
                  ),
                  title: const Text('Copy Event Link', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Save location path to clipboard', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'https://atheleos.com/events/${event.eventId}'));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard!')),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.send_rounded, color: Colors.white),
                  ),
                  title: const Text('Share inside ATHELEOS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Send directly to followers or coaches', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ShareContentBottomSheet(
                        eventId: event.eventId,
                        shareType: 'event',
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.share_outlined, color: Colors.white),
                  ),
                  title: const Text('Share Outside App', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Post to other sports networks', style: TextStyle(color: Colors.white38, fontSize: 10)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'Check out this ${event.sport} ${event.eventType} "${event.title}" at ${event.venue} on ATHELEOS!'));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event text details copied for external sharing!')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsStreamProvider);
    final currentUserId = ref.watch(loggedInUserIdProvider);
    final userProfile = ref.watch(activeProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.black,
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (events) {
          final event = events.firstWhere(
            (e) => e.eventId == eventId,
            orElse: () => throw Exception('Event not found'),
          );

          final isJoined = ref.watch(eventJoinedStatusProvider(eventId)).valueOrNull ?? false;
          final isBookmarked = ref.watch(eventBookmarkedStatusProvider(eventId)).valueOrNull ?? false;
          final attendeeAvatars = ref.watch(eventParticipantsAvatarsProvider(eventId)).valueOrNull ?? [];
          final allProfiles = ref.watch(profileListProvider).valueOrNull ?? [];

          return CustomScrollView(
            slivers: [
              // Banner Hero image header
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (event.bannerUrl.trim().isNotEmpty)
                        Image.network(
                          event.bannerUrl.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: const Color(0xFF141414)),
                        )
                      else
                        Container(color: const Color(0xFF141414)),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black87, Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border_outlined,
                      color: isBookmarked ? AppTheme.primaryColor : Colors.white,
                    ),
                    onPressed: () {
                      ref.read(eventsRepositoryProvider).toggleBookmark(
                            event.eventId,
                            currentUserId,
                            !isBookmarked,
                          );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: Colors.white),
                    onPressed: () => _showShareOptions(context, event, allProfiles),
                  ),
                ],
              ),

              // Scrollable Event Properties Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status & Level row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${event.eventType} • ${event.sport}'.toUpperCase(),
                              style: const TextStyle(color: AppTheme.primaryColor, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              event.competitionLevel.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: event.eventStatus == 'Registration Open'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : event.eventStatus == 'Upcoming'
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              event.eventStatus.toUpperCase(),
                              style: TextStyle(
                                color: event.eventStatus == 'Registration Open'
                                    ? Colors.greenAccent
                                    : event.eventStatus == 'Upcoming'
                                        ? Colors.blueAccent
                                        : Colors.redAccent,
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        event.title,
                        style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),

                      // Host / Organizer Block
                      GestureDetector(
                        onTap: () => context.push('/profile/${event.organizerUid}'),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141414),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF262626)),
                          ),
                          child: Row(
                            children: [
                              AppAvatar(
                                imageUrl: event.organizerAvatar,
                                radius: 18,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('HOSTED BY', style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          event.organizerName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                                        ),
                                        if (event.verifiedOrganizer) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified, size: 12, color: AppTheme.primaryColor),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Event Stats Grid
                      Row(
                        children: [
                          Expanded(child: _buildStatItem('FEE', event.isFree ? 'Free' : '\$${event.entryFee.toStringAsFixed(2)}', Icons.monetization_on_outlined)),
                          Expanded(child: _buildStatItem('DATE', '${event.startDate.month}/${event.startDate.day}/${event.startDate.year}', Icons.calendar_today_outlined)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildStatItem('TIME', '${event.startTime} - ${event.endTime}', Icons.access_time)),
                          Expanded(child: _buildStatItem('VENUE', event.venue, Icons.location_on_outlined)),
                        ],
                      ),
                      if (event.latitude != null && event.longitude != null) ...[
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Coordinates: Lat ${event.latitude}, Lng ${event.longitude}',
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Join / Register Action Button
                      if (event.isExternal) ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _launchExternalUrl(context, event.externalRegistrationUrl ?? ''),
                          child: Text('REGISTER ON OFFICIAL SITE', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ] else ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isJoined ? Colors.white12 : AppTheme.primaryColor,
                            foregroundColor: isJoined ? Colors.white70 : Colors.black,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: event.isFull && !isJoined
                              ? null
                              : () async {
                                  try {
                                    if (isJoined) {
                                      await ref.read(eventsRepositoryProvider).leaveEvent(event.eventId, currentUserId);
                                    } else {
                                      final details = {
                                        'uid': currentUserId,
                                        'name': userProfile?.name ?? 'Anonymous Athlete',
                                        'avatarUrl': userProfile?.avatarUrl ?? '',
                                        'role': userProfile?.role ?? 'Athlete',
                                      };
                                      await ref.read(eventsRepositoryProvider).joinEvent(event.eventId, currentUserId, details);
                                      // Let the organiser know a new athlete registered.
                                      if (event.organizerUid.isNotEmpty &&
                                          event.organizerUid != currentUserId) {
                                        unawaited(NotificationService.instance.create(
                                          receiverId: event.organizerUid,
                                          type: NotificationType.eventAccepted,
                                          actor: NotificationActor(
                                            id: currentUserId,
                                            name: userProfile?.name ?? 'An athlete',
                                            avatar: userProfile?.avatarUrl ?? '',
                                          ),
                                          body:
                                              'registered for your event "${event.title}"',
                                          relatedObjectId: event.eventId,
                                          thumbnailUrl: event.bannerUrl,
                                          dedupeKey:
                                              'event_join_${event.eventId}_$currentUserId',
                                        ));
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(UserFacingError.message(e, fallback: 'Unable to complete action. Please try again.')),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: Text(
                            isJoined
                                ? 'LEAVE EVENT'
                                : event.isFull
                                    ? 'EVENT FULL'
                                    : 'REGISTER / JOIN NOW',
                            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (context) => ShareContentBottomSheet(
                              eventId: event.eventId,
                              shareType: 'event',
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_outlined, size: 16, color: AppTheme.primaryColor),
                        label: Text(
                          'SHARE WITH FOLLOWERS',
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Deadline Warning
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  children: [
                                    const TextSpan(text: 'Registration Deadline: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(
                                      text: '${event.registrationDeadline.month}/${event.registrationDeadline.day}/${event.registrationDeadline.year}',
                                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Participant list section
                      if (attendeeAvatars.isNotEmpty) ...[
                        Text(
                          'PARTICIPATING ATHLETES (${event.currentParticipants} / ${event.maxParticipants})',
                          style: GoogleFonts.spaceGrotesk(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              height: 32,
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: Stack(
                                children: List.generate(
                                  attendeeAvatars.length > 6 ? 6 : attendeeAvatars.length,
                                  (index) {
                                    return Positioned(
                                      left: index * 20.0,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.black,
                                        child: AppAvatar(
                                          imageUrl: attendeeAvatars[index],
                                          radius: 13,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (event.currentParticipants > 6)
                              Text(
                                '+${event.currentParticipants - 6} more',
                                style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Eligibility criteria
                      Text(
                        'ELIGIBILITY CRITERIA',
                        style: GoogleFonts.spaceGrotesk(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      _buildCriteriaTile('Age Eligibility', event.ageGroup, Icons.assignment_ind_outlined),
                      _buildCriteriaTile('Gender Category', event.gender, Icons.people_outline),
                      _buildCriteriaTile('Skill Level Profile', event.skillLevel, Icons.trending_up),
                      const SizedBox(height: 24),

                      // Description
                      Text(
                        'EVENT DESCRIPTION & RULES',
                        style: GoogleFonts.spaceGrotesk(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // Contact Details
                      Text(
                        'ORGANIZER CONTACT DETAILS',
                        style: GoogleFonts.spaceGrotesk(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      _buildContactTile('Contact Name', event.contactPerson, Icons.person_outline),
                      _buildContactTile('Contact Number', event.contactNumber, Icons.phone_android_outlined),
                      _buildContactTile('Contact Email', event.contactEmail, Icons.mail_outline_outlined),
                      if (event.officialWebsite != null)
                        _buildContactTile('Official Website', event.officialWebsite!, Icons.language_outlined),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaTile(String title, String val, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 10),
          Text('$title: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildContactTile(String label, String val, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9)),
              const SizedBox(height: 2),
              Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
