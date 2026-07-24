import '../../data/models/user_model.dart';

abstract class AuthRepository {
  // --- Primary Sign-In ---
  Future<UserModel?> signInWithGoogle();

  // --- Fallback 1: Alternate Email ---
  Future<UserModel?> signInWithAlternateEmail({
    required String email,
    required String password,
  });
  Future<UserModel?> registerWithAlternateEmail({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetToAlternateEmail(String email);

  // --- Fallback 2: Phone OTP (onboarding — links to existing Firebase user) ---
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception error) onFailed,
  });
  Future<bool> verifyOTP({
    required String verificationId,
    required String smsCode,
  });

  // --- Fallback 2: Phone OTP (login — standalone sign-in, returns existing user) ---
  Future<void> sendLoginOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception error) onFailed,
  });
  Future<UserModel?> verifyLoginOTPAndSignIn({
    required String verificationId,
    required String smsCode,
  });

  // --- Profile & Session ---
  Future<bool> checkUsernameUnique(String username);
  Future<void> saveUserProfile(UserModel user);
  Future<UserModel?> getCurrentUser(String uid);
  Future<UserModel?> getUserByPhone(String phoneNumber);

  // --- Account Mutations ---
  Future<void> changeEmail(String newEmail);
  Future<void> updatePhoneNumber({
    required String verificationId,
    required String smsCode,
  });
  Future<void> reauthenticate({String? password});
  Future<void> updatePassword(String currentPassword, String newPassword);

  Future<void> signOut();
}
