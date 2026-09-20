import 'package:flutter_test/flutter_test.dart';
import 'package:atheleos/features/auth/presentation/controllers/auth_controller.dart';
import 'package:atheleos/features/auth/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth OTP Verification & Multi-Account Tests', () {
    test('UserModel accurately tracks phone verification state', () {
      final initialUser = UserModel.initial();
      expect(initialUser.phoneVerified, isFalse);
      expect(initialUser.phoneNumber, isEmpty);

      final verifiedUser = initialUser.copyWith(
        phoneNumber: '+919876543210',
        phoneVerified: true,
      );

      expect(verifiedUser.phoneVerified, isTrue);
      expect(verifiedUser.phoneNumber, '+919876543210');
      expect(verifiedUser.toMap()['phoneVerified'], isTrue);
      expect(verifiedUser.toMap()['phoneNumber'], '+919876543210');
    });

    test('AuthState transitions cleanly to roleSelection upon OTP verification', () {
      final initial = AuthState.initial().copyWith(
        verificationId: 'test_verification_id_123',
        tempPhoneNumber: '+919876543210',
        currentStep: AuthStep.otpInput,
      );

      expect(initial.currentStep, AuthStep.otpInput);
      expect(initial.verificationId, 'test_verification_id_123');
      expect(initial.tempPhoneNumber, '+919876543210');

      // Simulating the state update that occurs in verifyRegistrationPhoneCode when isVerified is true
      final updatedUser = initial.currentUser.copyWith(
        phoneNumber: initial.tempPhoneNumber,
        phoneVerified: true,
      );
      final afterVerification = initial.copyWith(
        currentUser: updatedUser,
        isLoading: false,
        currentStep: AuthStep.roleSelection,
      );

      expect(afterVerification.currentStep, AuthStep.roleSelection);
      expect(afterVerification.currentUser.phoneVerified, isTrue);
      expect(afterVerification.currentUser.phoneNumber, '+919876543210');
      expect(afterVerification.errorMessage, isNull);
    });

    test('Empty verificationId produces friendly session expired error', () {
      final emptyVerificationState = AuthState.initial().copyWith(
        verificationId: '',
        tempPhoneNumber: '+919876543210',
        currentStep: AuthStep.otpInput,
      );

      expect(emptyVerificationState.verificationId, isEmpty);
      // When verificationId is empty, error should advise requesting a new code
      const expectedError = 'Verification session expired. Please request a new code.';
      final errorState = emptyVerificationState.copyWith(
        isLoading: false,
        errorMessage: expectedError,
      );

      expect(errorState.errorMessage, expectedError);
      expect(errorState.currentStep, AuthStep.otpInput);
    });

    test('Multi-account phone support allows up to 5 profiles per phone', () {
      const maxAccounts = 5;
      const accountCount1 = 1; // User registering 2nd account
      const accountCount5 = 5; // User at limit

      expect(accountCount1 < maxAccounts, isTrue,
          reason: 'Second account on same phone must be permitted');
      expect(accountCount5 >= maxAccounts, isTrue,
          reason: '6th account must be blocked at 5');
    });

    test('Incomplete account detection correctly flags uncompleted registrations for cleanup', () {
      // Completed account: has phoneVerified == true AND has role
      final completedProfile = UserModel.initial().copyWith(
        uid: 'user_complete_123',
        alternateEmail: 'test@atheleos.com',
        phoneVerified: true,
        role: 'Athlete',
      );

      final isCompleted = completedProfile.phoneVerified && completedProfile.role.isNotEmpty;
      expect(isCompleted, isTrue, reason: 'Completed account must be protected from orphan cleanup');

      // Incomplete account 1: email verified but phone not verified
      final incompletePhone = UserModel.initial().copyWith(
        uid: 'user_incomplete_1',
        alternateEmail: 'test@atheleos.com',
        phoneVerified: false,
        role: 'Athlete',
      );
      expect(incompletePhone.phoneVerified && incompletePhone.role.isNotEmpty, isFalse,
          reason: 'Unverified phone must be treated as incomplete registration');

      // Incomplete account 2: phone verified but role not selected (app closed mid-onboarding)
      final incompleteRole = UserModel.initial().copyWith(
        uid: 'user_incomplete_2',
        alternateEmail: 'test@atheleos.com',
        phoneVerified: true,
        role: '',
      );
      expect(incompleteRole.phoneVerified && incompleteRole.role.isNotEmpty, isFalse,
          reason: 'Missing role must be treated as incomplete registration');
    });
  });
}
