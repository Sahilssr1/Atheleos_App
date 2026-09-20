import '../../data/models/user_model.dart';

abstract class AuthRepository {
  // --- Primary Sign-In (Username or Email + Password) ---
  Future<UserModel?> loginWithEmailOrUsername({
    required String identifier,
    required String password,
  });

  // --- Email Registration & OTP Verification ---
  Future<bool> checkEmailUnique(String email);
  Future<String?> getEmailForUsername(String username);
  Future<void> sendEmailOTP(String email);
  Future<bool> verifyEmailOTP({
    required String email,
    required String code,
  });

  // --- Alternate Email (Direct Firebase Auth) ---
  Future<UserModel?> signInWithAlternateEmail({
    required String email,
    required String password,
  });
  Future<UserModel?> registerWithAlternateEmail({
    required String email,
    required String password,
  });
  Future<void> sendPasswordResetToAlternateEmail(String email);
  Future<void> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  });
  Future<bool> cleanupIncompleteAccount(String email);

  // --- Phone OTP & Multi-Account Association (Up to 5 accounts per phone) ---
  Future<int> getAccountCountForPhone(String phoneNumber);
  Future<List<UserModel>> getUsersByPhone(String phoneNumber);

  // --- Phone OTP (onboarding — verify phone code) ---
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(Exception error) onFailed,
  });
  Future<bool> verifyOTP({
    required String verificationId,
    required String smsCode,
  });

  // --- Phone OTP (login — standalone sign-in, returns existing user(s)) ---
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
