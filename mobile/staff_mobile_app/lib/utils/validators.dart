class PortalValidators {
  static const int maxNameLength = 25;

  static final RegExp emojiRegex = RegExp(
    r'[\u{1F1E6}-\u{1F1FF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
    unicode: true,
  );

  static final RegExp _namePartRegex = RegExp(
    r"^[A-Za-z]+(?:[ '-][A-Za-z]+)*$",
  );
  static final RegExp _phMobileSubscriberRegex = RegExp(r'^9\d{9}$');
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _nameLetterRegex = RegExp(r'[A-Za-z]');
  static final RegExp _nameSeparatorRegex = RegExp(r"[ '\-]");

  static bool containsEmoji(String value) => emojiRegex.hasMatch(value);

  static String normalizeWhitespace(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String sanitizeMobileInput(String value) {
    final trimmed = value.trim();
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.isEmpty) {
      return trimmed.startsWith('+') ? '+' : '';
    }

    if (trimmed.startsWith('+')) {
      final limited = digitsOnly.length > 12
          ? digitsOnly.substring(0, 12)
          : digitsOnly;
      return '+$limited';
    }

    if (digitsOnly.length > 11) {
      return digitsOnly.substring(0, 11);
    }

    return digitsOnly;
  }

  static String normalizeMobileInput(String value) {
    var digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.startsWith('63') && digitsOnly.length <= 12) {
      digitsOnly = digitsOnly.substring(2);
    } else if (digitsOnly.startsWith('0') && digitsOnly.length <= 11) {
      digitsOnly = digitsOnly.substring(1);
    }

    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(0, 10);
    }

    return digitsOnly;
  }

  static String buildSubmissionMobile(String value) {
    final normalized = normalizeMobileInput(value);
    if (normalized.isEmpty) {
      return '';
    }

    return '+63$normalized';
  }

  static String titleCaseName(String value) {
    final normalized = normalizeWhitespace(value);
    if (normalized.isEmpty) {
      return '';
    }

    final lowerCased = normalized.toLowerCase();
    final buffer = StringBuffer();
    var capitalizeNext = true;

    for (final rune in lowerCased.runes) {
      final character = String.fromCharCode(rune);

      if (capitalizeNext && _nameLetterRegex.hasMatch(character)) {
        buffer.write(character.toUpperCase());
      } else {
        buffer.write(character);
      }

      capitalizeNext = _nameSeparatorRegex.hasMatch(character);
    }

    return buffer.toString();
  }

  static String? validateNamePart(String label, String value) {
    final normalized = normalizeWhitespace(value);

    if (normalized.isEmpty) {
      return '$label is required.';
    }

    if (containsEmoji(normalized)) {
      return 'Emoji characters are not allowed.';
    }

    if (normalized.length > maxNameLength) {
      return '$label must be 25 characters or fewer.';
    }

    if (!_namePartRegex.hasMatch(normalized)) {
      return '$label can only contain letters, spaces, hyphens, and apostrophes.';
    }

    return null;
  }

  static String? validateFullName(String value) {
    final normalized = normalizeWhitespace(value);

    if (normalized.isEmpty) {
      return 'Full name is required.';
    }

    if (containsEmoji(normalized)) {
      return 'Emoji characters are not allowed.';
    }

    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return 'Enter your full name with first and last name.';
    }

    final firstName = parts.first;
    final lastName = parts.skip(1).join(' ');

    return validateNamePart('First name', firstName) ??
        validateNamePart('Last name', lastName);
  }

  static String? validateEmail(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return 'Email address is required.';
    }

    if (containsEmoji(normalized)) {
      return 'Emoji characters are not allowed.';
    }

    if (!_emailRegex.hasMatch(normalized)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  static String? validatePhilippineMobile(
    String value, {
    bool required = false,
  }) {
    final normalized = normalizeMobileInput(value);

    if (normalized.isEmpty) {
      return required ? 'Mobile number is required.' : null;
    }

    if (!_phMobileSubscriberRegex.hasMatch(normalized)) {
      return 'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.';
    }

    return null;
  }
}
