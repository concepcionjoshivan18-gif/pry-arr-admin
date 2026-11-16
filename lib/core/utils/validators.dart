class Validators {
  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\s'\-]+$");
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
  );
  static final RegExp _addressChars = RegExp(r"^[a-zA-Z0-9À-ÖØ-öø-ÿ ,\.\-\#]+$");

  static const List<String> _allowedDomainSuffixes = [
    '.com.ph',
    '.net.ph',
    '.org.ph',
    '.edu.ph',
    '.gov.ph',
    '.mil.ph',
    '.i.ph',
    '.ph',
    '.com',
    '.net',
    '.org',
    '.edu',
    '.gov',
    '.mil',
  ];

  // Check for 4 consecutive identical characters (e.g., "aaaa" or "1111")
  static bool hasConsecutiveRepeating(String value) {
    for (int i = 0; i < value.length - 3; i++) {
      if (value[i] == value[i+1] && value[i] == value[i+2] && value[i] == value[i+3]) {
        return true;
      }
    }
    return false;
  }

  // Check if any single digit appears more than maxAllowed times
  static bool hasTooManySameDigits(String value, {int maxAllowed = 4}) {
    final counts = <String, int>{};
    for (int i = 0; i < value.length; i++) {
      final ch = value[i];
      counts[ch] = (counts[ch] ?? 0) + 1;
      if (counts[ch]! > maxAllowed) {
        return true;
      }
    }
    return false;
  }

  static String? validateFirstName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'First name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > 50 || !_nameRegex.hasMatch(trimmed)) {
      return 'Enter a valid first name';
    }
    if (hasConsecutiveRepeating(trimmed)) {
      return 'Too many repeating characters';
    }
    if (trimmed.contains('  ')) {
      return 'Double spaces not allowed';
    }
    return null;
  }

  static String? validateMiddleName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final trimmed = value.trim();
    if (trimmed.length > 50 || !_nameRegex.hasMatch(trimmed)) {
      return 'Enter a valid middle name';
    }
    if (hasConsecutiveRepeating(trimmed)) {
      return 'Too many repeating characters';
    }
    if (trimmed.contains('  ')) {
      return 'Double spaces not allowed';
    }
    return null;
  }

  static String? validateLastName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Last name is required';
    }
    final trimmed = value.trim();
    if (trimmed.length > 50 || !_nameRegex.hasMatch(trimmed)) {
      return 'Enter a valid last name';
    }
    if (hasConsecutiveRepeating(trimmed)) {
      return 'Too many repeating characters';
    }
    if (trimmed.contains('  ')) {
      return 'Double spaces not allowed';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a valid email address';
    }
    final trimmed = value.trim();
    if (trimmed.length > 100 || !_emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }

    final parts = trimmed.split('@');
    if (parts.length != 2) return 'Enter a valid email address';
    final domain = parts[1].toLowerCase();

    final isAllowedDomain = _allowedDomainSuffixes.any((suffix) => domain.endsWith(suffix));
    if (!isAllowedDomain) {
      return 'Invalid domain (e.g. .com, .ph, .com.ph, .edu.ph, etc.)';
    }

    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter contact number';
    }
    final trimmed = value.trim();
    
    // Exactly 11 digits and starts with 09
    if (trimmed.length != 11 || !RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
      return 'Must be 11 digits starting with 09';
    }
    if (hasConsecutiveRepeating(trimmed) || hasTooManySameDigits(trimmed, maxAllowed: 4)) {
      return 'Cannot have more than 4 of the same digit';
    }
    return null;
  }

  static String? validateEmergencyContact(String? value, {bool isRequired = true, String? ownPhone}) {
    if (value == null || value.trim().isEmpty) {
      if (isRequired) return 'Emergency contact is required';
      return null;
    }
    final trimmed = value.trim();

    if (ownPhone != null && ownPhone.trim().isNotEmpty && trimmed == ownPhone.trim()) {
      return 'Must be different from your own number';
    }

    // Exactly 11 digits and starts with 09
    if (trimmed.length != 11 || !RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
      return 'Must be 11 digits starting with 09';
    }
    if (hasConsecutiveRepeating(trimmed) || hasTooManySameDigits(trimmed, maxAllowed: 4)) {
      return 'Cannot have more than 4 of the same digit';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password must be at least 8 characters';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    bool hasUppercase = value.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = value.contains(RegExp(r'[a-z]'));
    bool hasDigits = value.contains(RegExp(r'[0-9]'));

    if (!hasUppercase || !hasLowercase || !hasDigits) {
      return 'Include uppercase, lowercase, and number';
    }
    return null;
  }

  static String? validateConfirmPassword(String? v, String? password) {
    if ((v ?? '').isEmpty) return 'Please confirm your password';
    if (v != password) return 'Passwords do not match';
    return null;
  }

  static String? validateBusinessName(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Business name is required';
    if (s.length < 2) return 'Business name must be at least 2 characters';
    if (s.length > 100) return 'Business name must be 100 characters or less';
    if (!RegExp(r'[A-Za-z]').hasMatch(s)) {
      return 'Business name contains invalid characters';
    }
    return null;
  }

  static double getPasswordStrength(String value) {
    if (value.isEmpty) return 0.0;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (value.contains(RegExp(r'[A-Z]'))) score++;
    if (value.contains(RegExp(r'[a-z]'))) score++;
    if (value.contains(RegExp(r'[0-9]'))) score++;
    if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    return (score / 6).clamp(0.0, 1.0);
  }

  static String getPasswordStrengthLabel(double strength) {
    if (strength <= 0.34) return 'Weak';
    if (strength <= 0.67) return 'Medium';
    return 'Strong';
  }

  static String? validateAddress(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Home address is required';
    if (s.length < 10) return 'Enter your complete address (house no., street, barangay, city)';
    if (s.length > 200) return 'Address is too long (max 200 characters)';
    if (!_addressChars.hasMatch(s)) return 'Address contains invalid characters';
    if (!RegExp(r'[A-Za-z]{3,}').hasMatch(s)) return 'Enter a valid address';
    if (s.split(RegExp(r'\s+')).length < 3) return 'Include your street, barangay and city';
    return null;
  }

  static String capitalizeWords(String text) {
    return formatCapitalized(text);
  }

  static String? validateBirthday(DateTime? birthday) {
    if (birthday == null) return 'Birthday is required';
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    if (age < 10) {
      return 'User must be at least 10 years old';
    }
    if (age > 50) {
      return 'User must be 50 years old or younger';
    }
    return null;
  }
}

String formatCapitalized(String text) {
  if (text.isEmpty) return text;
  return text.trim().split(RegExp(r'\s+')).map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
