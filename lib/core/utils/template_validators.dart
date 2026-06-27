/// Pure validator functions for WhatsApp template fields.
///
/// These are extracted from the inline FormField validators in
/// CreateTemplatePage so they can be unit/property tested in isolation.
class TemplateValidators {
  TemplateValidators._();

  // -------------------------------------------------------------------------
  // Requirement 11.1 — Template name
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid template name (lowercase letters,
  /// digits, underscores only; max 512 characters). Returns an error string
  /// otherwise.
  static String? validateTemplateName(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length > 512) return 'Template name must not exceed 512 characters';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
      return 'Only lowercase letters, numbers, and underscores are allowed';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.2 — Body text (MARKETING / UTILITY)
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid body text (max 1024 chars).
  static String? validateBodyText(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length > 1024) return 'Body text must not exceed 1024 characters';
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.3 — Header text
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid header text (max 60 chars, no emoji,
  /// no asterisks). Returns an error string otherwise.
  static String? validateHeaderText(String? value) {
    if (value == null || value.isEmpty) return null; // header is optional
    if (value.length > 60) return 'Header text must not exceed 60 characters';
    if (value.contains('*')) return 'Header text must not contain asterisks';
    if (_containsEmoji(value)) return 'Header text must not contain emoji';
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.4 — Footer text
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid footer text (max 60 chars).
  static String? validateFooterText(String? value) {
    if (value == null || value.isEmpty) return null; // footer is optional
    if (value.length > 60) return 'Footer text must not exceed 60 characters';
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.5 — Button label
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid button label (max 25 chars).
  static String? validateButtonLabel(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length > 25) return 'Button label must not exceed 25 characters';
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.6 — URL button URL
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid URL. Returns an error string otherwise.
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || (!uri.scheme.startsWith('http'))) {
      return 'Enter a valid URL (must start with http:// or https://)';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.7 — Phone number button
  // -------------------------------------------------------------------------

  /// Returns null if [value] is a valid phone number (must start with '+').
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (!value.startsWith('+')) {
      return 'Phone number must include a country code (start with +)';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.11 — Total button count
  // -------------------------------------------------------------------------

  /// Returns null if [count] ≤ 10. Returns an error string otherwise.
  static String? validateButtonCount(int count) {
    if (count > 10) return 'You cannot add more than 10 buttons';
    return null;
  }

  // -------------------------------------------------------------------------
  // Requirement 11.12 — Quick reply / CTA mix
  // -------------------------------------------------------------------------

  /// Returns null if the button list is valid (≤ 3 QUICK_REPLY when mixed
  /// with CTA buttons). Returns an error string otherwise.
  ///
  /// [buttons] is a list of maps with at least a 'type' key.
  static String? validateButtonMix(List<Map<String, dynamic>> buttons) {
    final quickReplies =
        buttons.where((b) => b['type'] == 'QUICK_REPLY').length;
    final ctas = buttons
        .where((b) => b['type'] == 'PHONE_NUMBER' || b['type'] == 'URL')
        .length;
    if (quickReplies > 0 && ctas > 0 && quickReplies > 3) {
      return 'You cannot mix more than 3 quick reply buttons with call-to-action buttons';
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  /// Returns true if [text] contains any Unicode emoji character.
  static bool _containsEmoji(String text) {
    // Matches common emoji ranges (Emoticons, Misc Symbols, Supplemental
    // Symbols, Dingbats, etc.)
    return RegExp(
      r'[\u{1F600}-\u{1F64F}'
      r'\u{1F300}-\u{1F5FF}'
      r'\u{1F680}-\u{1F6FF}'
      r'\u{1F700}-\u{1F77F}'
      r'\u{1F780}-\u{1F7FF}'
      r'\u{1F800}-\u{1F8FF}'
      r'\u{1F900}-\u{1F9FF}'
      r'\u{1FA00}-\u{1FA6F}'
      r'\u{1FA70}-\u{1FAFF}'
      r'\u{2600}-\u{26FF}'
      r'\u{2700}-\u{27BF}]',
      unicode: true,
    ).hasMatch(text);
  }
}
