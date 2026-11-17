import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/utils/validators.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _emergencyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _addressController = TextEditingController(text: user?.address ?? '');
    _emergencyController = TextEditingController(text: user?.emergencyContact ?? '');
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyController.dispose();
    super.dispose();
  }

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

  void _changePassword() {
    final pwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final pwText = pwCtrl.text;
          final strength = Validators.getPasswordStrength(pwText);
          final strengthLabel = Validators.getPasswordStrengthLabel(strength);
          final strengthColor = strength <= 0.34 ? Colors.redAccent : (strength <= 0.67 ? Colors.amber : Colors.green);

          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: pwCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                      validator: (v) => Validators.validatePassword(v),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (int i = 0; i < 3; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(right: i == 2 ? 0 : 4),
                              decoration: BoxDecoration(
                                color: (strength * 3).ceil() > i ? strengthColor : Colors.grey.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(strengthLabel, style: TextStyle(color: strengthColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder()),
                      validator: (v) => v != pwCtrl.text ? 'Passwords do not match' : null,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await user.updatePassword(pwCtrl.text.trim());
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          showTopNotification(context, 'Password updated successfully!', isSuccess: true);
                        }
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        showTopNotification(context, 'Error: $e. Please re-login and try again.', isError: true);
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: hwOrange, foregroundColor: Colors.white),
                child: const Text('Update Password'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: Background()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Glass(
                        radius: 22,
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: Icon(Icons.arrow_back_rounded, color: p.text, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Edit Profile', style: ts(p.text, 22, FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Glass(
                        radius: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Personal Information', style: ts(p.text, 16, FontWeight.w800)),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))],
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                labelText: 'First Name',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[A-Za-zÀ-ÖØ-öø-ÿ .'\-]"))],
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                labelText: 'Last Name',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              style: ts(p.text, 14),
                              validator: Validators.validateAddress,
                              inputFormatters: [LengthLimitingTextInputFormatter(50)],
                              decoration: InputDecoration(
                                labelText: 'Home Address',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _emergencyController,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                labelText: 'Emergency Contact',
                                labelStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: b(p.line),
                                enabledBorder: b(p.line),
                                focusedBorder: b(hwOrange, 1.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            OutlinedButton.icon(
                              onPressed: _changePassword,
                              icon: const Icon(Icons.lock_reset_rounded, color: hwOrange),
                              label: Text('Change Password', style: ts(p.text, 14, FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                side: BorderSide(color: p.line),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (_isSaving)
                              const Center(child: CircularProgressIndicator())
                            else
                              GestureDetector(
                                onTap: _saveProfile,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: hwOrange,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: hwOrange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5)),
                                    ],
                                  ),
                                  child: Text('SAVE CHANGES', style: ts(Colors.white, 15, FontWeight.w800)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
