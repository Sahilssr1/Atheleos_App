import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/router/app_router.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../../core/utils/user_facing_error.dart';

// ─────────────────────────────────────────────────────────────────
// AUTH STEP ENUM
// ─────────────────────────────────────────────────────────────────
enum AuthStep {
  splash, // 0 – animated splash
  login, // 1 – primary: Username or Email + Password
  phoneLogin, // 2 – Mobile number entry for sign-in
  phoneLoginOtp, // 3 – OTP entry for sign-in (with multi-account chooser)
  createAccountCredentials, // 4 – Page 1: Username, Full Name, Email, Password, Confirm, Email OTP
  phoneInput, // 5 – Page 2: Phone number entry (validates <= 5 accounts limit)
  otpInput, // 6 – Phone OTP verification
  roleSelection, // 7 – Athlete / Coach / Brand / Federation
  location, // 8 – Country, State, City
  roleDetails, // 9 – sport, position, height, weight
  complete, // 10 – success, redirect to home
}

class AuthState {
  final AuthStep currentStep;
  final UserModel currentUser;
  final bool isLoading;
  final String? errorMessage;
  final String verificationId;
  final String tempPhoneNumber;
  final String tempEmail;
  final bool isEmailOtpSent;
  final bool isEmailVerified;
  final bool isCheckingUsername;
  final bool? isUsernameAvailable;
  final List<UserModel> phoneLinkedAccounts;

  AuthState({
    required this.currentStep,
    required this.currentUser,
    required this.isLoading,
    this.errorMessage,
    required this.verificationId,
    required this.tempPhoneNumber,
    required this.tempEmail,
    this.isEmailOtpSent = false,
    this.isEmailVerified = false,
    this.isCheckingUsername = false,
    this.isUsernameAvailable,
    this.phoneLinkedAccounts = const [],
  });

  AuthState copyWith({
    AuthStep? currentStep,
    UserModel? currentUser,
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
    String? tempPhoneNumber,
    String? tempEmail,
    bool? isEmailOtpSent,
    bool? isEmailVerified,
    bool? isCheckingUsername,
    bool? isUsernameAvailable,
    List<UserModel>? phoneLinkedAccounts,
  }) {
    return AuthState(
      currentStep: currentStep ?? this.currentStep,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // explicitly nullable — null clears error
      verificationId: verificationId ?? this.verificationId,
      tempPhoneNumber: tempPhoneNumber ?? this.tempPhoneNumber,
      tempEmail: tempEmail ?? this.tempEmail,
      isEmailOtpSent: isEmailOtpSent ?? this.isEmailOtpSent,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isCheckingUsername: isCheckingUsername ?? this.isCheckingUsername,
      isUsernameAvailable: isUsernameAvailable ?? this.isUsernameAvailable,
      phoneLinkedAccounts: phoneLinkedAccounts ?? this.phoneLinkedAccounts,
    );
  }

  factory AuthState.initial() {
    return AuthState(
      currentStep: AuthStep.splash,
      currentUser: UserModel.initial(),
      isLoading: false,
      errorMessage: null,
      verificationId: '',
      tempPhoneNumber: '',
      tempEmail: '',
      isEmailOtpSent: false,
      isEmailVerified: false,
      isCheckingUsername: false,
      isUsernameAvailable: null,
      phoneLinkedAccounts: const [],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository, ref);
});

// ─────────────────────────────────────────────────────────────────
// AUTH CONTROLLER
// ─────────────────────────────────────────────────────────────────
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthController(this._repository, this._ref) : super(AuthState.initial()) {
    _checkExistingSession();
  }

  // ──────────────────────────────────────────────
  // Session restore on cold start
  // ──────────────────────────────────────────────
  Future<void> _checkExistingSession() async {
    try {
      var currentUser = await FirebaseAuth.instance.authStateChanges().first;
      if (currentUser != null) {
        try {
          await currentUser.reload();
          currentUser = FirebaseAuth.instance.currentUser;
        } catch (e) {
          debugPrint('Failed to reload current user on startup: $e');
        }
      }

      if (currentUser != null) {
        final existingProfile =
            await _repository.getCurrentUser(currentUser.uid);
        if (existingProfile != null &&
            existingProfile.phoneVerified &&
            existingProfile.role.isNotEmpty) {
          _ref.read(loggedInUserIdProvider.notifier).state = existingProfile.uid;
          _ref.read(currentProfileIdProvider.notifier).state = existingProfile.uid;
          _ref.read(authStateProvider.notifier).state = true;
          state =
              state.copyWith(currentStep: AuthStep.complete, isLoading: false);
        } else {
          // Incomplete profile - delete user record from Firebase Auth and sign out on startup
          final uid = currentUser.uid;
          final userEmail = currentUser.email;
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).delete();
          } catch (_) {}
          try {
            await currentUser.delete();
          } catch (e) {
            debugPrint('Failed to delete incomplete user on startup: $e');
            if (userEmail != null && userEmail.isNotEmpty) {
              await _repository.cleanupIncompleteAccount(userEmail);
            }
          }
          await clearSavedCredentials();
          await _repository.signOut();
          state = state.copyWith(currentStep: AuthStep.login, isLoading: false);
        }
      } else {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (state.currentStep == AuthStep.splash) {
            state = state.copyWith(currentStep: AuthStep.login);
          }
        });
      }
    } catch (error) {
      await _repository.signOut();
      _ref.read(authStateProvider.notifier).state = false;
      state = state.copyWith(
        currentStep: AuthStep.login,
        isLoading: false,
        errorMessage: error.toString().contains('deleted')
            ? 'This account has been deleted and cannot be accessed.'
            : 'Your session expired or network error. Please sign in again.',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Navigation helpers
  // ──────────────────────────────────────────────
  void setStep(AuthStep step) {
    state = state.copyWith(currentStep: step, errorMessage: null);
  }

  void goToPhoneLogin() {
    state = state.copyWith(
      currentStep: AuthStep.phoneLogin,
      errorMessage: null,
      phoneLinkedAccounts: const [],
    );
  }

  void goToCreateAccount() {
    state = state.copyWith(
      currentStep: AuthStep.createAccountCredentials,
      errorMessage: null,
      isEmailOtpSent: false,
      isEmailVerified: false,
      isUsernameAvailable: null,
      tempEmail: '',
    );
  }

  void goBackToLogin() {
    clearSavedCredentials();
    state = state.copyWith(
      currentStep: AuthStep.login,
      errorMessage: null,
      phoneLinkedAccounts: const [],
      tempEmail: '',
      isEmailOtpSent: false,
      isEmailVerified: false,
      isUsernameAvailable: null,
    );
  }

  void previousStep() {
    switch (state.currentStep) {
      case AuthStep.phoneLogin:
        state = state.copyWith(currentStep: AuthStep.login, errorMessage: null);
        break;
      case AuthStep.phoneLoginOtp:
        state = state.copyWith(currentStep: AuthStep.phoneLogin, errorMessage: null);
        break;
      case AuthStep.createAccountCredentials:
        state = state.copyWith(currentStep: AuthStep.login, errorMessage: null);
        break;
      case AuthStep.phoneInput:
        state = state.copyWith(
            currentStep: AuthStep.createAccountCredentials,
            errorMessage: null);
        break;
      case AuthStep.otpInput:
        state = state.copyWith(
            currentStep: AuthStep.phoneInput, errorMessage: null);
        break;
      case AuthStep.roleSelection:
        state = state.copyWith(
            currentStep: AuthStep.otpInput, errorMessage: null);
        break;
      case AuthStep.location:
        state = state.copyWith(
            currentStep: AuthStep.roleSelection, errorMessage: null);
        break;
      case AuthStep.roleDetails:
        state = state.copyWith(
            currentStep: AuthStep.location, errorMessage: null);
        break;
      default:
        final prevIndex = state.currentStep.index - 1;
        if (prevIndex >= 0) {
          state = state.copyWith(
            currentStep: AuthStep.values[prevIndex],
            errorMessage: null,
          );
        }
    }
  }

  void nextStep() {
    final nextIndex = state.currentStep.index + 1;
    if (nextIndex < AuthStep.values.length) {
      state = state.copyWith(
        currentStep: AuthStep.values[nextIndex],
        errorMessage: null,
      );
    }
  }

  // ──────────────────────────────────────────────
  // PRIMARY: Username or Email + Password Sign-In
  // ──────────────────────────────────────────────
  Future<void> loginWithUsernameOrEmail({
    required String identifier,
    required String password,
    bool saveCredentials = true,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.loginWithEmailOrUsername(
        identifier: identifier,
        password: password,
      );
      if (user != null) {
        // Trigger OS / Google Password Manager to save password
        try {
          TextInput.finishAutofillContext(shouldSave: true);
        } catch (_) {}

        if (saveCredentials) {
          await saveLoginCredentials(
            identifier: identifier,
            password: password,
            username: user.username,
            fullName: user.fullName,
            role: user.role,
          );
        }
        _completeLogin(user);
      } else {
        try {
          TextInput.finishAutofillContext(shouldSave: false);
        } catch (_) {}
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in failed. Please check your credentials.',
        );
      }
    } on FirebaseAuthException catch (e) {
      try {
        TextInput.finishAutofillContext(shouldSave: false);
      } catch (_) {}
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.message ?? e.code),
      );
    } catch (e) {
      try {
        TextInput.finishAutofillContext(shouldSave: false);
      } catch (_) {}
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.toString()),
      );
    }
  }

  // ──────────────────────────────────────────────
  // CREDENTIAL & AUTOFILL PERSISTENCE
  // ──────────────────────────────────────────────
  Future<void> saveLoginCredentials({
    required String identifier,
    required String password,
    String? username,
    String? fullName,
    String? role,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_login_identifier', identifier);
      await prefs.setString('saved_login_password', base64Encode(utf8.encode(password)));
      if (username != null && username.isNotEmpty) {
        await prefs.setString('saved_login_username', username);
      }
      if (fullName != null && fullName.isNotEmpty) {
        await prefs.setString('saved_login_fullname', fullName);
      }
      if (role != null && role.isNotEmpty) {
        await prefs.setString('saved_login_role', role);
      }
      await prefs.setBool('saved_login_has_credentials', true);
    } catch (e) {
      debugPrint('Error saving credentials to SharedPreferences: $e');
    }
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final identifier = prefs.getString('saved_login_identifier') ??
          prefs.getString('saved_login_username') ??
          prefs.getString('saved_login_email');
      final encodedPass = prefs.getString('saved_login_password');

      if (identifier != null && identifier.isNotEmpty) {
        String password = '';
        if (encodedPass != null && encodedPass.isNotEmpty) {
          try {
            password = utf8.decode(base64Decode(encodedPass));
          } catch (_) {
            password = encodedPass;
          }
        }
        return {
          'identifier': identifier,
          'password': password,
          'username': prefs.getString('saved_login_username') ?? identifier,
          'fullName': prefs.getString('saved_login_fullname') ?? identifier,
          'role': prefs.getString('saved_login_role') ?? 'ATHLETE',
        };
      }
    } catch (e) {
      debugPrint('Error retrieving saved credentials: $e');
    }
    return null;
  }

  Future<void> clearSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_login_identifier');
      await prefs.remove('saved_login_password');
      await prefs.remove('saved_login_username');
      await prefs.remove('saved_login_fullname');
      await prefs.remove('saved_login_role');
      await prefs.remove('saved_login_has_credentials');
    } catch (e) {
      debugPrint('Error clearing saved credentials: $e');
    }
  }

  Future<void> updateSavedPasswordForEmail({
    required String email,
    required String newPassword,
  }) async {
    final clean = email.trim().toLowerCase();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('alternateEmail', isEqualTo: clean)
          .limit(1)
          .get();

      String username = clean;
      String fullName = '';
      String role = 'ATHLETE';

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        username = data['username'] ?? clean;
        fullName = data['fullName'] ?? data['displayName'] ?? '';
        role = data['role'] ?? 'ATHLETE';
      }

      await saveLoginCredentials(
        identifier: username,
        password: newPassword,
        username: username,
        fullName: fullName,
        role: role,
      );
    } catch (e) {
      debugPrint('Error updating saved credentials after password reset: $e');
    }
  }

  Future<void> directSignInWithSavedAccount() async {
    final creds = await getSavedCredentials();
    if (creds != null &&
        creds['identifier'] != null &&
        creds['password'] != null &&
        creds['password']!.isNotEmpty) {
      await loginWithUsernameOrEmail(
        identifier: creds['identifier']!,
        password: creds['password']!,
      );
    } else {
      state = state.copyWith(
        errorMessage: 'Saved credentials not found. Please sign in manually.',
      );
    }
  }

  // ──────────────────────────────────────────────
  // SEND PASSWORD RESET EMAIL / OTP
  // ──────────────────────────────────────────────
  Future<String?> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.sendPasswordResetToAlternateEmail(email);
      state = state.copyWith(isLoading: false, errorMessage: null);
      return null;
    } catch (e) {
      final msg = _friendlyAuthError(e.toString());
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return msg;
    }
  }

  Future<String?> sendForgotPasswordOTP(String email) async {
    final clean = email.trim().toLowerCase();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isUnique = await _repository.checkEmailUnique(clean);
      if (isUnique) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'No account found with this email address.',
        );
        return 'No account found with this email address.';
      }

      await _repository.sendEmailOTP(clean);
      state = state.copyWith(
        isLoading: false,
        tempEmail: clean,
        errorMessage: null,
      );
      return null;
    } catch (e) {
      final msg = _friendlyAuthError(e.toString());
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return msg;
    }
  }

  Future<bool> verifyForgotPasswordOTP({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isVerified = await _repository.verifyEmailOTP(
        email: email.trim().toLowerCase(),
        code: code.trim(),
      );
      state = state.copyWith(
        isLoading: false,
        errorMessage: isVerified ? null : 'Invalid verification code.',
      );
      return isVerified;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.toString()),
      );
      return false;
    }
  }

  Future<String?> resetPasswordWithOtp({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.resetPasswordWithOtp(
        email: email.trim().toLowerCase(),
        code: code.trim(),
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false, errorMessage: null);
      return null;
    } catch (e) {
      final msg = _friendlyAuthError(e);
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return msg;
    }
  }

  // ──────────────────────────────────────────────
  // PHONE LOGIN: Send OTP
  // ──────────────────────────────────────────────
  Future<void> sendLoginOTP(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.sendLoginOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            tempPhoneNumber: phoneNumber,
            currentStep: AuthStep.phoneLoginOtp,
            phoneLinkedAccounts: const [],
          );
        },
        onFailed: (error) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: UserFacingError.message(error, fallback: 'Failed to send verification code. Please try again.'),
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Failed to send verification code. Please try again.'),
      );
    }
  }

  // ──────────────────────────────────────────────
  // PHONE LOGIN: Verify OTP & Handle 1-to-5 Accounts
  // ──────────────────────────────────────────────
  Future<void> verifyLoginOTP(String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authUser = await _repository.verifyLoginOTPAndSignIn(
        verificationId: state.verificationId,
        smsCode: smsCode,
      );

      if (authUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid verification code. Please try again.',
        );
        return;
      }

      // Query all user accounts linked to this phone number
      final accounts = await _repository.getUsersByPhone(state.tempPhoneNumber);

      if (accounts.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          phoneLinkedAccounts: const [],
          errorMessage:
              'No registered accounts found with ${state.tempPhoneNumber}. Please create an account.',
        );
      } else {
        // ALWAYS present the Account Selection screen — whether 1 account or up to 5 accounts!
        state = state.copyWith(
          isLoading: false,
          phoneLinkedAccounts: accounts,
          currentStep: AuthStep.phoneLoginOtp,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.toString()),
      );
    }
  }

  // ──────────────────────────────────────────────
  // Select which account to use from phone accounts
  // ──────────────────────────────────────────────
  void selectPhoneAccount(UserModel account) {
    _completeLogin(account);
  }

  void clearPhoneLinkedAccounts() {
    state = state.copyWith(
      phoneLinkedAccounts: const [],
      currentStep: AuthStep.phoneLogin,
      errorMessage: null,
    );
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Real-time distinct username check
  // ──────────────────────────────────────────────
  Future<void> checkUsernameAvailability(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.length < 3) {
      state = state.copyWith(isUsernameAvailable: null, isCheckingUsername: false);
      return;
    }
    state = state.copyWith(isCheckingUsername: true);
    try {
      final isUnique = await _repository.checkUsernameUnique(clean);
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: isUnique,
      );
    } catch (e) {
      state = state.copyWith(
        isCheckingUsername: false,
        isUsernameAvailable: null,
      );
    }
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Send Email OTP (checks 1-email-1-ID)
  // ──────────────────────────────────────────────
  Future<void> sendEmailVerificationOtp(String email) async {
    final clean = email.trim().toLowerCase();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isUnique = await _repository.checkEmailUnique(clean);
      if (!isUnique) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'An account already exists with this email. Try logging in with this email instead.',
        );
        return;
      }

      await _repository.sendEmailOTP(clean);
      state = state.copyWith(
        isLoading: false,
        tempEmail: clean,
        isEmailOtpSent: true,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Failed to send verification email. Please try again.'),
      );
    }
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Verify Email OTP
  // ──────────────────────────────────────────────
  Future<bool> verifyEmailOtp(String code) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isVerified = await _repository.verifyEmailOTP(
        email: state.tempEmail,
        code: code,
      );
      if (isVerified) {
        state = state.copyWith(
          isLoading: false,
          isEmailVerified: true,
          errorMessage: null,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'Incorrect email verification code. Please check and try again.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Verification failed. Please try again.'),
      );
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Finalize Credentials & Proceed to Phone Step
  // ──────────────────────────────────────────────
  Future<void> finalizeCredentialsAndProceed({
    required String username,
    required String fullName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final authUser = await _repository.registerWithAlternateEmail(
        email: email.trim(),
        password: password,
      );

      if (authUser == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create user account. Please try again.',
        );
        return;
      }

      final cleanUsername = username.trim().toLowerCase();
      final updatedUser = UserModel.initial().copyWith(
        uid: authUser.uid,
        username: cleanUsername,
        fullName: fullName.trim(),
        alternateEmail: email.trim(),
        googleEmail: '',
      );

      // Trigger OS / Google Password Manager to save credentials
      try {
        TextInput.finishAutofillContext(shouldSave: true);
      } catch (_) {}

      // Pre-save credentials locally for direct sign-in
      await saveLoginCredentials(
        identifier: cleanUsername,
        password: password,
        username: cleanUsername,
        fullName: fullName.trim(),
      );

      state = state.copyWith(
        currentUser: updatedUser,
        isLoading: false,
        currentStep: AuthStep.phoneInput,
      );
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.message ?? e.code),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(e.toString()),
      );
    }
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Phone Number (Check <= 5 limit) & Send OTP
  // ──────────────────────────────────────────────
  Future<void> sendRegistrationPhoneCode(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final count = await _repository.getAccountCountForPhone(phoneNumber);
      if (count >= 5) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'This phone number has reached the maximum limit of 5 accounts. Try logging in with your phone number.',
        );
        return;
      }

      await _repository.sendOTP(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            tempPhoneNumber: phoneNumber,
            currentStep: AuthStep.otpInput,
          );
        },
        onFailed: (error) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: UserFacingError.message(error, fallback: 'Failed to send verification code. Please try again.'),
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Failed to send verification code. Please try again.'),
      );
    }
  }

  // ──────────────────────────────────────────────
  // CREATE ACCOUNT: Verify Phone OTP & Proceed to Roles
  // ──────────────────────────────────────────────
  Future<void> verifyRegistrationPhoneCode(String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      if (state.verificationId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Verification session expired. Please request a new code.',
        );
        return;
      }

      debugPrint('Verifying registration OTP for phone: ${state.tempPhoneNumber}');
      final isVerified = await _repository.verifyOTP(
        verificationId: state.verificationId,
        smsCode: smsCode,
      );

      if (isVerified) {
        debugPrint('Phone successfully verified for registration: ${state.tempPhoneNumber}');
        final updatedUser = state.currentUser.copyWith(
          phoneNumber: state.tempPhoneNumber,
          phoneVerified: true,
        );
        state = state.copyWith(
          currentUser: updatedUser,
          isLoading: false,
          currentStep: AuthStep.roleSelection,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid OTP code. Please verify and try again.',
        );
      }
    } catch (e) {
      debugPrint('OTP Verification Error: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Verification failed. Please check the code and try again.'),
      );
    }
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 3: Role Selection
  // ──────────────────────────────────────────────
  void selectRole(String selectedRole) {
    final updatedUser = state.currentUser.copyWith(role: selectedRole);
    state = state.copyWith(
      currentUser: updatedUser,
      currentStep: AuthStep.location,
    );
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 4: Location
  // ──────────────────────────────────────────────
  void setLocation({
    required String country,
    required String stateName,
    required String cityName,
  }) {
    final updatedUser = state.currentUser.copyWith(
      country: country,
      state: stateName,
      city: cityName,
    );
    state = state.copyWith(
      currentUser: updatedUser,
      currentStep: AuthStep.roleDetails,
    );
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 5: Role Details & Final Save
  // ──────────────────────────────────────────────
  Future<void> submitRoleDetails({
    required String sport,
    String? position,
    String? recruitmentStatus,
    String? height,
    String? weight,
    bool skipped = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      UserModel updatedUser;
      if (skipped) {
        updatedUser = state.currentUser.copyWith(
          sport: '',
          position: '',
          recruitmentStatus: '',
          height: '',
          weight: '',
        );
      } else {
        updatedUser = state.currentUser.copyWith(
          sport: sport,
          position: position ?? '',
          recruitmentStatus: recruitmentStatus ?? '',
          height: height ?? '',
          weight: weight ?? '',
        );
      }

      await _repository.saveUserProfile(updatedUser);
      final savedUser =
          await _repository.getCurrentUser(updatedUser.uid) ?? updatedUser;

      _ref.read(loggedInUserIdProvider.notifier).state = savedUser.uid;
      _ref.read(currentProfileIdProvider.notifier).state = savedUser.uid;

      state = state.copyWith(
        currentUser: savedUser,
        isLoading: false,
        currentStep: AuthStep.complete,
      );
      _ref.read(authStateProvider.notifier).state = true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFacingError.message(e, fallback: 'Failed to save profile details. Please try again.'),
      );
    }
  }

  // ──────────────────────────────────────────────
  // Sign Out
  // ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
    _ref.read(authStateProvider.notifier).state = false;
    _ref.read(loggedInUserIdProvider.notifier).state = '';
    _ref.read(currentProfileIdProvider.notifier).state = '';
    state = AuthState.initial().copyWith(currentStep: AuthStep.login);
  }

  Future<void> exitOnboarding() async {
    state = state.copyWith(isLoading: true);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? state.currentUser.uid;
    final username = state.currentUser.username.trim().toLowerCase();
    final tempEmail = state.tempEmail.trim().toLowerCase();
    final altEmail = state.currentUser.alternateEmail.trim().toLowerCase();

    // 1. Clean up any partial Firestore user document
    if (uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (e) {
        debugPrint('Firestore cleanup error on user doc: $e');
      }
    }

    // 2. Clean up reserved username in Firestore
    if (username.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('usernames').doc(username).delete();
      } catch (e) {
        debugPrint('Firestore cleanup error on username doc: $e');
      }
    }

    // 3. Clean up email OTP record in Firestore
    final emailToClean = tempEmail.isNotEmpty ? tempEmail : altEmail;
    if (emailToClean.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('email_otps').doc(emailToClean).delete();
      } catch (e) {
        debugPrint('Firestore cleanup error on email_otps doc: $e');
      }
    }

    // 4. Delete the incomplete user account from Firebase Authentication
    try {
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete user from Firebase Auth during onboarding exit: $e');
    }

    // 5. Clear locally saved credentials in SharedPreferences
    await clearSavedCredentials();

    // 6. Sign out from Firebase
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('Sign out error on onboarding exit: $e');
    }

    // 7. Reset all Riverpod state and return to login screen
    _ref.read(authStateProvider.notifier).state = false;
    _ref.read(loggedInUserIdProvider.notifier).state = '';
    _ref.read(currentProfileIdProvider.notifier).state = '';
    state = AuthState.initial().copyWith(currentStep: AuthStep.login);
  }

  void resetFlow() {
    state = AuthState.initial();
  }

  // ──────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────
  void _completeLogin(UserModel user) async {
    try {
      TextInput.finishAutofillContext(shouldSave: true);
    } catch (_) {}

    _ref.read(loggedInUserIdProvider.notifier).state = user.uid;
    _ref.read(currentProfileIdProvider.notifier).state = user.uid;
    _ref.read(authStateProvider.notifier).state = true;
    state = state.copyWith(
      currentUser: user,
      isLoading: false,
      currentStep: AuthStep.complete,
      phoneLinkedAccounts: const [],
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      if (user.username.isNotEmpty) {
        await prefs.setString('saved_login_username', user.username);
      }
      if (user.email.isNotEmpty) {
        await prefs.setString('saved_login_email', user.email);
      }
      if (user.fullName.isNotEmpty) {
        await prefs.setString('saved_login_fullname', user.fullName);
      }
      if (user.role.isNotEmpty) {
        await prefs.setString('saved_login_role', user.role);
      }
    } catch (e) {
      debugPrint('Error saving login info to SharedPreferences: $e');
    }
  }

  String _friendlyAuthError(dynamic raw) {
    return UserFacingError.message(raw);
  }
}
