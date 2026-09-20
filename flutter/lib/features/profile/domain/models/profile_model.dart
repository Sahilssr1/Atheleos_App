import 'stat_entry.dart';

const _unsetProfileValue = Object();

class ProfileModel {
  final String id;
  final String name;
  final String username;
  final String avatarUrl;
  final String coverUrl;
  final String role; // 'Athlete', 'Coach', 'Brand', 'Federation'
  final bool verified;
  final String sport;
  final String primaryPosition;
  final String clubOrAcademy;
  final String city;
  final String state;
  final String country;
  final String bio;
  final String email;
  final String phoneNumber;
  final String dateOfBirth;
  final String gender;
  final String personalNotes;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final int clipsCount;
  final int profileViews;
  final int portfolioViews;
  final int portfolioShares;
  final int searchAppearances;
  final List<String> achievements;
  final List<String> certifications;
  final int? experienceYears;
  final String website;
  final Map<String, String> socialLinks;
  final String? resumeFileName;
  final double? height; // Private (only in Edit Profile)
  final double? weight; // Private (only in Edit Profile)
  final List<String> mediaGallery;
  final String? industry; // For Brand/Federation
  final String? organizationName; // For Brand/Federation
  final bool isFollowing; // Whether the logged-in user follows this profile
  final bool showFollowing; // Whether the user chooses to show who they follow on their profile
  /// Sport-agnostic statistics array. Stored as a Firestore array of
  /// {id, name, type, value} objects. Never hardcoded per sport.
  final List<StatEntry> statistics;

  // Verification fields
  final String
      verificationStatus; // 'none', 'pending', 'underReview', 'approved', 'rejected', 'moreInfoRequired'
  final String
      verificationBadge; // e.g. 'Verified Athlete', 'District Athlete', etc.
  final String verificationDate; // Date when verified
  final int
      verificationLevel; // Progression level: 0 (none), 1 (Verified Athlete), etc.
  final String verificationRejectedReason; // Reason if rejected
  final Map<String, dynamic>
      verificationRequestDetails; // Raw details of the verification request

  const ProfileModel({
    required this.id,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.coverUrl,
    required this.role,
    required this.verified,
    required this.sport,
    required this.primaryPosition,
    required this.clubOrAcademy,
    required this.city,
    required this.state,
    this.country = '',
    required this.bio,
    this.email = '',
    this.phoneNumber = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.personalNotes = '',
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.clipsCount,
    this.profileViews = 0,
    this.portfolioViews = 0,
    this.portfolioShares = 0,
    this.searchAppearances = 0,
    required this.achievements,
    required this.certifications,
    this.experienceYears,
    required this.website,
    required this.socialLinks,
    this.resumeFileName,
    this.height,
    this.weight,
    required this.mediaGallery,
    this.industry,
    this.organizationName,
    this.isFollowing = false,
    this.showFollowing = false,
    List<StatEntry>? statistics,
    this.verificationStatus = 'none',
    this.verificationBadge = '',
    this.verificationDate = '',
    this.verificationLevel = 0,
    this.verificationRejectedReason = '',
    this.verificationRequestDetails = const {},
  }) : statistics = statistics ?? const [];

  ProfileModel copyWith({
    String? name,
    String? username,
    String? avatarUrl,
    String? coverUrl,
    String? role,
    bool? verified,
    String? sport,
    String? primaryPosition,
    String? clubOrAcademy,
    String? city,
    String? state,
    String? country,
    String? bio,
    String? email,
    String? phoneNumber,
    String? dateOfBirth,
    String? gender,
    String? personalNotes,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    int? clipsCount,
    int? profileViews,
    int? portfolioViews,
    int? portfolioShares,
    int? searchAppearances,
    List<String>? achievements,
    List<String>? certifications,
    int? experienceYears,
    String? website,
    Map<String, String>? socialLinks,
    String? resumeFileName,
    Object? height = _unsetProfileValue,
    Object? weight = _unsetProfileValue,
    List<String>? mediaGallery,
    String? industry,
    String? organizationName,
    bool? isFollowing,
    bool? showFollowing,
    List<StatEntry>? statistics,
    String? verificationStatus,
    String? verificationBadge,
    String? verificationDate,
    int? verificationLevel,
    String? verificationRejectedReason,
    Map<String, dynamic>? verificationRequestDetails,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      role: role ?? this.role,
      verified: verified ?? this.verified,
      sport: sport ?? this.sport,
      primaryPosition: primaryPosition ?? this.primaryPosition,
      clubOrAcademy: clubOrAcademy ?? this.clubOrAcademy,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      personalNotes: personalNotes ?? this.personalNotes,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      clipsCount: clipsCount ?? this.clipsCount,
      profileViews: profileViews ?? this.profileViews,
      portfolioViews: portfolioViews ?? this.portfolioViews,
      portfolioShares: portfolioShares ?? this.portfolioShares,
      searchAppearances: searchAppearances ?? this.searchAppearances,
      achievements: achievements ?? this.achievements,
      certifications: certifications ?? this.certifications,
      experienceYears: experienceYears ?? this.experienceYears,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      resumeFileName: resumeFileName ?? this.resumeFileName,
      height: identical(height, _unsetProfileValue)
          ? this.height
          : height as double?,
      weight: identical(weight, _unsetProfileValue)
          ? this.weight
          : weight as double?,
      mediaGallery: mediaGallery ?? this.mediaGallery,
      industry: industry ?? this.industry,
      organizationName: organizationName ?? this.organizationName,
      isFollowing: isFollowing ?? this.isFollowing,
      showFollowing: showFollowing ?? this.showFollowing,
      statistics: statistics ?? this.statistics,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationBadge: verificationBadge ?? this.verificationBadge,
      verificationDate: verificationDate ?? this.verificationDate,
      verificationLevel: verificationLevel ?? this.verificationLevel,
      verificationRejectedReason:
          verificationRejectedReason ?? this.verificationRejectedReason,
      verificationRequestDetails:
          verificationRequestDetails ?? this.verificationRequestDetails,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': id,
      'name': name,
      'displayName': name,
      'fullName': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'photoUrl': avatarUrl,
      'coverUrl': coverUrl,
      'coverPhoto': coverUrl,
      'role': role,
      'verified': verified,
      'sport': sport,
      'primaryPosition': primaryPosition,
      'position': primaryPosition,
      'clubOrAcademy': clubOrAcademy,
      'teamName': clubOrAcademy,
      'city': city,
      'state': state,
      'country': country,
      'bio': bio,
      'email': email,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth,
      'dob': dateOfBirth,
      'gender': gender,
      'personalNotes': personalNotes,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'clipsCount': clipsCount,
      'profileViews': profileViews,
      'portfolioViews': portfolioViews,
      'portfolioShares': portfolioShares,
      'searchAppearances': searchAppearances,
      'achievements': achievements,
      'certifications': certifications,
      'experienceYears': experienceYears,
      'website': website,
      'socialLinks': socialLinks,
      'resumeFileName': resumeFileName,
      'height': height,
      'weight': weight,
      'mediaGallery': mediaGallery,
      'industry': industry,
      'organizationName': organizationName,
      'isFollowing': isFollowing,
      'showFollowing': showFollowing,
      'statistics': statistics.map((s) => s.toMap()).toList(),
      'verificationStatus': verificationStatus,
      'verificationBadge': verificationBadge,
      'verificationDate': verificationDate,
      'verificationLevel': verificationLevel,
      'verificationRejectedReason': verificationRejectedReason,
      'verificationRequestDetails': verificationRequestDetails,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> data) {
    return ProfileModel(
      id: data['id'] ?? data['uid'] ?? '',
      name: data['name'] ?? data['displayName'] ?? data['fullName'] ?? '',
      username: data['username'] ?? '',
      avatarUrl:
          data['avatarUrl'] ?? data['photoUrl'] ?? data['googlePhotoUrl'] ?? '',
      coverUrl: data['coverUrl'] ?? data['coverPhoto'] ?? '',
      role: data['role'] ?? 'Athlete',
      verified: data['verified'] ?? data['googleVerified'] ?? false,
      sport: data['sport'] ?? '',
      primaryPosition: data['primaryPosition'] ?? data['position'] ?? '',
      clubOrAcademy:
          data['clubOrAcademy'] ?? data['teamName'] ?? data['school_club'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      country: data['country'] ?? '',
      bio: data['bio'] ?? '',
      email:
          data['email'] ?? data['googleEmail'] ?? data['alternateEmail'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? data['dob'] ?? '',
      gender: data['gender'] ?? '',
      personalNotes: data['personalNotes'] ?? '',
      followersCount: _parseInt(data['followersCount']),
      followingCount: _parseInt(data['followingCount']),
      postsCount: data['postsCount']?.toInt() ?? 0,
      clipsCount: data['clipsCount']?.toInt() ?? 0,
      profileViews: data['profileViews']?.toInt() ?? 0,
      portfolioViews: data['portfolioViews']?.toInt() ?? 0,
      portfolioShares: data['portfolioShares']?.toInt() ?? 0,
      searchAppearances: data['searchAppearances']?.toInt() ?? 0,
      achievements: List<String>.from(data['achievements'] ?? []),
      certifications: List<String>.from(data['certifications'] ?? []),
      experienceYears: data['experienceYears'] != null
          ? _parseInt(data['experienceYears'])
          : null,
      website: data['website'] ?? '',
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      resumeFileName:
          (data['resumeFileName'] ?? data['resumeFilename']) as String?,
      height: _parseDouble(data['height']),
      weight: _parseDouble(data['weight']),
      mediaGallery: List<String>.from(data['mediaGallery'] ?? []),
      industry: data['industry'] as String?,
      organizationName: data['organizationName'] as String?,
      isFollowing: data['isFollowing'] ?? false,
      showFollowing: data['showFollowing'] ?? false,
      statistics: _parseStatistics(data['statistics']),
      verificationStatus: data['verificationStatus'] ?? 'none',
      verificationBadge: data['verificationBadge'] ?? '',
      verificationDate: data['verificationDate'] ?? '',
      verificationLevel: _parseInt(data['verificationLevel']),
      verificationRejectedReason: data['verificationRejectedReason'] ?? '',
      verificationRequestDetails:
          Map<String, dynamic>.from(data['verificationRequestDetails'] ?? {}),
    );
  }

  static int _parseInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static List<StatEntry> _parseStatistics(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((m) => StatEntry.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }
}
