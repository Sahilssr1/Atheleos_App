import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String eventId;
  final String organizerUid;
  final String organizerName;
  final String organizerAvatar;
  final bool verifiedOrganizer;
  final String title;
  final String description;
  final String sport;
  final String eventType;
  final String bannerUrl;
  final String bannerPublicId;
  final String bannerThumbnailUrl;
  final String competitionLevel;
  final String registrationType; // 'internal' | 'external'
  final String? externalRegistrationUrl;
  final String eventStatus; // 'Upcoming' | 'Registration Open' | 'Registration Closed' | 'Live' | 'Completed' | 'Cancelled'
  final String venue;
  final String city;
  final String state;
  final String country;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime registrationDeadline;
  final String startTime;
  final String endTime;
  final int maxParticipants;
  final int currentParticipants;
  final double entryFee; // 0.0 for free
  final String contactPerson;
  final String contactNumber;
  final String contactEmail;
  final String? officialWebsite;
  final String ageGroup;
  final String gender;
  final String skillLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.eventId,
    required this.organizerUid,
    required this.organizerName,
    required this.organizerAvatar,
    required this.verifiedOrganizer,
    required this.title,
    required this.description,
    required this.sport,
    required this.eventType,
    required this.bannerUrl,
    required this.bannerPublicId,
    required this.bannerThumbnailUrl,
    required this.competitionLevel,
    required this.registrationType,
    this.externalRegistrationUrl,
    required this.eventStatus,
    required this.venue,
    required this.city,
    required this.state,
    required this.country,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    required this.registrationDeadline,
    required this.startTime,
    required this.endTime,
    required this.maxParticipants,
    this.currentParticipants = 0,
    required this.entryFee,
    required this.contactPerson,
    required this.contactNumber,
    required this.contactEmail,
    this.officialWebsite,
    required this.ageGroup,
    required this.gender,
    required this.skillLevel,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFree => entryFee <= 0.0;
  bool get isFull => currentParticipants >= maxParticipants;
  bool get isExternal => registrationType == 'external';

  EventModel copyWith({
    String? eventId,
    String? organizerUid,
    String? organizerName,
    String? organizerAvatar,
    bool? verifiedOrganizer,
    String? title,
    String? description,
    String? sport,
    String? eventType,
    String? bannerUrl,
    String? bannerPublicId,
    String? bannerThumbnailUrl,
    String? competitionLevel,
    String? registrationType,
    String? externalRegistrationUrl,
    String? eventStatus,
    String? venue,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? registrationDeadline,
    String? startTime,
    String? endTime,
    int? maxParticipants,
    int? currentParticipants,
    double? entryFee,
    String? contactPerson,
    String? contactNumber,
    String? contactEmail,
    String? officialWebsite,
    String? ageGroup,
    String? gender,
    String? skillLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      eventId: eventId ?? this.eventId,
      organizerUid: organizerUid ?? this.organizerUid,
      organizerName: organizerName ?? this.organizerName,
      organizerAvatar: organizerAvatar ?? this.organizerAvatar,
      verifiedOrganizer: verifiedOrganizer ?? this.verifiedOrganizer,
      title: title ?? this.title,
      description: description ?? this.description,
      sport: sport ?? this.sport,
      eventType: eventType ?? this.eventType,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bannerPublicId: bannerPublicId ?? this.bannerPublicId,
      bannerThumbnailUrl: bannerThumbnailUrl ?? this.bannerThumbnailUrl,
      competitionLevel: competitionLevel ?? this.competitionLevel,
      registrationType: registrationType ?? this.registrationType,
      externalRegistrationUrl: externalRegistrationUrl ?? this.externalRegistrationUrl,
      eventStatus: eventStatus ?? this.eventStatus,
      venue: venue ?? this.venue,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      entryFee: entryFee ?? this.entryFee,
      contactPerson: contactPerson ?? this.contactPerson,
      contactNumber: contactNumber ?? this.contactNumber,
      contactEmail: contactEmail ?? this.contactEmail,
      officialWebsite: officialWebsite ?? this.officialWebsite,
      ageGroup: ageGroup ?? this.ageGroup,
      gender: gender ?? this.gender,
      skillLevel: skillLevel ?? this.skillLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'organizerUid': organizerUid,
      'createdBy': organizerUid,
      'organizerName': organizerName,
      'organizerAvatar': organizerAvatar,
      'verifiedOrganizer': verifiedOrganizer,
      'title': title,
      'description': description,
      'sport': sport,
      'eventType': eventType,
      'bannerUrl': bannerUrl,
      'bannerPublicId': bannerPublicId,
      'bannerThumbnailUrl': bannerThumbnailUrl,
      'competitionLevel': competitionLevel,
      'registrationType': registrationType,
      'externalRegistrationUrl': externalRegistrationUrl,
      'eventStatus': eventStatus,
      'venue': venue,
      'city': city,
      'state': state,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'eventDate': startDate.toIso8601String(),
      'registrationDeadline': Timestamp.fromDate(registrationDeadline),
      'startTime': startTime,
      'endTime': endTime,
      'maxParticipants': maxParticipants,
      'currentParticipants': currentParticipants,
      'entryFee': entryFee,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'contactEmail': contactEmail,
      'officialWebsite': officialWebsite,
      'ageGroup': ageGroup,
      'gender': gender,
      'skillLevel': skillLevel,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return EventModel(
      eventId: id,
      organizerUid: map['organizerUid'] as String? ?? map['createdBy'] as String? ?? '',
      organizerName: map['organizerName'] as String? ?? '',
      organizerAvatar: map['organizerAvatar'] as String? ?? map['avatarUrl'] as String? ?? '',
      verifiedOrganizer: map['verifiedOrganizer'] as bool? ?? false,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      sport: map['sport'] as String? ?? '',
      eventType: map['eventType'] as String? ?? '',
      bannerUrl: map['bannerUrl'] as String? ?? '',
      bannerPublicId: map['bannerPublicId'] as String? ?? '',
      bannerThumbnailUrl: map['bannerThumbnailUrl'] as String? ?? '',
      competitionLevel: map['competitionLevel'] as String? ?? 'Open',
      registrationType: map['registrationType'] as String? ?? 'internal',
      externalRegistrationUrl: map['externalRegistrationUrl'] as String?,
      eventStatus: map['eventStatus'] as String? ?? 'Upcoming',
      venue: map['venue'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      country: map['country'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      startDate: parseDate(map['startDate'] ?? map['eventDate']),
      endDate: parseDate(map['endDate'] ?? map['startDate'] ?? map['eventDate']),
      registrationDeadline: parseDate(map['registrationDeadline'] ?? map['startDate']),
      startTime: map['startTime'] as String? ?? '',
      endTime: map['endTime'] as String? ?? '',
      maxParticipants: map['maxParticipants'] as int? ?? 100,
      currentParticipants: map['currentParticipants'] as int? ?? 0,
      entryFee: (map['entryFee'] as num?)?.toDouble() ?? 0.0,
      contactPerson: map['contactPerson'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      contactEmail: map['contactEmail'] as String? ?? '',
      officialWebsite: map['officialWebsite'] as String?,
      ageGroup: map['ageGroup'] as String? ?? 'All Ages',
      gender: map['gender'] as String? ?? 'All',
      skillLevel: map['skillLevel'] as String? ?? 'Open',
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
