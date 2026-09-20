/// Utility for sanitizing and converting backend errors, Firebase exceptions,
/// and network failures into clear, conversational layman language.
class UserFacingError {
  /// Converts any raw error, exception, or error string into a user-friendly sentence.
  static String message(dynamic error, {String fallback = 'Something went wrong. Please try again.'}) {
    if (error == null) return fallback;

    final raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    final lower = raw.toLowerCase();

    // 1. Network & Connectivity
    if (lower.contains('network-request-failed') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network error') ||
        lower.contains('no internet') ||
        lower.contains('connection refused') ||
        lower.contains('connection closed') ||
        lower.contains('connection reset')) {
      return 'Please check your internet connection and try again.';
    }

    if (lower.contains('timeout') || lower.contains('timed out') || lower.contains('deadline-exceeded')) {
      return 'The request took too long. Please check your connection and try again.';
    }

    // 2. Firebase Auth: Credentials & Conflict
    if (lower.contains('email-already-in-use') ||
        lower.contains('email address is already in use') ||
        lower.contains('email already exists') ||
        lower.contains('email is already registered') ||
        lower.contains('account already exists with this email')) {
      return 'An account already exists with this email. Try logging in with this email instead.';
    }

    if (lower.contains('credential-already-in-use') ||
        lower.contains('phone number is already') ||
        lower.contains('phone number already exists') ||
        lower.contains('phone number is already registered') ||
        lower.contains('maximum limit of 5 accounts')) {
      return 'This phone number is already registered to an account. Try logging in using your phone number.';
    }

    if (lower.contains('user-not-found') ||
        lower.contains('no registered atheleos account') ||
        lower.contains('no user found')) {
      return 'No account found with these details. Please check and try again.';
    }

    if (lower.contains('wrong-password') ||
        lower.contains('invalid_login_credentials') ||
        lower.contains('invalid password') ||
        lower.contains('invalid-credential')) {
      return 'Incorrect password or email. Please check your details and try again.';
    }

    if (lower.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a few moments and try again.';
    }

    if (lower.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }

    if (lower.contains('requires-recent-login')) {
      return 'For your security, please sign in again before continuing.';
    }

    // 3. Verification & Codes
    if (lower.contains('invalid-verification-code') || lower.contains('incorrect email verification code')) {
      return 'Invalid verification code. Please check the code and try again.';
    }

    if (lower.contains('session-expired') || lower.contains('code has expired')) {
      return 'The verification code has expired. Please request a new one.';
    }

    // 4. Firestore & Permissions
    if (lower.contains('permission-denied') ||
        lower.contains('permission denied') ||
        lower.contains('caller does not have permission')) {
      return 'Unable to access this information right now. Please try again.';
    }

    if (lower.contains('not-found') || lower.contains('profile not found') || lower.contains('document does not exist')) {
      return 'This profile or content could not be found.';
    }

    if (lower.contains('deleted') || lower.contains('account has been deleted')) {
      return 'This account has been deleted and cannot be accessed.';
    }

    if (lower.contains('username') && (lower.contains('taken') || lower.contains('already exists'))) {
      return 'This username is already taken. Please choose another.';
    }

    // 5. Clean up readable custom exceptions
    String cleaned = raw
        .replaceAll(RegExp(r'^Exception:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'^Error:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();

    // If cleaned string contains technical symbols/stack trace words, use fallback
    final cleanedLower = cleaned.toLowerCase();
    if (cleanedLower.contains('cloud_firestore') ||
        cleanedLower.contains('firebase_auth') ||
        cleanedLower.contains('platformexception') ||
        cleanedLower.contains('nosuchmethoderror') ||
        cleanedLower.contains('null check') ||
        cleanedLower.contains('nullcheck') ||
        cleanedLower.contains('typeerror') ||
        cleanedLower.contains('formatexception') ||
        cleanedLower.contains('assertion') ||
        cleanedLower.contains('stack trace') ||
        cleanedLower.contains('http/')) {
      return fallback;
    }

    if (cleaned.isNotEmpty && cleaned.length <= 120) {
      return cleaned;
    }

    return fallback;
  }
}
