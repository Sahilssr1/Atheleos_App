import 'package:atheleos/core/utils/user_facing_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserFacingError', () {
    test('converts null and empty to fallback', () {
      expect(
        UserFacingError.message(null),
        'Something went wrong. Please try again.',
      );
      expect(
        UserFacingError.message(''),
        'Something went wrong. Please try again.',
      );
      expect(
        UserFacingError.message('   ', fallback: 'Custom fallback'),
        'Custom fallback',
      );
    });

    test('translates network and timeout errors to layman connectivity message', () {
      expect(
        UserFacingError.message('[firebase_auth/network-request-failed] A network error has occurred.'),
        'Please check your internet connection and try again.',
      );
      expect(
        UserFacingError.message('SocketException: Failed host lookup: firestore.googleapis.com'),
        'Please check your internet connection and try again.',
      );
      expect(
        UserFacingError.message('ClientException: Connection reset by peer'),
        'Please check your internet connection and try again.',
      );
      expect(
        UserFacingError.message('TimeoutException after 0:00:10.000000: Task timed out'),
        'The request took too long. Please check your connection and try again.',
      );
    });

    test('translates email-already-in-use to friendly login suggestion', () {
      expect(
        UserFacingError.message('[firebase_auth/email-already-in-use] The email address is already in use by another account.'),
        'An account already exists with this email. Try logging in with this email instead.',
      );
      expect(
        UserFacingError.message('An account already exists with this email.'),
        'An account already exists with this email. Try logging in with this email instead.',
      );
    });

    test('translates phone conflict and account limit to friendly login suggestion', () {
      expect(
        UserFacingError.message('[firebase_auth/credential-already-in-use] This phone number is already registered.'),
        'This phone number is already registered to an account. Try logging in using your phone number.',
      );
      expect(
        UserFacingError.message('This phone number has reached the maximum limit of 5 accounts.'),
        'This phone number is already registered to an account. Try logging in using your phone number.',
      );
    });

    test('translates user-not-found and invalid credentials to friendly messages', () {
      expect(
        UserFacingError.message('[firebase_auth/user-not-found] There is no user record corresponding to this identifier.'),
        'No account found with these details. Please check and try again.',
      );
      expect(
        UserFacingError.message('[firebase_auth/invalid-credential] The credential is invalid or has expired.'),
        'Incorrect password or email. Please check your details and try again.',
      );
      expect(
        UserFacingError.message('[firebase_auth/wrong-password] Invalid password entered.'),
        'Incorrect password or email. Please check your details and try again.',
      );
    });

    test('translates Firestore permission-denied without exposing backend internals', () {
      final message = UserFacingError.message(
        '[cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.',
      );
      expect(message, 'Unable to access this information right now. Please try again.');
      expect(message.contains('cloud_firestore'), isFalse);
      expect(message.contains('permission-denied'), isFalse);
    });

    test('strips technical prefixes from clean readable exceptions', () {
      expect(
        UserFacingError.message('Exception: Please choose a different username.'),
        'Please choose a different username.',
      );
      expect(
        UserFacingError.message('Error: Invalid character in name'),
        'Invalid character in name',
      );
    });

    test('filters out technical stack traces and internal errors to fallback', () {
      expect(
        UserFacingError.message('TypeError: Null check operator used on a null value'),
        'Something went wrong. Please try again.',
      );
      expect(
        UserFacingError.message('NoSuchMethodError: The method "data" was called on null.'),
        'Something went wrong. Please try again.',
      );
      expect(
        UserFacingError.message('PlatformException(cloud_firestore, permission denied, null, null)'),
        'Unable to access this information right now. Please try again.',
      );
    });
  });
}
