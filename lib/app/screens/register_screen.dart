import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/validators.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';
import 'otp_verification_screen.dart';
import 'package:intl/intl.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final first = TextEditingController();
  final last = TextEditingController();
  final middle = TextEditingController();
  final businessName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final emergency = TextEditingController();
  final address = TextEditingController();
  final pw = TextEditingController();
  final confirm = TextEditingController();
  final birthdayController = TextEditingController();
  final ageController = TextEditingController();
  DateTime? parsedBirthday;

  String gender = 'Male';
  bool business = false; // "I'm a contractor / business shopper"
  bool agreed = false;
  bool showPw = false, showConfirm = false;
  bool submitted = false, loading = false;
  bool dark = true;

  // used to scroll to the first field with an error
  static const order = [
    'first', 'last', 'middle', 'email', 'phone', 'emergency', 'birthday', 'address',
    'business', 'password', 'confirm', 'terms'
  ];
  final keys = {for (final id in order) id: GlobalKey()};

  // ---- real-time validation state
  static const textIds = [
    'first', 'last', 'middle', 'email', 'phone',
    'emergency', 'birthday', 'address', 'business', 'password', 'confirm'
  ];
  final focusNodes = {for (final id in textIds) id: FocusNode()};
  final touched = <String>{};

  static final nameFmt = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]")),
  ];

  static final emailFmt = <TextInputFormatter>[
    TextInputFormatter.withFunction(
        (o, n) => ('@'.allMatches(n.text).length > 1 || n.text.contains('..')) ? o : n),
  ];

  static final birthdayFmt = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
    LengthLimitingTextInputFormatter(10),
    TextInputFormatter.withFunction((oldValue, newValue) {
      final text = newValue.text.replaceAll('/', '');
      if (text.length > 8) return oldValue;
      var newText = '';
      for (int i = 0; i < text.length; i++) {
        if (i == 2 || i == 4) {
          newText += '/';
        }
        newText += text[i];
      }
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }),
  ];

  void _onBirthdayChanged() {
    final text = birthdayController.text.trim();
    if (text.length == 8 || text.length == 10) {
      try {
        final parts = text.split('/');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          if (year < 100) {
            year += year > 30 ? 1900 : 2000;
          }
          final date = DateTime(year, month, day);
          if (date.year == year && date.month == month && date.day == day) {
            parsedBirthday = date;
            final now = DateTime.now();
            int age = now.year - date.year;
            if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
              age--;
            }
            ageController.text = age.toString();
            return;
          }
        }
      } catch (_) {}
    }
    parsedBirthday = null;
    ageController.text = '';
  }

  Timer? _emailDebounce;
  bool checkingEmail = false;
  final checkedEmails = <String>{};
  final takenEmails = <String>{};

  late final TapGestureRecognizer termsTap = TapGestureRecognizer()..onTap = openTerms;

  @override
  void initState() {
    super.initState();
    birthdayController.addListener(_onBirthdayChanged);
    for (final c in [first, last, middle, businessName, email, phone, emergency, address, pw, confirm, birthdayController]) {
      c.addListener(() => setState(() {}));
    }
    email.addListener(() {
      _emailDebounce?.cancel();
      _emailDebounce = Timer(const Duration(milliseconds: 600), _checkEmail);
    });
    focusNodes.forEach((id, node) {
      node.addListener(() {
        if (!node.hasFocus) {
          if (touched.add(id)) setState(() {});
          if (id == 'email') {
            _emailDebounce?.cancel();
            _checkEmail();
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    birthdayController.dispose();
    ageController.dispose();
    for (final n in focusNodes.values) {
      n.dispose();
    }
    for (final c in [first, last, middle, businessName, email, phone, emergency, address, pw, confirm]) {
      c.dispose();
    }
    termsTap.dispose();
    super.dispose();
  }

  String? errorFor(String id) {
    switch (id) {
      case 'first':
        return Validators.validateFirstName(first.text);
      case 'last':
        return Validators.validateLastName(last.text);
      case 'middle':
        return Validators.validateMiddleName(middle.text);
      case 'email':
        {
          final formatErr = Validators.validateEmail(email.text);
          if (formatErr != null) return formatErr;
          if (takenEmails.contains(email.text.trim().toLowerCase())) {
            return 'This email is already registered';
          }
          return null;
        }
      case 'phone':
        return Validators.validatePhone(phone.text);
      case 'emergency':
        return Validators.validateEmergencyContact(emergency.text, ownPhone: phone.text);
      case 'birthday':
        return Validators.validateBirthday(parsedBirthday);
      case 'address':
        return Validators.validateAddress(address.text);
      case 'business':
        return business ? Validators.validateBusinessName(businessName.text) : null;
      case 'password':
        return Validators.validatePassword(pw.text);
      case 'confirm':
        return Validators.validateConfirmPassword(confirm.text, pw.text);
      case 'terms':
        return agreed ? null : 'Please accept the terms to continue';
    }
    return null;
  }

  String? shown(String id) => (submitted || touched.contains(id)) ? errorFor(id) : null;

  Future<bool> isEmailRegistered(String e) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    return await authService.isEmailAlreadyInUse(e);
  }

  Future<void> _checkEmail() async {
    final e = email.text.trim().toLowerCase();
    if (Validators.validateEmail(e) != null || checkedEmails.contains(e)) return;
    setState(() => checkingEmail = true);
    bool taken = false, ok = true;
    try {
      taken = await isEmailRegistered(e);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      checkingEmail = false;
      if (ok) checkedEmails.add(e);
      if (taken) takenEmails.add(e);
    });
  }

  int get totalRequired => business ? 10 : 9;

  int get filled => [
        first.text.trim().isNotEmpty,
        last.text.trim().isNotEmpty,
        email.text.trim().isNotEmpty,
        phone.text.isNotEmpty,
        emergency.text.isNotEmpty,
        address.text.trim().isNotEmpty,
        if (business) businessName.text.trim().isNotEmpty,
        pw.text.isNotEmpty,
        confirm.text.isNotEmpty,
        agreed,
      ].where((e) => e).length;

  double get strength => Validators.getPasswordStrength(pw.text);

  Future<void> openTerms() async {
    final ok = await showPalSheet<bool>(context, const TermsSheet());
    if (ok == true) setState(() => agreed = true);
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => submitted = true);
    await _checkEmail();
    if (!mounted) return;

    final bad = order.where((id) => errorFor(id) != null).toList();
    final bdayErr = Validators.validateBirthday(parsedBirthday);
    if (bad.isNotEmpty || bdayErr != null) {
      if (bdayErr != null) {
        showTopNotification(context, bdayErr, isError: true);
      } else {
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
      }
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

  @override
  Widget build(BuildContext context) {
    return Pal(
      dark: dark,
      child: Builder(
        builder: (context) {
          final p = Pal.of(context);
          final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                const Positioned.fill(child: Background()),
                SafeArea(
                  child: Column(
                    children: [
                      _header(p),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                          children: [
                            _section(p, Icons.person_rounded, 'Personal details', [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: _field('first', 'First name', first,
                                          cap: TextCapitalization.words, maxLen: 50, fmt: nameFmt)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _field('last', 'Last name', last,
                                          cap: TextCapitalization.words, maxLen: 50, fmt: nameFmt)),
                                ],
                              ),
                              _field('middle', 'Middle name (optional)', middle,
                                  icon: Icons.badge_outlined,
                                  cap: TextCapitalization.words,
                                  maxLen: 50,
                                  fmt: nameFmt),
                              _genderPicker(p),
                            ]),
                            _section(p, Icons.call_rounded, 'Contact', [
                              _field('email', 'Email address', email,
                                  icon: Icons.mail_outline_rounded,
                                  type: TextInputType.emailAddress,
                                  maxLen: 100,
                                  fmt: emailFmt,
                                  noSpaces: true,
                                  suffix: checkingEmail
                                      ? const Padding(
                                          padding: EdgeInsets.all(14),
                                          child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2)),
                                        )
                                      : (errorFor('email') == null &&
                                              checkedEmails.contains(email.text.trim().toLowerCase())
                                          ? Icon(Icons.check_circle_rounded, color: p.ok)
                                          : null)),
                              _field('phone', 'Contact number', phone,
                                  icon: Icons.smartphone_rounded,
                                  type: TextInputType.phone,
                                  hint: '09XXXXXXXXX',
                                  fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]),
                              _field('emergency', 'Emergency contact number', emergency,
                                  icon: Icons.contact_phone_outlined,
                                  type: TextInputType.phone,
                                  hint: '09XXXXXXXXX',
                                  helper: 'Someone we can reach if there is a problem with a delivery',
                                  fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]),
                              _birthdayAndAgeRow(p),
                            ]),
                            _section(p, Icons.location_on_rounded, 'Address', [
                              _field('address', 'Home address', address,
                                  icon: Icons.home_outlined,
                                  lines: 2,
                                  hint: 'House no., street, barangay, city, province',
                                  maxLen: 200,
                                  cap: TextCapitalization.words),
                            ]),
                            _section(p, Icons.lock_rounded, 'Security', [
                              _field('password', 'Password', pw,
                                  icon: Icons.lock_outline_rounded,
                                  obscure: !showPw,
                                  suffix: _eye(p, showPw, () => setState(() => showPw = !showPw))),
                              if (pw.text.isNotEmpty) _strengthMeter(p),
                              _field('confirm', 'Confirm password', confirm,
                                  icon: Icons.lock_reset_rounded,
                                  obscure: !showConfirm,
                                  suffix: confirm.text.isNotEmpty && confirm.text == pw.text
                                      ? Icon(Icons.check_circle_rounded, color: p.ok)
                                      : _eye(p, showConfirm, () => setState(() => showConfirm = !showConfirm))),
                            ]),
                            _businessCard(p),
                            if (business)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Glass(
                                  radius: 24,
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                                  child: _field('business', 'Business name', businessName,
                                      icon: Icons.business_rounded,
                                      maxLen: 100,
                                      cap: TextCapitalization.words),
                                ),
                              ),
                            const SizedBox(height: 14),
                            _terms(p),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => context.go('/login'),
                              child: Center(
                                child: Text('Already have an account?  Sign in',
                                    style: ts(p.faint, 13, FontWeight.w600)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!keyboardOpen) _bottomBar(p),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _birthdayAndAgeRow(Pal p) {
    final err = shown('birthday');
    OutlineInputBorder b(Color color, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: w));

    return KeyedSubtree(
      key: keys['birthday'],
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: birthdayController,
                focusNode: focusNodes['birthday'],
                keyboardType: TextInputType.number,
                inputFormatters: birthdayFmt,
                style: ts(p.text, 15),
                decoration: InputDecoration(
                  labelText: 'Birthday',
                  labelStyle: ts(p.sub, 14),
                  floatingLabelStyle: ts(p.sub, 13, FontWeight.w600),
                  hintText: 'DD/MM/YYYY',
                  hintStyle: ts(p.faint, 14),
                  errorText: err,
                  errorMaxLines: 2,
                  errorStyle: ts(p.danger, 12, FontWeight.w600),
                  prefixIcon: Icon(Icons.cake_rounded,
                      color: err != null ? p.danger : p.sub, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today_rounded, color: hwOrange, size: 18),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                        firstDate: DateTime.now().subtract(const Duration(days: 365 * 60)),
                        lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        birthdayController.text = DateFormat('dd/MM/yyyy').format(picked);
                      }
                    },
                  ),
                  filled: true,
                  fillColor: p.dark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  border: b(p.line),
                  enabledBorder: b(p.line),
                  focusedBorder: b(hwOrange, 1.5),
                  errorBorder: b(p.danger),
                  focusedErrorBorder: b(p.danger, 1.5),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: ageController,
                readOnly: true,
                style: ts(p.text, 15),
                decoration: InputDecoration(
                  labelText: 'Age',
                  labelStyle: ts(p.sub, 14),
                  floatingLabelStyle: ts(p.sub, 13, FontWeight.w600),
                  hintText: '10-50',
                  hintStyle: ts(p.faint, 14),
                  filled: true,
                  fillColor: p.dark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                  border: b(p.line),
                  enabledBorder: b(p.line),
                  focusedBorder: b(hwOrange, 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        children: [
          Row(
            children: [
              Glass(
                radius: 22,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: IconButton(
                    onPressed: () => context.go('/login'),
                    icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Join us in a few steps', style: ts(p.faint, 13)),
                    const SizedBox(height: 2),
                    Text('Create account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(p.text, 24, FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: filled / totalRequired,
                    minHeight: 6,
                    backgroundColor: p.track,
                    color: filled == totalRequired ? p.ok : hwOrange,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$filled/$totalRequired', style: ts(p.faint, 12, FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(Pal p, IconData icon, String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: hwOrange.withValues(alpha: 0.14)),
                  child: Icon(icon, color: hwOrange, size: 18),
                ),
                const SizedBox(width: 10),
                Text(title, style: ts(p.text, 16, FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _field(
    String id,
    String label,
    TextEditingController c, {
    IconData? icon,
    TextInputType? type,
    List<TextInputFormatter>? fmt,
    bool obscure = false,
    Widget? suffix,
    String? hint,
    String? helper,
    int lines = 1,
    TextCapitalization cap = TextCapitalization.none,
    int? maxLen,
    bool noSpaces = false,
  }) {
    final p = Pal.of(context);
    final err = shown(id);
    final formatters = <TextInputFormatter>[
      ...?fmt,
      if (maxLen != null) LengthLimitingTextInputFormatter(maxLen),
      if (obscure) LengthLimitingTextInputFormatter(64),
      if (noSpaces || obscure) FilteringTextInputFormatter.deny(RegExp(r'\s')),
      if (!noSpaces && !obscure)
        TextInputFormatter.withFunction(
            (o, n) => (n.text.startsWith(' ') || n.text.contains('  ')) ? o : n),
    ];
    OutlineInputBorder b(Color color, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: w));

    return KeyedSubtree(
      key: keys[id],
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          focusNode: focusNodes[id],
          keyboardType: type,
          inputFormatters: formatters,
          obscureText: obscure,
          textCapitalization: cap,
          maxLines: obscure ? 1 : lines,
          style: ts(p.text, 15),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: ts(p.sub, 14),
            floatingLabelStyle: ts(p.sub, 13, FontWeight.w600),
            hintText: hint,
            hintStyle: ts(p.faint, 14),
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: ts(p.sub, 11),
            errorText: err,
            errorMaxLines: 2,
            errorStyle: ts(p.danger, 12, FontWeight.w600),
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: err != null ? p.danger : p.sub, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: p.dark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            border: b(p.line),
            enabledBorder: b(p.line),
            focusedBorder: b(hwOrange, 1.5),
            errorBorder: b(p.danger),
            focusedErrorBorder: b(p.danger, 1.5),
          ),
        ),
      ),
    );
  }

  Widget _eye(Pal p, bool visible, VoidCallback onTap) => IconButton(
        onPressed: onTap,
        icon: Icon(visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: p.faint, size: 20),
      );

  Widget _genderPicker(Pal p) {
    const options = [
      ('Male', Icons.male_rounded),
      ('Female', Icons.female_rounded),
      ('Other', Icons.transgender_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Gender', style: ts(p.faint, 12, FontWeight.w600)),
          ),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: o == options.last ? 0 : 8),
                    child: GestureDetector(
                      onTap: () => setState(() => gender = o.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: gender == o.$1 ? hwOrange : (p.dark ? Colors.white.withValues(alpha: 0.08) : Colors.white),
                          borderRadius: BorderRadius.circular(18),
                          border: gender == o.$1 ? null : Border.all(color: p.line),
                          boxShadow: gender == o.$1
                              ? [
                                  BoxShadow(
                                      color: hwOrange.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(o.$2, size: 18, color: gender == o.$1 ? Colors.white : p.sub),
                            const SizedBox(width: 4),
                            Text(o.$1,
                                style: ts(gender == o.$1 ? Colors.white : p.text, 13, FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strengthMeter(Pal p) {
    final v = strength;
    final bars = (v * 4).ceil();
    final color = v <= 0.34 ? p.danger : (v <= 0.67 ? p.amber : p.ok);
    final label = v <= 0.34 ? 'Weak' : (v <= 0.67 ? 'Fair' : (v < 1 ? 'Good' : 'Strong'));
    final t = pw.text;
    final rules = [
      ('8+ characters', t.length >= 8),
      ('Upper & lower case', RegExp(r'[A-Z]').hasMatch(t) && RegExp(r'[a-z]').hasMatch(t)),
      ('A number', RegExp(r'\d').hasMatch(t)),
      ('A symbol', RegExp(r'[^A-Za-z0-9]').hasMatch(t)),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i < bars ? color : p.track,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                child: Text(label, style: ts(color, 12, FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final r in rules)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(r.$2 ? Icons.check_circle_rounded : Icons.circle_outlined,
                        size: 14, color: r.$2 ? p.ok : p.faint),
                    const SizedBox(width: 4),
                    Text(r.$1, style: ts(r.$2 ? p.ok : p.faint, 11, FontWeight.w600)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _businessCard(Pal p) {
    return Glass(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: hwOrange.withValues(alpha: 0.14)),
            child: const Icon(Icons.business_center_rounded, color: hwOrange, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("I'm a contractor / business shopper", style: ts(p.text, 14, FontWeight.w800)),
                const SizedBox(height: 2),
                Text('For bulk and business purchases', style: ts(p.faint, 12)),
              ],
            ),
          ),
          Switch(
            value: business,
            activeThumbColor: Colors.white,
            activeTrackColor: hwOrange,
            onChanged: (v) => setState(() => business = v),
          ),
        ],
      ),
    );
  }

  Widget _terms(Pal p) {
    final err = shown('terms');
    return KeyedSubtree(
      key: keys['terms'],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: agreed,
                activeColor: hwOrange,
                side: BorderSide(color: err != null ? p.danger : p.faint, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onChanged: (v) => setState(() => agreed = v ?? false),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: ts(p.sub, 13),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms and Conditions',
                        recognizer: termsTap,
                        style: ts(hwOrange, 13, FontWeight.w800)
                            .copyWith(decoration: TextDecoration.underline),
                      ),
                      const TextSpan(text: ' of the service.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (err != null)
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(err, style: ts(p.danger, 12, FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar(Pal p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Glass(
        radius: 28,
        padding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: loading ? null : submit,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hwOrange,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: hwOrange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5)),
              ],
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text('Create account', style: ts(Colors.white, 16, FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

Future<T?> showPalSheet<T>(BuildContext context, Widget child) {
  final dark = Pal.of(context).dark;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Pal(dark: dark, child: SheetShell(child: child)),
  );
}

class SheetShell extends StatelessWidget {
  final Widget child;
  const SheetShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.88),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + mq.viewInsets.bottom),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 18),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PrimaryButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hwOrange,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: hwOrange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5)),
          ],
        ),
        child: Text(label, style: ts(Colors.white, 15, FontWeight.w800)),
      ),
    );
  }
}

class TermsSheet extends StatelessWidget {
  const TermsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final mq = MediaQuery.of(context);

    Widget para(String t, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: ts(p.text, 14, FontWeight.w800)),
              const SizedBox(height: 4),
              Text(b, style: ts(p.sub, 13).copyWith(height: 1.4)),
            ],
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.faint.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Terms and Conditions', style: ts(p.text, 20, FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Please read before creating your account', style: ts(p.faint, 13)),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                para('1. Account Registration & Security',
                    'By creating an account with PRY-ARR Hardware OMS, you agree to provide accurate, current, and complete personal details (full name, contact number, and address). You are responsible for keeping your password confidential and for all activities under your account.'),
                para('2. Orders & Product Availability',
                    'All orders placed for hardware tools, construction supplies, and equipment are subject to product availability and price verification. PRY-ARR Hardware reserves the right to modify prices or cancel orders in cases of stock unavailability or pricing errors.'),
                para('3. Payment & Cash on Delivery (COD)',
                    'We support Cash on Delivery (COD) and approved digital payments. For COD orders, please ensure an authorized representative is present at the delivery location with exact payment. Repeated refusal of COD deliveries without valid justification may result in account restriction.'),
                para('4. Delivery & Inspection',
                    'Estimated delivery times are subject to traffic, weather, and logistics conditions. Customers or authorized representatives are required to inspect delivered items upon arrival. Any missing, damaged, or incorrect hardware items must be reported within 24 hours of delivery.'),
                para('5. Returns & Exchange Policy',
                    'Items eligible for exchange must be in original condition, unopened, and accompanied by the official receipt. Custom-cut materials (e.g., pipes, wires, glass, or tint) are non-returnable unless proven defective.'),
                para('6. Privacy & Data Protection',
                    'PRY-ARR Hardware values your privacy. Your personal information is stored securely and used strictly for processing orders, managing deliveries, and providing customer support. We do not sell or disclose your personal details to unauthorized third parties.'),
                para('7. User Conduct & Terms Updates',
                    'You agree not to misuse the platform or place fraudulent orders. PRY-ARR Hardware reserves the right to update these terms at any time. Continued use of the platform indicates your agreement to any modified terms.'),
                para('8. Customer Support',
                    'For questions, order updates, or assistance, please reach out to PRY-ARR Hardware customer support through the app profile screen or store contact channels.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'I agree', onTap: () => Navigator.pop(context, true)),
      ],
    );
  }
}

class SuccessSheet extends StatelessWidget {
  final String name;
  final VoidCallback onStartShopping;
  const SuccessSheet({super.key, required this.name, required this.onStartShopping});

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.ok.withValues(alpha: 0.15),
            border: Border.all(color: p.ok, width: 3),
          ),
          child: Icon(Icons.check_rounded, size: 48, color: p.ok),
        ),
        const SizedBox(height: 16),
        Text('Welcome, $name!', style: ts(p.text, 22, FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Your account has been created.', style: ts(p.faint, 13)),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Start shopping', onTap: onStartShopping),
      ],
    );
  }
}
