/// Validates password strength across registration, reset, and account settings.
/// Requires:
/// - At least 8 characters
/// - At least 1 uppercase letter (A-Z)
/// - At least 1 lowercase letter (a-z)
/// - At least 1 numeric digit (0-9)
/// - At least 1 special character (!@#$%^&*...)
class PasswordValidator {
  static const int minLength = 8;

  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < minLength) {
      return 'Password must be at least 8 characters';
    }
    if (!hasUppercase(value)) {
      return 'Password must contain at least one uppercase letter (A-Z)';
    }
    if (!hasLowercase(value)) {
      return 'Password must contain at least one lowercase letter (a-z)';
    }
    if (!hasNumber(value)) {
      return 'Password must contain at least one number (0-9)';
    }
    if (!hasSpecialChar(value)) {
      return 'Password must contain at least one special character (!@#\$%...)';
    }
    return null;
  }

  static bool hasMinLength(String val) => val.length >= minLength;
  static bool hasUppercase(String val) => RegExp(r'[A-Z]').hasMatch(val);
  static bool hasLowercase(String val) => RegExp(r'[a-z]').hasMatch(val);
  static bool hasNumber(String val) => RegExp(r'[0-9]').hasMatch(val);
  static bool hasSpecialChar(String val) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_+\-=\[\]\\\/~`]').hasMatch(val);

  static bool isStrong(String val) => validate(val) == null;
}
