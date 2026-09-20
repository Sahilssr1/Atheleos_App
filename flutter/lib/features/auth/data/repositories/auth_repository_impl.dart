import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────
  // PRIMARY: Login with Email or Username + Password
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> loginWithEmailOrUsername({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    String targetEmail = trimmed;

    if (!trimmed.contains('@')) {
      // It's a username - resolve to email
      final email = await getEmailForUsername(trimmed);
      if (email == null || email.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account found with username "@$trimmed".',
        );
      }
      targetEmail = email;
    }

    return signInWithAlternateEmail(email: targetEmail, password: password);
  }

  // ─────────────────────────────────────────────────
  // USERNAME & EMAIL LOOKUPS & VERIFICATIONS
  // ─────────────────────────────────────────────────
  @override
  Future<String?> getEmailForUsername(String username) async {
    final clean = username.trim().toLowerCase();
    try {
      final doc = await _firestore.collection('usernames').doc(clean).get();
      if (doc.exists && doc.data() != null) {
        final email = doc.data()!['email'];
        if (email != null && email.toString().isNotEmpty) {
          return email.toString();
        }
      }
    } catch (e) {
      debugPrint('Firestore query username doc failed: $e');
    }

    // Fallback: search in users collection
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final email = data['email'] ?? data['alternateEmail'] ?? data['googleEmail'];
        if (email != null && email.toString().isNotEmpty) {
          return email.toString();
        }
      }
    } catch (e) {
      debugPrint('Firestore fallback query username in users failed: $e');
    }
    return null;
  }

  @override
  Future<bool> checkEmailUnique(String email) async {
    final clean = email.trim().toLowerCase();
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: clean)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return false;

      final queryAlt = await _firestore
          .collection('users')
          .where('alternateEmail', isEqualTo: clean)
          .limit(1)
          .get();
      if (queryAlt.docs.isNotEmpty) return false;

      return true;
    } catch (e) {
      debugPrint('Firestore checkEmailUnique failed: $e');
      return true;
    }
  }

  @override
  Future<void> sendEmailOTP(String email) async {
    final clean = email.trim().toLowerCase();
    final random = Random.secure();
    final otp = (100000 + random.nextInt(900000)).toString();

    try {
      // 1. Store in Firestore with status 'pending' (onEmailOtpWrite trigger activates as fallback)
      await _firestore.collection('email_otps').doc(clean).set({
        'email': clean,
        'code': otp,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 10))),
        'verified': false,
        'status': 'pending',
      });

      debugPrint('=============================================');
      debugPrint(' [ATHELEOS EMAIL OTP] Code for $clean: $otp ');
      debugPrint('=============================================');

      // 2. Direct HTTPS call to Cloud Function for instant real-time dispatch
      try {
        final uri = Uri.parse(
            'https://us-central1-atheleos-4a146.cloudfunctions.net/sendEmailOtp');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': clean, 'code': otp}),
        );
        if (response.statusCode == 200) {
          debugPrint('Email OTP dispatched directly via Cloud Function HTTPS.');
        } else {
          debugPrint(
              'HTTPS email dispatch returned status ${response.statusCode}, fallback to Firestore trigger.');
        }
      } catch (httpErr) {
        debugPrint('Direct HTTPS email call error: $httpErr (Firestore trigger is active as fallback)');
      }
    } catch (e) {
      debugPrint('Failed to store email OTP in Firestore: $e');
      rethrow;
    }
  }

  @override
  Future<bool> verifyEmailOTP({
    required String email,
    required String code,
  }) async {
    final clean = email.trim().toLowerCase();
    try {
      final doc = await _firestore.collection('email_otps').doc(clean).get();
      if (!doc.exists || doc.data() == null) {
        return false;
      }
      final data = doc.data()!;
      final storedCode = data['code']?.toString().trim() ?? '';
      final inputCode = code.trim();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

      debugPrint('[verifyEmailOTP] Verifying for $clean. doc.exists: ${doc.exists}, storedCode: "$storedCode", inputCode: "$inputCode"');

      if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please request a new one.');
      }

      if (storedCode == inputCode) {
        await _firestore.collection('email_otps').doc(clean).update({'verified': true});
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('verifyEmailOTP error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────
  // PHONE MULTI-ACCOUNT ASSOCIATION (1-to-5 Rule)
  // ─────────────────────────────────────────────────
  @override
  Future<int> getAccountCountForPhone(String phoneNumber) async {
    try {
      final clean = phoneNumber.trim();
      final alternate = clean.startsWith('+91')
          ? clean.substring(3).trim()
          : (clean.length == 10 ? '+91$clean' : clean);
      final variants = {clean, alternate}.where((p) => p.isNotEmpty).toList();

      final query = await _firestore
          .collection('users')
          .where('phoneNumber', whereIn: variants)
          .get();
      return query.docs.where((d) => d.data()['isDeleted'] != true).length;
    } catch (e) {
      debugPrint('Firestore getAccountCountForPhone error: $e');
      return 0;
    }
  }

  @override
  Future<List<UserModel>> getUsersByPhone(String phoneNumber) async {
    try {
      final clean = phoneNumber.trim();
      final alternate = clean.startsWith('+91')
          ? clean.substring(3).trim()
          : (clean.length == 10 ? '+91$clean' : clean);
      final variants = {clean, alternate}.where((p) => p.isNotEmpty).toList();

      final query = await _firestore
          .collection('users')
          .where('phoneNumber', whereIn: variants)
          .get();
      return query.docs
          .map((d) => UserModel.fromMap(d.data()))
          .where((u) => !u.isDeleted)
          .toList();
    } catch (e) {
      debugPrint('Firestore getUsersByPhone error: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────
  // FALLBACK 1: Alternate Email — Sign In
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> signInWithAlternateEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        // Try to load full profile from Firestore (alternate email sign-in for existing user)
        final profile = await getCurrentUser(user.uid);
        if (profile != null) return profile;
        // No profile yet — return basic model so onboarding can continue
        return _userModelFromFirebaseUser(user,
            googleVerified: false, alternateEmail: email.trim());
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Alternate email sign-in failed: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Alternate email sign-in error: $e');
      rethrow;
    }
    return null;
  }

  // ─────────────────────────────────────────────────
  // FALLBACK 1: Alternate Email — Register (new user, email+password)
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> registerWithAlternateEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        return _userModelFromFirebaseUser(user,
            googleVerified: false, alternateEmail: cleanEmail);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Alternate email registration failed: [${e.code}] ${e.message}');
      if (e.code == 'email-already-in-use') {
        // Attempt to clean up orphan/incomplete registration
        final wasCleaned = await cleanupIncompleteAccount(cleanEmail);
        if (wasCleaned) {
          debugPrint(
              'Orphan account purged for $cleanEmail. Retrying createUserWithEmailAndPassword...');
          final UserCredential retryCred =
              await _auth.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          final user = retryCred.user;
          if (user != null) {
            return _userModelFromFirebaseUser(user,
                googleVerified: false, alternateEmail: cleanEmail);
          }
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('Alternate email registration error: $e');
      rethrow;
    }
    return null;
  }

  @override
  Future<bool> cleanupIncompleteAccount(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final uri = Uri.parse(
          'https://us-central1-atheleos-4a146.cloudfunctions.net/cleanupIncompleteAccount');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': cleanEmail}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['deletedOrphan'] == true) {
          debugPrint('Successfully purged orphan user account for $cleanEmail');
          return true;
        } else if (data['completed'] == true) {
          debugPrint('Account for $cleanEmail has a completed profile; not an orphan.');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error calling cleanupIncompleteAccount Cloud Function: $e');
    }

    // Client-side fallback: check if current user matches email and has no completed profile
    try {
      final current = _auth.currentUser;
      if (current != null && current.email?.toLowerCase().trim() == cleanEmail) {
        final profile = await getCurrentUser(current.uid);
        if (profile == null || !profile.phoneVerified || profile.role.isEmpty) {
          try {
            await _firestore.collection('users').doc(current.uid).delete();
          } catch (_) {}
          try {
            await current.delete();
            return true;
          } catch (delErr) {
            debugPrint('Client fallback current.delete() error: $delErr');
          }
        }
      }
    } catch (e) {
      debugPrint('Client fallback cleanupIncompleteAccount error: $e');
    }

    return false;
  }

  // ─────────────────────────────────────────────────
  // FALLBACK 1: Send Password Reset to Alternate Email
  // ─────────────────────────────────────────────────
  @override
  Future<void> sendPasswordResetToAlternateEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset failed: [${e.code}] ${e.message}');
      rethrow;
    }
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = code.trim();

    try {
      final uri = Uri.parse(
          'https://us-central1-atheleos-4a146.cloudfunctions.net/resetPasswordWithOtp');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': cleanEmail,
          'code': cleanCode,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        debugPrint('Password reset successfully via Cloud Function for $cleanEmail');
      } else {
        throw Exception(data['error'] ?? 'Failed to reset password. Please try again.');
      }
    } catch (e) {
      debugPrint('resetPasswordWithOtp error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────
  // ONBOARDING OTP: Send (links phone to existing Firebase user)
  // ─────────────────────────────────────────────────
  @override
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception error) onFailed,
  }) async {
    if (kIsWeb) {
      onFailed(Exception(
          'Phone OTP is not supported on web. Please use the Android or iOS app.'));
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('Auto-verification succeeded natively.');
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
              'Firebase phone verification failed: [${e.code}] ${e.message}');
          onFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint(
              'OTP sent to $phoneNumber, verificationId: $verificationId');
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
              'Code auto-retrieval timeout for verificationId: $verificationId');
        },
      );
    } catch (e) {
      debugPrint('verifyPhoneNumber call failed: $e');
      onFailed(Exception(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────
  // ONBOARDING OTP: Verify (links phone to existing Firebase user)
  // ─────────────────────────────────────────────────
  @override
  Future<bool> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        try {
          await currentUser.linkWithCredential(credential);
          return true;
        } on FirebaseAuthException catch (e) {
          debugPrint('linkWithCredential notice: [${e.code}] ${e.message}');
          // If the phone number is already linked to another Firebase Auth user account
          // (or already linked to this user), Firebase Auth rejects linking it again with
          // 'credential-already-in-use' or 'provider-already-linked'.
          // However, Firebase Auth validates the smsCode before checking linking.
          // Since the SMS OTP was verified by Firebase servers, the user has proven
          // ownership of this phone number. Atheleos explicitly supports multiple accounts
          // (up to 5) sharing the same verified phone number in Firestore.
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            return true;
          }
          return false;
        }
      } else {
        try {
          await _auth.signInWithCredential(credential);
          return true;
        } on FirebaseAuthException catch (e) {
          debugPrint('signInWithCredential notice: [${e.code}] ${e.message}');
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            return true;
          }
          return false;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP verification failed: [${e.code}] ${e.message}');
      if (e.code == 'credential-already-in-use' ||
          e.code == 'provider-already-linked') {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('OTP verification error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────
  // FALLBACK 2 LOGIN OTP: Send (standalone sign-in, no linking)
  // ─────────────────────────────────────────────────
  @override
  Future<void> sendLoginOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception error) onFailed,
  }) async {
    if (kIsWeb) {
      onFailed(Exception(
          'Phone OTP sign-in is not supported on web. Please use the mobile app.'));
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('Auto login-OTP verification succeeded natively.');
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('Login OTP verification failed: [${e.code}] ${e.message}');
          onFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint(
              'Login OTP sent to $phoneNumber, verificationId: $verificationId');
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint(
              'Login OTP auto-retrieval timeout for verificationId: $verificationId');
        },
      );
    } catch (e) {
      debugPrint('sendLoginOTP call failed: $e');
      onFailed(Exception(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────
  // FALLBACK 2 LOGIN OTP: Verify & Sign In → return UserModel
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> verifyLoginOTPAndSignIn({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      // Try to find an existing Firestore profile for this UID
      final existingProfile = await getCurrentUser(user.uid);
      if (existingProfile != null) return existingProfile;

      // Try by phone number (user may have registered via Google + phone link)
      final phone = user.phoneNumber ?? '';
      if (phone.isNotEmpty) {
        final byPhone = await getUserByPhone(phone);
        if (byPhone != null) return byPhone;
      }

      // Brand-new user via phone — return minimal model for onboarding
      return _userModelFromFirebaseUser(user,
          googleVerified: false, phoneVerified: true);
    } on FirebaseAuthException catch (e) {
      debugPrint('Login OTP sign-in failed: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Login OTP sign-in error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────
  // PROFILE: Lookup by phone number in Firestore
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> getUserByPhone(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserModel.fromMap(query.docs.first.data());
      }
    } catch (e) {
      debugPrint('Firestore getUserByPhone failed: $e');
    }
    return null;
  }

  // ─────────────────────────────────────────────────
  // PROFILE: Username uniqueness check
  // ─────────────────────────────────────────────────
  @override
  Future<bool> checkUsernameUnique(String username) async {
    if (username.isEmpty) return false;
    try {
      final docRef = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase().trim())
          .get();
      return !docRef.exists;
    } catch (e) {
      debugPrint(
          'Firestore query username failed: $e. Simulating username availability.');
      return !['admin', 'atheleos', 'test', 'coach']
          .contains(username.toLowerCase());
    }
  }

  // ─────────────────────────────────────────────────
  // PROFILE: Save user to Firestore
  // ─────────────────────────────────────────────────
  @override
  Future<void> saveUserProfile(UserModel user) async {
    try {
      final updatedUser = user.copyWith(
        profileCompletion: user.calculateCompletionPercentage(),
        updatedAt: DateTime.now(),
      );

      final userRef = _firestore.collection('users').doc(updatedUser.uid);

      // If saving for the first time or updating during onboarding, we should reserve the username
      if (updatedUser.username.isNotEmpty) {
        final usernameRef =
            _firestore.collection('usernames').doc(updatedUser.username);

        await _firestore.runTransaction((transaction) async {
          final usernameDoc = await transaction.get(usernameRef);
          if (usernameDoc.exists &&
              usernameDoc.data()?['uid'] != updatedUser.uid) {
            throw Exception('Username already reserved by another user.');
          }

          final userEmail = updatedUser.email.isNotEmpty
              ? updatedUser.email
              : (updatedUser.alternateEmail.isNotEmpty
                  ? updatedUser.alternateEmail
                  : updatedUser.googleEmail);

          transaction.set(usernameRef, {
            'uid': updatedUser.uid,
            'email': userEmail.toLowerCase().trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.set(
              userRef, updatedUser.toMap(), SetOptions(merge: true));
        });
      } else {
        await userRef.set(updatedUser.toMap(), SetOptions(merge: true));
      }
      debugPrint('Saved profile successfully to Firestore: ${updatedUser.uid}');
    } catch (e) {
      debugPrint('Firestore failed to save user document: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────
  // PROFILE: Get user by UID
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> getCurrentUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        if (doc.data()!['isDeleted'] == true) {
          await signOut();
          throw StateError(
              'This account has been deleted and cannot be accessed.');
        }
        return UserModel.fromMap(doc.data()!);
      }

      // Fallback: If document by UID doesn't exist, check if current authenticated user's phone matches any profile
      final authUser = _auth.currentUser;
      if (authUser != null && authUser.uid == uid && authUser.phoneNumber != null && authUser.phoneNumber!.isNotEmpty) {
        final profile = await getUserByPhone(authUser.phoneNumber!);
        if (profile != null) {
          return profile;
        }
      }

      return null;
    } on StateError {
      rethrow;
    } catch (e) {
      debugPrint('Firestore failed to fetch user document: $e.');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────
  // ACCOUNT MUTATIONS
  // ─────────────────────────────────────────────────

  @override
  Future<void> changeEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    // verifyBeforeUpdateEmail sends a verification link.
    // The email won't change in Auth until the user clicks the link.
    await user.verifyBeforeUpdateEmail(newEmail.trim());
    debugPrint('Verification email sent to $newEmail');
  }

  @override
  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      await user.updatePhoneNumber(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'credential-already-in-use' ||
          e.code == 'provider-already-linked') {
        debugPrint('Phone update notice: [${e.code}] ${e.message}');
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    final providers = user.providerData.map((info) => info.providerId).toSet();

    if (providers.contains(EmailAuthProvider.PROVIDER_ID)) {
      final email = user.email;
      if (email == null || password == null || password.isEmpty) {
        throw Exception('Your current password is required.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      return;
    }

    if (providers.contains(GoogleAuthProvider.PROVIDER_ID)) {
      if (kIsWeb) {
        await user.reauthenticateWithPopup(GoogleAuthProvider());
        return;
      }
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null)
        throw Exception('Google re-authentication was cancelled.');
      final googleAuth = await googleUser.authentication;
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ),
      );
      return;
    }

    await user.getIdToken(true);
  }

  @override
  Future<void> updatePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await reauthenticate(password: currentPassword);
    await user.updatePassword(newPassword);
    debugPrint('Password updated successfully.');
  }

  // ─────────────────────────────────────────────────
  // SESSION: Sign out
  // ─────────────────────────────────────────────────
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  // ─────────────────────────────────────────────────
  // HELPER: Build minimal UserModel from a Firebase user object
  // ─────────────────────────────────────────────────
  UserModel _userModelFromFirebaseUser(
    User user, {
    bool googleVerified = false,
    bool phoneVerified = false,
    String alternateEmail = '',
  }) {
    return UserModel(
      uid: user.uid,
      googleEmail: googleVerified ? (user.email ?? '') : '',
      alternateEmail: alternateEmail,
      username: '',
      fullName: user.displayName ?? '',
      phoneNumber: user.phoneNumber ?? '',
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
      phoneVerified: phoneVerified ||
          (user.phoneNumber != null && user.phoneNumber!.isNotEmpty),
      googleVerified: googleVerified,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
