import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String googleEmail;
  final String alternateEmail;
  final String username;
  final String fullName;
  final String phoneNumber;
  final String country;
  final String state;
  final String city;
  final String role; 
  final String sport;
  final String position;
  final String height;
  final String weight;
  final String recruitmentStatus;
  final int profileCompletion;
  final bool phoneVerified;
  final bool googleVerified;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.googleEmail,
    required this.alternateEmail,
    required this.username,
    required this.fullName,
    required this.phoneNumber,
    required this.country,
    required this.state,
    required this.city,
    required this.role,
    required this.sport,
    required this.position,
    required this.height,
    required this.weight,
    required this.recruitmentStatus,
    required this.profileCompletion,
    required this.phoneVerified,
    required this.googleVerified,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  UserModel copyWith({
    String? uid,
    String? googleEmail,
    String? alternateEmail,
    String? username,
    String? fullName,
    String? phoneNumber,
    String? country,
    String? state,
    String? city,
    String? role,
    String? sport,
    String? position,
    String? height,
    String? weight,
    String? recruitmentStatus,
    int? profileCompletion,
    bool? phoneVerified,
    bool? googleVerified,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      googleEmail: googleEmail ?? this.googleEmail,
      alternateEmail: alternateEmail ?? this.alternateEmail,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      country: country ?? this.country,
      state: state ?? this.state,
      city: city ?? this.city,
      role: role ?? this.role,
      sport: sport ?? this.sport,
      position: position ?? this.position,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      recruitmentStatus: recruitmentStatus ?? this.recruitmentStatus,
      profileCompletion: profileCompletion ?? this.profileCompletion,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      googleVerified: googleVerified ?? this.googleVerified,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'googleEmail': googleEmail,
      'alternateEmail': alternateEmail,
      'username': username,
      'fullName': fullName,
      // Also write canonical field names expected by _mapToProfile
      'displayName': fullName,
      'name': fullName,
      'phoneNumber': phoneNumber,
      'country': country,
      'state': state,
      'city': city,
      'role': role,
      'sport': sport,
      'position': position,
      'primaryPosition': position,
      'height': height,
      'weight': weight,
      'recruitmentStatus': recruitmentStatus,
      'profileCompletion': profileCompletion,
      'phoneVerified': phoneVerified,
      'googleVerified': googleVerified,
      'verified': phoneVerified && googleVerified,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // height/weight may be stored as String OR double depending on which save path wrote them
    String _str(dynamic v) {
      if (v == null) return '';
      if (v is String) return v;
      return v.toString();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      googleEmail: map['googleEmail'] ?? '',
      alternateEmail: map['alternateEmail'] ?? '',
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? map['displayName'] ?? map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      country: map['country'] ?? 'India',
      state: map['state'] ?? '',
      city: map['city'] ?? '',
      role: map['role'] ?? '',
      sport: map['sport'] ?? '',
      position: map['position'] ?? map['primaryPosition'] ?? '',
      height: _str(map['height']),
      weight: _str(map['weight']),
      recruitmentStatus: map['recruitmentStatus'] ?? '',
      profileCompletion: map['profileCompletion'] is int
          ? map['profileCompletion']
          : (map['profileCompletion'] as num?)?.toInt() ?? 0,
      phoneVerified: map['phoneVerified'] ?? false,
      googleVerified: map['googleVerified'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      deletedAt: map['deletedAt'] is Timestamp
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory UserModel.initial() {
    return UserModel(
      uid: '',
      googleEmail: '',
      alternateEmail: '',
      username: '',
      fullName: '',
      phoneNumber: '',
      country: 'India',
      state: '',
      city: '',
      role: '',
      sport: '',
      position: '',
      height: '',
      weight: '',
      recruitmentStatus: '',
      profileCompletion: 0,
      phoneVerified: false,
      googleVerified: false,
      isDeleted: false,
      deletedAt: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  int calculateCompletionPercentage() {
    int score = 0;
    int total = 12;

    if (googleEmail.isNotEmpty) score++;
    if (alternateEmail.isNotEmpty) score++;
    if (username.isNotEmpty) score++;
    if (fullName.isNotEmpty) score++;
    if (phoneNumber.isNotEmpty) score++;
    if (country.isNotEmpty) score++;
    if (state.isNotEmpty) score++;
    if (city.isNotEmpty) score++;
    if (role.isNotEmpty) score++;
    if (sport.isNotEmpty) score++;
    if (position.isNotEmpty) score++;
    if (height.isNotEmpty) score++;

    return ((score / total) * 100).round();
  }
}
