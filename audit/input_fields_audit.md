# Input Fields Audit Report

## 1. Input Fields Table

| Screen Name + File Path + Line Number | Label / Hint Text | Controller / Variable Name | Keyboard Type | Obscure Text | Input Formatters | Max Length | Text Input Action | Current Validator | Used For |
|---|---|---|---|---|---|---|---|---|---|
| LoginScreen (`lib/app/screens/login_screen.dart`, L288-L297) | Email Address | `_emailController` | emailAddress | false | NONE | NONE | next | `(v) => Validators.validateEmail(v)` | FirebaseAuth email |
| LoginScreen (`lib/app/screens/login_screen.dart`, L300-L309) | Password | `_passwordController` | text | true | NONE | NONE | done | `(v) => v == null || v.isEmpty ? 'Password is required' : null` | FirebaseAuth password |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L480) | First Name | `first` | name | false | `[FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))]` | 50 | next | `(v) => Validators.validateFirstName(v)` | Firestore `firstName` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L525) | Last Name | `last` | name | false | `[FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))]` | 50 | next | `(v) => Validators.validateLastName(v)` | Firestore `lastName` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L550) | Middle Name (Optional) | `middle` | name | false | `[FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))]` | 50 | next | `(v) => Validators.validateMiddleName(v)` | Firestore `middleName` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L585) | Email Address | `email` | emailAddress | false | `[FilteringTextInputFormatter.deny(RegExp(r'\s'))]` | 100 | next | `(v) => Validators.validateEmail(v)` | FirebaseAuth email & Firestore `email` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L615) | Mobile Number | `phone` | phone | false | `[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]` | 11 | next | `(v) => Validators.validatePhone(v)` | Firestore `phone` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L645) | Emergency Contact Number | `emergency` | phone | false | `[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]` | 11 | next | `(v) => Validators.validateEmergencyContact(v, ownPhone: phone.text)` | Firestore `emergencyContact` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L675) | Birthday (DD/MM/YYYY) | `birthdayController` | datetime | false | `birthdayFmt` | 10 | next | `(v) => Validators.validateBirthday(parsedBirthday)` | Firestore `birthday` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L710) | Age (Auto-computed) | `ageController` | number | false | NONE | NONE | next | NONE | Read-only computed field |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L740) | Complete Street Address / Delivery Address | `address` | text | false | NONE | 200 | next | `(v) => Validators.validateAddress(v)` | Firestore `address` & `shippingAddresses` |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L780) | Password | `pw` | text | `!showPw` | `[FilteringTextInputFormatter.deny(RegExp(r'\s'))]` | 64 | next | `(v) => Validators.validatePassword(v)` | FirebaseAuth password |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L815) | Confirm Password | `confirm` | text | `!showConfirm` | `[FilteringTextInputFormatter.deny(RegExp(r'\s'))]` | 64 | done | `(v) => Validators.validateConfirmPassword(v, pw.text)` | Password confirmation |
| RegisterScreen (`lib/app/screens/register_screen.dart`, L860) | Business Name (Contractor / Shopper) | `businessName` | text | false | NONE | 100 | done | `(v) => business ? Validators.validateBusinessName(v) : null` | Firestore `businessName` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L234) | First Name | `_firstNameController` | name | false | `[FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))]` | NONE | next | Manual validation in `_saveProfile()` | Firestore `firstName` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L250) | Last Name | `_lastNameController` | name | false | `[FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))]` | NONE | next | Manual validation in `_saveProfile()` | Firestore `lastName` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L266) | Mobile Number | `_phoneController` | phone | false | `[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]` | 11 | next | Manual validation in `_saveProfile()` | Firestore `phone` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L281) | Email Address | `_emailController` | emailAddress | false | NONE | NONE | next | Manual validation in `_saveProfile()` | Firestore `email` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L297) | Delivery Address | `_addressController` | text | false | NONE | 200 | next | Manual validation in `_saveProfile()` | Firestore `address` |
| EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`, L314) | Emergency Contact Number | `_emergencyController` | phone | false | `[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]` | 11 | done | Manual validation in `_saveProfile()` | Firestore `emergencyContact` |
| EditProfileScreen (Password Dialog, L120) | New Password | `pwCtrl` | text | true | NONE | NONE | next | `(v) => Validators.validatePassword(v)` | FirebaseAuth updatePassword |
| EditProfileScreen (Password Dialog, L168) | Confirm Password | `confirmCtrl` | text | true | NONE | NONE | done | `(v) => v != pwCtrl.text ? 'Passwords do not match' : null` | Password confirmation |
| AccountsScreen (Create/Edit Employee, L758) | First Name | `_firstNameCtrl` | name | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null` | Firestore `firstName` |
| AccountsScreen (Create/Edit Employee, L769) | Last Name | `_lastNameCtrl` | name | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null` | Firestore `lastName` |
| AccountsScreen (Create/Edit Employee, L790) | Email Address | `_emailCtrl` | emailAddress | false | NONE | NONE | next | `(v) => Validators.validateEmail(v)` | FirebaseAuth & Firestore `email` |
| AccountsScreen (Create/Edit Employee, L805) | Mobile Number | `_phoneCtrl` | phone | false | NONE | NONE | next | `(v) => Validators.validatePhone(v)` | Firestore `phone` |
| AccountsScreen (Create/Edit Employee, L817) | Password | `_passCtrl` | text | true | NONE | NONE | next | `(v) => (!isEdit && (v == null || v.length < 6)) ? 'Password must be at least 6 characters' : null` | FirebaseAuth password |
| AccountsScreen (Create/Edit Employee, L839) | Home Address | `_addressCtrl` | text | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null` | Firestore `address` |
| AccountsScreen (Create/Edit Employee, L867) | Emergency Contact | `_emergencyCtrl` | phone | false | NONE | NONE | next | `(v) => Validators.validateEmergencyContact(v, isRequired: false)` | Firestore `emergencyContact` |
| AccountsScreen (Create/Edit Employee, L894) | Basic Salary (₱) | `_salaryCtrl` | number | false | NONE | NONE | next | `(v) => (double.tryParse(v ?? '') == null) ? 'Enter valid salary' : null` | Firestore `basicSalary` |
| AccountsScreen (Create/Edit Employee, L915) | RFID UID (e.g. 992E91E6) | `_rfidUidCtrl` | text | false | NONE | NONE | done | NONE | Firestore `rfidUid` & `cards` collection doc ID |
| AdminProfileScreen (`lib/admin/screens/admin_profile_screen.dart`, L288) | First Name | `_fNameCtrl` | name | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'First name is required' : null` | Firestore `firstName` |
| AdminProfileScreen (`lib/admin/screens/admin_profile_screen.dart`, L299) | Last Name | `_lNameCtrl` | name | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'Last name is required' : null` | Firestore `lastName` |
| AdminProfileScreen (`lib/admin/screens/admin_profile_screen.dart`, L311) | Mobile Number | `_phoneCtrl` | phone | false | NONE | NONE | next | `(v) => Validators.validatePhone(v)` | Firestore `phone` |
| AdminProfileScreen (`lib/admin/screens/admin_profile_screen.dart`, L323) | Home Address | `_addressCtrl` | text | false | NONE | NONE | next | `(v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null` | Firestore `address` |
| AdminProfileScreen (`lib/admin/screens/admin_profile_screen.dart`, L347) | Emergency Contact | `_emergencyCtrl` | phone | false | NONE | NONE | done | `(v) => Validators.validateEmergencyContact(v, isRequired: false)` | Firestore `emergencyContact` |

---

## 2. SUBMIT HANDLERS

### LoginScreen Submit Handler (`lib/app/screens/login_screen.dart`)
```dart
  void _submit() async {
    if (_lockoutSeconds > 0) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    try {
      await authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (mounted) {
        _failedLoginAttempts = 0;
        _errorMessage = null;
      }
    } catch (e) {
      if (!mounted) return;

      final raw = e.toString().replaceFirst('Exception: ', '');
      final isShiftBlock = raw.contains('time in with your RFID');

      setState(() {
        _errorMessage = _friendlyAuthError(e);
        if (!isShiftBlock) _failedLoginAttempts++;
      });

      _shakeController?.forward(from: 0);

      if (!isShiftBlock && _failedLoginAttempts >= 5) {
        _startLockoutTimer();
      }
    }
  }
```

### RegisterScreen Submit Handler (`lib/app/screens/register_screen.dart`)
```dart
  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => submitted = true);
    await _checkEmail();
    if (!mounted) return;

    final bad = order.where((id) => errorFor(id) != null).toList();
    final bdayErr = Validators.validateBirthday(parsedBirthday);
    if (bdayErr != null) {
      showTopNotification(context, bdayErr, isError: true);
      if (bad.isNotEmpty) {
        final ctx = keys[bad.first]!.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 300), alignment: 0.15, curve: Curves.easeOut);
        }
      }
      return;
    }

    if (bad.isNotEmpty) {
      final ctx = keys[bad.first]!.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), alignment: 0.15, curve: Curves.easeOut);
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Please fix ${bad.length} highlighted ${bad.length == 1 ? 'field' : 'fields'}'),
          backgroundColor: Pal.of(context).danger,
        ));
      return;
    }

    // Trigger OTP Verification Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => OtpVerificationScreen(
        recipient: email.text.trim(),
        onVerified: () async {
          Navigator.pop(ctx);
          await _executeRegistration();
        },
      ),
    );
  }

  Future<void> _executeRegistration() async {
    setState(() => loading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      await authService.registerCustomerUser(
        email: email.text.trim(),
        password: pw.text,
        firstName: formatCapitalized(first.text),
        middleName: formatCapitalized(middle.text),
        lastName: formatCapitalized(last.text),
        phone: phone.text.trim(),
        businessName: business ? formatCapitalized(businessName.text) : null,
        marketingOptIn: true,
        birthday: parsedBirthday,
        address: address.text.trim(),
        gender: gender,
        emergencyContact: emergency.text.trim(),
      );

      // Force sign out so user logs in through the login page first
      await authService.signOut();

      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please sign in to enter the app.'),
          backgroundColor: Color(0xFF1B8A4B),
          duration: Duration(seconds: 4),
        ),
      );

      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration error: $e'), backgroundColor: Colors.red),
      );
    }
  }
```

### EditProfileScreen Save Profile Handler (`lib/app/screens/edit_profile_screen.dart`)
```dart
  void _saveProfile() async {
    final firstNameErr = Validators.validateFirstName(_firstNameController.text);
    final lastNameErr = Validators.validateLastName(_lastNameController.text);
    final emailErr = Validators.validateEmail(_emailController.text);
    final phoneErr = Validators.validatePhone(_phoneController.text);
    final addressErr = Validators.validateAddress(_addressController.text);
    final emergencyErr = Validators.validateEmergencyContact(_emergencyController.text, ownPhone: _phoneController.text);

    if (firstNameErr != null || lastNameErr != null || emailErr != null || phoneErr != null || addressErr != null || emergencyErr != null) {
      showTopNotification(
        context,
        firstNameErr ?? lastNameErr ?? emailErr ?? phoneErr ?? addressErr ?? emergencyErr ?? 'Please check inputs',
        isError: true,
      );
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final updatedData = {
        'firstName': Validators.capitalizeWords(_firstNameController.text),
        'lastName': Validators.capitalizeWords(_lastNameController.text),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'emergencyContact': _emergencyController.text.trim(),
      };
      await firestoreService.updateUserProfile(user.uid, updatedData);
      authService.updateLocalUser(updatedData);
      if (mounted) {
        showTopNotification(context, 'Profile updated successfully!', isSuccess: true);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
```

### AccountsScreen Save Employee Handler (`lib/admin/screens/accounts_screen.dart`)
```dart
                                  if (!_formKey.currentState!.validate()) return;
                                  
                                  final data = {
                                    'firstName': formatCapitalized(_firstNameCtrl.text),
                                    'lastName': formatCapitalized(_lastNameCtrl.text),
                                    'email': _emailCtrl.text.trim(),
                                    'phone': _phoneCtrl.text.trim(),
                                    'address': _addressCtrl.text.trim(),
                                    'gender': _gender,
                                    'emergencyContact': _emergencyCtrl.text.trim(),
                                  };

                                  bool rfidChanged = false;
                                  String savedRfid = '';

                                  if (isEdit) {
                                    if (widget.user!.role == 'staff' || widget.user!.role == 'driver' || widget.user!.isDriver) {
                                      data['basicSalary'] = double.tryParse(_salaryCtrl.text) ?? 0.0;
                                      data['assignedRole'] = _assignedRole;
                                      final newRfid = _rfidUidCtrl.text.trim().toUpperCase();
                                      data['rfidUid'] = newRfid;

                                      final cardsCol = FirebaseFirestore.instance.collection('cards');
                                      final owned = await cardsCol
                                          .where('staffId', isEqualTo: widget.user!.uid)
                                          .get();

                                      for (final d in owned.docs) {
                                        if (d.id.toUpperCase() != newRfid) {
                                          await d.reference.delete();
                                        }
                                      }

                                      final alreadyOwned =
                                      owned.docs.any((d) => d.id.toUpperCase() == newRfid);
                                      if (newRfid.isNotEmpty && !alreadyOwned) {
                                        await firestore.assignCard(newRfid, widget.user!.uid);
                                        rfidChanged = true;
                                        savedRfid = newRfid;
                                      }
                                    }
                                    await firestore.updateUserProfile(widget.user!.uid, data);
                                  } else {
                                    final rfid = _rfidUidCtrl.text.trim().toUpperCase();
                                    await authService.createStaffAccount(
                                      email: _emailCtrl.text.trim(),
                                      password: _passCtrl.text.trim(),
                                      firstName: formatCapitalized(_firstNameCtrl.text),
                                      lastName: formatCapitalized(_lastNameCtrl.text),
                                      assignedRole: _assignedRole,
                                      basicSalary: double.tryParse(_salaryCtrl.text) ?? 0.0,
                                      phone: _phoneCtrl.text.trim(),
                                      address: _addressCtrl.text.trim(),
                                      gender: _gender,
                                      emergencyContact: _emergencyCtrl.text.trim(),
                                      rfidUid: rfid,
                                    );
                                    if (rfid.isNotEmpty) {
                                      rfidChanged = true;
                                      savedRfid = rfid;
                                    }
                                  }

                                  if (rfidChanged) {
                                    _saved = true;
                                    _regSession ??= DateTime.now().millisecondsSinceEpoch.toString();
                                    _setRegistration('registered', uid: savedRfid);
                                  }

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    showTopSuccess(
                                      context,
                                      isEdit ? 'Account updated successfully!' : 'Staff account created successfully!',
                                    );
                                  }
```

---

## 3. SHARED VALIDATORS/HELPERS (`lib/core/utils/validators.dart`)
```dart
import 'package:flutter/services.dart';

class Validators {
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$",
  );

  static final RegExp _nameRegex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ .'\-]+$");

  static const List<String> _allowedDomainSuffixes = [
    '.com', '.ph', '.com.ph', '.net', '.org', '.edu', '.gov', '.edu.ph', '.net.ph', '.org.ph', '.mil.ph'
  ];

  static bool hasConsecutiveRepeating(String text) {
    if (text.length < 3) return false;
    for (int i = 0; i < text.length - 2; i++) {
      if (text[i] == text[i + 1] && text[i + 1] == text[i + 2]) {
        return true;
      }
    }
    return false;
  }

  static bool hasTooManySameDigits(String text, {int maxAllowed = 4}) {
    final counts = <String, int>{};
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      counts[char] = (counts[char] ?? 0) + 1;
      if (counts[char]! > maxAllowed) return true;
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
    if (v == null || v.trim().isEmpty) return 'Business name is required';
    final trimmed = v.trim();
    if (trimmed.length < 2) return 'Business name is too short';
    return null;
  }

  static String? validateAddress(String? v) {
    if (v == null || v.trim().isEmpty) return 'Delivery address is required';
    final trimmed = v.trim();
    if (trimmed.length < 5) return 'Please enter a complete delivery address';
    return null;
  }

  static String? validateBirthday(DateTime? birthday) {
    if (birthday == null) return 'Birthday is required';
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month || (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    if (age < 10 || age > 50) {
      return 'Age must be between 10 and 50 years old';
    }
    return null;
  }

  static double getPasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double score = 0.0;
    if (password.length >= 8) score += 0.4;
    if (password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]'))) score += 0.3;
    if (password.contains(RegExp(r'[0-9]'))) score += 0.3;
    return score.clamp(0.0, 1.0);
  }

  static String getPasswordStrengthLabel(double strength) {
    if (strength <= 0.34) return 'Weak';
    if (strength <= 0.67) return 'Medium';
    return 'Strong';
  }

  static String capitalizeWords(String input) {
    if (input.isEmpty) return '';
    return input.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
```

---

## 4. FIRESTORE FIELDS SAVED ON REGISTRATION

1. **Customer Registration (`RegisterScreen` -> `AuthService.registerCustomerUser`)**:
   - `uid` (REQUIRED - Firestore Document ID)
   - `email` (REQUIRED)
   - `firstName` (REQUIRED)
   - `middleName` (OPTIONAL)
   - `lastName` (REQUIRED)
   - `phone` (REQUIRED)
   - `role`: `'customer'` (REQUIRED)
   - `businessName` (OPTIONAL)
   - `marketingOptIn` (REQUIRED)
   - `createdAt` (REQUIRED)
   - `birthday` (REQUIRED)
   - `address` (REQUIRED)
   - `gender` (REQUIRED)
   - `emergencyContact` (REQUIRED)

2. **Staff/Driver Account Creation (`AccountsScreen` -> `AuthService.createStaffAccount`)**:
   - `uid` (REQUIRED - Firestore Document ID)
   - `email` (REQUIRED)
   - `firstName` (REQUIRED)
   - `lastName` (REQUIRED)
   - `role`: `'staff'` or `'driver'` (REQUIRED)
   - `assignedRole` (REQUIRED)
   - `basicSalary` (REQUIRED)
   - `phone` (OPTIONAL)
   - `address` (OPTIONAL)
   - `gender` (OPTIONAL)
   - `emergencyContact` (OPTIONAL)
   - `rfidUid` (OPTIONAL)
   - `onShift`: `false` (REQUIRED)
   - `createdAt` (REQUIRED)
   - `status`: `'Active'` (REQUIRED)

---

## 5. FORMS WITHOUT Form/validator
- **RegisterScreen (`lib/app/screens/register_screen.dart`)**: Uses manual validation checks (`errorFor(id)` in `order` list and `Validators.validateBirthday`) instead of standard Flutter `Form` and `FormField.validator`.
- **EditProfileScreen (`lib/app/screens/edit_profile_screen.dart`)**: Uses manual validation in `_saveProfile()` (`Validators.validateFirstName`, etc.) for profile text fields, and `Form` with `FormKey` only for the Change Password dialog.
- **LoginScreen (`lib/app/screens/login_screen.dart`)**: Uses `Form` and `_formKey.currentState!.validate()` with `TextFormField`.

---

## 6. FIELDS WITH NO VALIDATION AT ALL
- **RegisterScreen (`lib/app/screens/register_screen.dart`)**: `businessName` has no validation when business toggle is false; when true, `validateBusinessName` is called. `gender` uses a fixed dropdown selection ('Male', 'Female'), so no invalid input is possible.
- **AccountsScreen (`lib/admin/screens/accounts_screen.dart`)**: `_rfidUidCtrl` (RFID UID field) has no validation (`NONE`), allowing any text or empty value.

---

## 7. INCONSISTENCIES
- **Phone Number Validation**:
  - `RegisterScreen` / `EditProfileScreen` use `Validators.validatePhone` (requires exactly 11 digits starting with `09`).
  - `AccountsScreen` (Admin create employee) uses `Validators.validatePhone` as well. However, in some older/fallback code paths, phone numbers might not enforce 11 digits strictly if left optional.
- **Email Validation**:
  - `LoginScreen` uses `Validators.validateEmail`.
  - `RegisterScreen` uses `Validators.validateEmail`.
  - `EditProfileScreen` uses `Validators.validateEmail`.
  - `AccountsScreen` uses `Validators.validateEmail`.

---

## 8. CHECKLIST OF ALL FILES READ
1. `lib/app/screens/login_screen.dart`
2. `lib/app/screens/register_screen.dart`
3. `lib/app/screens/edit_profile_screen.dart`
4. `lib/admin/screens/accounts_screen.dart`
5. `lib/admin/screens/admin_profile_screen.dart`
6. `lib/core/utils/validators.dart`
7. `lib/core/services/auth_service.dart`
8. `pubspec.yaml`
9. `firestore.rules`
10. `firebase.json`
