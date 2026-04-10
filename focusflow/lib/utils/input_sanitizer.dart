/// Input sanitization utilities for secure data handling.
///
/// Prevents common injection vectors:
/// - HTML/script injection in task titles and descriptions
/// - Excessively long inputs that could cause performance issues
/// - Control characters that could corrupt data
///
/// Applied at the service layer before data reaches SQLite or Firestore.
class InputSanitizer {
  /// Maximum lengths for each field type
  static const int maxTitleLength = 200;
  static const int maxDescriptionLength = 1000;
  static const int maxCategoryLength = 50;

  /// Sanitize a task title
  static String sanitizeTitle(String input) {
    return _sanitize(input, maxLength: maxTitleLength);
  }

  /// Sanitize a task description
  static String sanitizeDescription(String input) {
    return _sanitize(input, maxLength: maxDescriptionLength);
  }

  /// Sanitize a category name
  static String sanitizeCategory(String input) {
    return _sanitize(input, maxLength: maxCategoryLength);
  }

  /// Core sanitization logic
  static String _sanitize(String input, {required int maxLength}) {
    if (input.isEmpty) return input;

    String sanitized = input;

    // Strip HTML tags (prevents XSS if data ever rendered in a WebView)
    sanitized = sanitized.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove script-related patterns
    sanitized = sanitized.replaceAll(
      RegExp(r'javascript:', caseSensitive: false), ''
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'on\w+\s*=', caseSensitive: false), ''
    );

    // Remove control characters (keep newlines and tabs for descriptions)
    sanitized = sanitized.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ''
    );

    // Trim whitespace
    sanitized = sanitized.trim();

    // Enforce max length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Validate that an email looks reasonable (basic format check)
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Validate password meets minimum requirements
  static String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (password.length > 128) {
      return 'Password is too long';
    }
    return null; // null = valid
  }
}
