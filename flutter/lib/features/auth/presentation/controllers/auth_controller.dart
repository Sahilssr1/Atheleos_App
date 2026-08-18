import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../core/router/app_router.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';

// ─────────────────────────────────────────────────────────────────
// AUTH STEP ENUM
// ─────────────────────────────────────────────────────────────────
enum AuthStep {
  splash, // 0 – animated splash
  login, // 1 – primary: Continue with Google
  phoneLogin, // 2 – fallback 2: Mobile number entry for sign-in
  phoneLoginOtp, // 3 – fallback 2: OTP entry for sign-in
  phoneInput, // 4 – onboarding: enter phone (after Google/email auth)
  otpInput, // 5 – onboarding: OTP after phoneInput
  basicAccount, // 6 – onboarding: Username, Full Name, Alt Email, Password
  roleSelection, // 7 – onboarding: Athlete / Coach / Brand
  location, // 8 – onboarding: Country, State, City
  roleDetails, // 9 – onboarding: sport, position, height, weight
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

  AuthState({
    required this.currentStep,
    required this.currentUser,
    required this.isLoading,
    this.errorMessage,
    required this.verificationId,
    required this.tempPhoneNumber,
    required this.tempEmail,
  });

  AuthState copyWith({
    AuthStep? currentStep,
    UserModel? currentUser,
    bool? isLoading,
    String? errorMessage,
    String? verificationId,
    String? tempPhoneNumber,
    String? tempEmail,
  }) {
    return AuthState(
      currentStep: currentStep ?? this.currentStep,
      currentUser: currentUser ?? this.currentUser,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // explicitly nullable — null clears error
      verificationId: verificationId ?? this.verificationId,
      tempPhoneNumber: tempPhoneNumber ?? this.tempPhoneNumber,
      tempEmail: tempEmail ?? this.tempEmail,
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
        // Force reload the user to pull the latest linked providers from the server
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
        if (existingProfile != null) {
          _ref.read(loggedInUserIdProvider.notifier).state = existingProfile.uid;
          _ref.read(currentProfileIdProvider.notifier).state = existingProfile.uid;
          _ref.read(authStateProvider.notifier).state = true;
          state =
              state.copyWith(currentStep: AuthStep.complete, isLoading: false);
        } else {
          // Incomplete profile - delete user record from Firebase Auth and sign out on startup
          try {
            await currentUser.delete();
          } catch (e) {
            debugPrint('Failed to delete incomplete user on startup: $e');
          }
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
    state =
        state.copyWith(currentStep: AuthStep.phoneLogin, errorMessage: null);
  }

  void goBackToLogin() {
    state = state.copyWith(currentStep: AuthStep.login, errorMessage: null);
  }

  void previousStep() {
    // Custom back logic for the new non-linear recovery steps
    switch (state.currentStep) {
      case AuthStep.phoneLogin:
        state = state.copyWith(
            currentStep: AuthStep.login, errorMessage: null);
        break;
      case AuthStep.phoneLoginOtp:
        state = state.copyWith(
            currentStep: AuthStep.phoneLogin, errorMessage: null);
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
  // STEP 1: Google Sign-In (primary)
  // ──────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.signInWithGoogle();
      if (user != null) {
        final existingUser = await _repository.getCurrentUser(user.uid);
        if (existingUser != null) {
          _completeLogin(existingUser);
        } else {
          state = state.copyWith(
            currentUser: user,
            isLoading: false,
            currentStep: AuthStep.phoneInput,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Google Sign-In failed to return user data.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Google Authentication Error: $e',
      );
    }
  }

  // ──────────────────────────────────────────────
  // FALLBACK 1: Alternate Email Sign-In / Register
  // ──────────────────────────────────────────────
  Future<void> signInWithAlternateEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      UserModel? user;

      // First try signing in (existing user)
      try {
        user = await _repository.signInWithAlternateEmail(
            email: email, password: password);
      } on Exception catch (e) {
        final msg = e.toString();
        // If user doesn't exist, try registering (new user path)
        if (msg.contains('user-not-found') ||
            msg.contains('INVALID_LOGIN_CREDENTIALS') ||
            msg.contains('wrong-password')) {
          // Don't auto-create — show proper error
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'No account found for this email and password. Check your credentials or use phone sign-in.',
          );
          return;
        }
        // email-already-in-use on create shouldn't happen here; re-throw others
        state = state.copyWith(
          isLoading: false,
          errorMessage: _friendlyAuthError(msg),
        );
        return;
      }

      if (user != null) {
        final existingUser = await _repository.getCurrentUser(user.uid);
        if (existingUser != null) {
          _completeLogin(existingUser);
        } else {
          // New user via email — proceed to onboarding
          state = state.copyWith(
            currentUser: user.copyWith(alternateEmail: email.trim()),
            isLoading: false,
            currentStep: AuthStep.phoneInput,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Sign-in failed. Please check your credentials.',
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
  // FALLBACK 1: Send Password Reset Email
  // ──────────────────────────────────────────────
  Future<String?> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.sendPasswordResetToAlternateEmail(email);
      state = state.copyWith(isLoading: false, errorMessage: null);
      return null; // null = success
    } catch (e) {
      final msg = _friendlyAuthError(e.toString());
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return msg;
    }
  }

  // ──────────────────────────────────────────────
  // FALLBACK 2: Send OTP for Login (standalone sign-in)
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
          );
        },
        onFailed: (error) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Failed to send OTP: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'OTP Send Error: $e',
      );
    }
  }

  // ──────────────────────────────────────────────
  // FALLBACK 2: Verify Login OTP & Sign In
  // ──────────────────────────────────────────────
  Future<void> verifyLoginOTP(String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repository.verifyLoginOTPAndSignIn(
        verificationId: state.verificationId,
        smsCode: smsCode,
      );

      if (user != null) {
        final existingUser = await _repository.getCurrentUser(user.uid);
        if (existingUser != null) {
          _completeLogin(existingUser);
        } else {
          // New phone user → onboarding
          state = state.copyWith(
            currentUser: user.copyWith(
              phoneNumber: state.tempPhoneNumber,
              phoneVerified: true,
            ),
            isLoading: false,
            currentStep: AuthStep.basicAccount,
          );
        }
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid OTP. Please try again.',
        );
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('invalid-verification-code')) {
        msg = 'Invalid OTP code. Please check and try again.';
      } else if (msg.contains('session-expired')) {
        msg = 'The verification code has expired. Please request a new one.';
      } else if (msg.contains('invalid-phone-number')) {
        msg = 'The phone number entered is invalid.';
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: msg,
      );
    }
  }

  // ──────────────────────────────────────────────
  // ONBOARDING — Send OTP (links phone to authenticated user)
  // ──────────────────────────────────────────────
  Future<void> sendVerificationCode(String phoneNumber) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
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
            errorMessage: 'Failed to send SMS OTP: ${error.toString()}',
          );
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'SMS Send Error: $e',
      );
    }
  }

  // ──────────────────────────────────────────────
  // ONBOARDING — Verify OTP (onboarding link step)
  // ──────────────────────────────────────────────
  Future<void> verifyOTPCode(String smsCode) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final isVerified = await _repository.verifyOTP(
        verificationId: state.verificationId,
        smsCode: smsCode,
      );

      if (isVerified) {
        final updatedUser = state.currentUser.copyWith(
          phoneNumber: state.tempPhoneNumber,
          phoneVerified: true,
        );
        state = state.copyWith(
          currentUser: updatedUser,
          isLoading: false,
          currentStep: AuthStep.basicAccount,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid OTP code. Please verify and try again.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'OTP Verification Error: $e',
      );
    }
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 3: Basic Account
  // ──────────────────────────────────────────────
  Future<bool> createBasicAccount({
    required String username,
    required String fullName,
    required String alternateEmail,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final trimmedUsername = username.toLowerCase().trim();
      final isUnique = await _repository.checkUsernameUnique(trimmedUsername);
      if (!isUnique) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Username "$username" is already taken. Try another.',
        );
        return false;
      }

      final updatedUser = state.currentUser.copyWith(
        username: trimmedUsername,
        fullName: fullName,
        alternateEmail: alternateEmail,
      );

      state = state.copyWith(
        currentUser: updatedUser,
        isLoading: false,
        currentStep: AuthStep.roleSelection,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create basic profile details: $e',
      );
      return false;
    }
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 4: Role Selection
  // ──────────────────────────────────────────────
  void selectRole(String selectedRole) {
    final updatedUser = state.currentUser.copyWith(role: selectedRole);
    state = state.copyWith(
      currentUser: updatedUser,
      currentStep: AuthStep.location,
    );
  }

  // ──────────────────────────────────────────────
  // ONBOARDING Step 5: Location
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
  // ONBOARDING Step 6: Role Details & Final Save
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
        errorMessage: 'Failed saving role-specific profile data: $e',
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
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }
    } catch (e) {
      debugPrint('Failed to delete user during onboarding exit: $e');
    }
    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('Sign out error on onboarding exit: $e');
    }
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
  void _completeLogin(UserModel user) {
    _ref.read(loggedInUserIdProvider.notifier).state = user.uid;
    _ref.read(currentProfileIdProvider.notifier).state = user.uid;
    _ref.read(authStateProvider.notifier).state = true;
    state = state.copyWith(
      currentUser: user,
      isLoading: false,
      currentStep: AuthStep.complete,
    );
  }

  String _friendlyAuthError(String raw) {
    if (raw.contains('user-not-found')) {
      return 'No account found with this email.';
    } else if (raw.contains('wrong-password') ||
        raw.contains('INVALID_LOGIN_CREDENTIALS')) {
      return 'Incorrect password. Please try again.';
    } else if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait and try again.';
    } else if (raw.contains('network-request-failed')) {
      return 'Network error. Check your connection.';
    } else if (raw.contains('invalid-email')) {
      return 'The email address is not valid.';
    } else if (raw.contains('email-already-in-use')) {
      return 'An account already exists with this email. Try signing in.';
    }
    return 'Authentication failed. Please try again.';
  }
}
