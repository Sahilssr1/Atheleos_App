import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/profile_model.dart';
import '../../domain/models/stat_entry.dart';
import '../../domain/repositories/user_repository.dart';

class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Safely parse a field that may be stored as num or String
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String)
      return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
    return null;
  }

  // Safely parse an int that may be stored as num or String
  static int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  // Convert a Firestore document map to a ProfileModel
  // Handles both UserModel field names (fullName, position) and ProfileModel field names (displayName, primaryPosition)
  ProfileModel _mapToProfile(String id, Map<String, dynamic> data) {
    return ProfileModel(
      id: id,
      name: data['displayName'] ?? data['name'] ?? data['fullName'] ?? '',
      username: data['username'] ?? '',
      avatarUrl: pickAvatarUrl(data),
      coverUrl: data['coverPhoto'] ?? data['coverUrl'] ?? '',
      role: data['role'] ?? 'Athlete',
      verified: data['verified'] ?? data['googleVerified'] ?? false,
      sport: data['sport'] ?? '',
      primaryPosition: data['primaryPosition'] ?? data['position'] ?? '',
      clubOrAcademy: data['clubOrAcademy'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      country: data['country'] ?? '',
      bio: data['bio'] ?? '',
      email:
          data['email'] ?? data['googleEmail'] ?? data['alternateEmail'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      dateOfBirth: data['dateOfBirth'] ?? '',
      gender: data['gender'] ?? '',
      personalNotes: data['personalNotes'] ?? '',
      followersCount: _parseInt(data['followersCount']),
      followingCount: _parseInt(data['followingCount']),
      postsCount: _parseInt(data['postsCount']),
      clipsCount: _parseInt(data['clipsCount']),
      profileViews: _parseInt(data['profileViews']),
      portfolioViews: _parseInt(data['portfolioViews']),
      portfolioShares: _parseInt(data['portfolioShares']),
      searchAppearances: _parseInt(data['searchAppearances']),
      achievements: List<String>.from(data['achievements'] ?? []),
      certifications: List<String>.from(data['certifications'] ?? []),
      experienceYears: data['experienceYears'] != null
          ? _parseInt(data['experienceYears'])
          : null,
      website: data['website'] ?? '',
      socialLinks: Map<String, String>.from(data['socialLinks'] ?? {}),
      resumeFileName: data['resumeFileName'] as String?,
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

  /// Safely deserialize the statistics array from Firestore.
  static List<StatEntry> _parseStatistics(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(StatEntry.fromMap)
        .toList();
  }

  // Convert a ProfileModel to a Firestore document map matching user-editable security rules
  Map<String, dynamic> _profileToMap(ProfileModel profile) {
    return {
      'uid': profile.id,
      'username': profile.username,
      'displayName': profile.name,
      'fullName': profile.name,
      'name': profile.name,
      'role': profile.role,
      'sport': profile.sport,
      'primaryPosition': profile.primaryPosition,
      'position': profile.primaryPosition,
      'clubOrAcademy': profile.clubOrAcademy,
      'teamName': profile.clubOrAcademy,
      'city': profile.city,
      'state': profile.state,
      'country': profile.country,
      'bio': profile.bio,
      'email': profile.email,
      'phoneNumber': profile.phoneNumber,
      'dateOfBirth': profile.dateOfBirth,
      'dob': profile.dateOfBirth,
      'gender': profile.gender,
      'personalNotes': profile.personalNotes,
      'photoUrl': profile.avatarUrl,
      'avatarUrl': profile.avatarUrl,
      'coverPhoto': profile.coverUrl,
      'coverUrl': profile.coverUrl,
      'achievements': profile.achievements,
      'certifications': profile.certifications,
      'experienceYears': profile.experienceYears,
      'website': profile.website,
      'socialLinks': profile.socialLinks,
      'resumeFileName': profile.resumeFileName,
      'height': profile.height,
      'weight': profile.weight,
      'mediaGallery': profile.mediaGallery,
      'industry': profile.industry,
      'organizationName': profile.organizationName,
      'showFollowing': profile.showFollowing,
      'updatedAt': FieldValue.serverTimestamp(),
      'statistics': profile.statistics.map((s) => s.toMap()).toList(),
    };
  }

  @override
  Future<ProfileModel?> getUserById(String id) async {
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      if (doc.exists && doc.data() != null) {
        final profile = _mapToProfile(doc.id, doc.data()!);
        // If this is the logged-in user and avatar is missing, patch it from Firebase Auth
        if (profile.avatarUrl.isEmpty && id == _auth.currentUser?.uid) {
          final photoUrl = _auth.currentUser?.photoURL ?? '';
          if (photoUrl.isNotEmpty) {
            await _firestore
                .collection('users')
                .doc(id)
                .update({'photoUrl': photoUrl});
            return profile.copyWith(avatarUrl: photoUrl);
          }
        }
        return profile;
      } else {
        // First-time login: auto-create a minimal empty profile in Firestore for this user
        final currentUid = _auth.currentUser?.uid;
        if (id == currentUid) {
          final firebaseUser = _auth.currentUser!;
          final defaultProfile = ProfileModel(
            id: id,
            name: firebaseUser.displayName ?? '',
            username: '',
            avatarUrl: firebaseUser.photoURL ?? '',
            coverUrl: '',
            role: 'Athlete',
            verified: false,
            sport: '',
            primaryPosition: '',
            clubOrAcademy: '',
            city: '',
            state: '',
            bio: '',
            followersCount: 0,
            followingCount: 0,
            postsCount: 0,
            clipsCount: 0,
            profileViews: 0,
            portfolioShares: 0,
            searchAppearances: 0,
            achievements: [],
            certifications: [],
            experienceYears: null,
            website: '',
            socialLinks: {},
            height: null,
            weight: null,
            mediaGallery: [],
          );
          await updateUser(defaultProfile);
          return defaultProfile;
        }
      }
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error loading user by ID: $e');
    }
    return null;
  }

  @override
  Future<ProfileModel?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return null;
    }
    return getUserById(uid);
  }

  /// Automatically deletes legacy 'Brand / Federation' profiles from Firestore backend
  Future<int> deleteLegacyBrandFederationProfiles() async {
    try {
      final snap = await _firestore.collection('users').get();
      int deletedCount = 0;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        final data = doc.data();
        final rawRole = (data['role'] as String? ?? '').trim().toLowerCase();
        if (rawRole == 'brand / federation' ||
            rawRole == 'brand/federation' ||
            rawRole == 'brand & federation' ||
            rawRole == 'brand_federation') {
          batch.delete(doc.reference);
          deletedCount++;
        }
      }
      if (deletedCount > 0) {
        await batch.commit();
        debugPrint('FirestoreUserRepository: Purged $deletedCount legacy Brand / Federation profiles.');
      }
      return deletedCount;
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error purging legacy profiles: $e');
      return 0;
    }
  }

  @override
  Future<List<ProfileModel>> getAllUsers({int limit = 50}) async {
    try {
      final querySnapshot =
          await _firestore.collection('users').limit(limit).get();
      final firestoreUsers = querySnapshot.docs
          .map((doc) => _mapToProfile(doc.id, doc.data()))
          .where((p) {
            final r = p.role.trim().toLowerCase();
            return r != 'brand / federation' &&
                   r != 'brand/federation' &&
                   r != 'brand & federation' &&
                   r != 'brand_federation';
          })
          .toList();

      return firestoreUsers;
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error loading all users: $e');
      return [];
    }
  }

  @override
  Future<List<ProfileModel>> getUsersByRole(String role, {int limit = 50}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .limit(limit)
          .get();
      return querySnapshot.docs
          .map((doc) => _mapToProfile(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error loading users by role: $e');
      return [];
    }
  }

  @override
  Future<void> updateFollowState(String userId, bool isFollowing) async {
    final myId = _auth.currentUser?.uid;
    if (myId == null || myId.isEmpty || myId == userId) return;

    final targetRef = _firestore.collection('users').doc(userId);
    final myRef = _firestore.collection('users').doc(myId);
    final followerRef = targetRef.collection('followers').doc(myId);
    final followingRef = myRef.collection('following').doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final targetSnapshot = await transaction.get(targetRef);
        final mySnapshot = await transaction.get(myRef);

        if (targetSnapshot.exists && mySnapshot.exists) {
          final targetData = targetSnapshot.data() ?? {};
          final myData = mySnapshot.data() ?? {};

          final currentFollowers = targetData['followersCount'] ?? 0;
          final currentFollowing = myData['followingCount'] ?? 0;

          transaction.update(targetRef, {
            'followersCount': isFollowing
                ? currentFollowers + 1
                : (currentFollowers > 0 ? currentFollowers - 1 : 0),
          });

          transaction.update(myRef, {
            'followingCount': isFollowing
                ? currentFollowing + 1
                : (currentFollowing > 0 ? currentFollowing - 1 : 0),
          });
          if (isFollowing) {
            final relationship = {'createdAt': FieldValue.serverTimestamp()};
            transaction.set(followerRef, relationship);
            transaction.set(followingRef, relationship);
          } else {
            transaction.delete(followerRef);
            transaction.delete(followingRef);
          }
        }
      });
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error updating follow state: $e');
    }
  }

  @override
  Future<void> updateUser(ProfileModel user) async {
    try {
      final mapData = _profileToMap(user);
      await _firestore
          .collection('users')
          .doc(user.id)
          .set(mapData, SetOptions(merge: true));
      debugPrint('FirestoreUserRepository: Saved user profile: ${user.id}');
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error saving user profile: $e');
      rethrow;
    }
  }

  @override
  Future<List<ProfileModel>> searchUsers({
    required String query,
    required String sport,
    required String role,
    required String state,
    required String city,
    required bool onlyVerified,
  }) async {
    try {
      Query firestoreQuery = _firestore.collection('users');

      if (role != 'All') {
        firestoreQuery = firestoreQuery.where('role', isEqualTo: role);
      }
      if (sport != 'All') {
        firestoreQuery = firestoreQuery.where('sport', isEqualTo: sport);
      }
      if (state != 'All') {
        firestoreQuery = firestoreQuery.where('state', isEqualTo: state);
      }
      if (onlyVerified) {
        firestoreQuery = firestoreQuery.where('verified', isEqualTo: true);
      }

      firestoreQuery = firestoreQuery.limit(50);

      final snapshot = await firestoreQuery.get();
      final results = snapshot.docs
          .map((doc) =>
              _mapToProfile(doc.id, doc.data() as Map<String, dynamic>))
          .toList();

      return results.where((user) {
        final r = user.role.trim().toLowerCase();
        if (r == 'brand / federation' ||
            r == 'brand/federation' ||
            r == 'brand & federation' ||
            r == 'brand_federation') {
          return false;
        }
        final matchesQuery = query.isEmpty ||
            user.name.toLowerCase().contains(query.toLowerCase()) ||
            user.username.toLowerCase().contains(query.toLowerCase()) ||
            user.primaryPosition.toLowerCase().contains(query.toLowerCase()) ||
            user.bio.toLowerCase().contains(query.toLowerCase());
        final matchesCity = city.isEmpty ||
            user.city.toLowerCase().contains(city.toLowerCase());
        return matchesQuery && matchesCity;
      }).toList();
    } catch (e) {
      debugPrint('FirestoreUserRepository: Error searching users: $e');
      return [];
    }
  }

  @override
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    // Implemented in updateFollowState already, but this satisfies the interface
    await updateFollowState(targetUserId, true);
  }

  @override
  Future<void> incrementProfileViews(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'profileViews': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing profile views: $e');
    }
  }

  @override
  Future<void> incrementPortfolioShares(String uid) async {
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).update({
        'portfolioShares': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing portfolio shares: $e');
    }
  }
}
