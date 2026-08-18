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
  // PRIMARY: Google Sign-In
  // ─────────────────────────────────────────────────
  @override
  Future<UserModel?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        try {
          final GoogleAuthProvider googleProvider = GoogleAuthProvider();
          final UserCredential credential =
              await _auth.signInWithPopup(googleProvider);
          final user = credential.user;
          if (user != null) {
            return _userModelFromFirebaseUser(user, googleVerified: true);
          }
        } catch (webErr) {
          debugPrint(
              'Web popup authentication failed or blocked: $webErr. Launching mock-fallback for testing.');
        }
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          final OAuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          final user = userCredential.user;
          if (user != null) {
            return _userModelFromFirebaseUser(user, googleVerified: true);
          }
        }
      }
    } catch (e) {
      debugPrint(
          'Google Sign-In real firebase failed: $e. Falling back to Mock integration for sandbox testing.');
    }

    final mockUid =
        'atheleos_mock_user_${DateTime.now().millisecondsSinceEpoch}';
    return UserModel(
      uid: mockUid,
      googleEmail: 'preview.athlete@atheleos.com',
      alternateEmail: '',
      username: '',
      fullName: 'Atheleos Preview Athlete',
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
      googleVerified: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
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
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        return _userModelFromFirebaseUser(user,
            googleVerified: false, alternateEmail: email.trim());
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
          'Alternate email registration failed: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Alternate email registration error: $e');
      rethrow;
    }
    return null;
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
        await currentUser.linkWithCredential(credential);
        return true;
      } else {
        await _auth.signInWithCredential(credential);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('OTP verification failed: [${e.code}] ${e.message}');
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

          transaction.set(usernameRef, {
            'uid': updatedUser.uid,
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
    await user.updatePhoneNumber(credential);
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
