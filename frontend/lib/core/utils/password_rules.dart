class PasswordRules {
  static bool hasMinMaxChars(String password) => password.length >= 8 && password.length <= 32;
  static bool hasUppercase(String password) => RegExp(r'[A-Z]').hasMatch(password);
  static bool hasLowercase(String password) => RegExp(r'[a-z]').hasMatch(password);
  static bool hasNumber(String password) => RegExp(r'[0-9]').hasMatch(password);
  static bool hasSpecialChar(String password) => RegExp(r'[^a-zA-Z0-9]').hasMatch(password);

  static bool isValid(String password) {
    return hasMinMaxChars(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasNumber(password) &&
        hasSpecialChar(password);
  }
}
