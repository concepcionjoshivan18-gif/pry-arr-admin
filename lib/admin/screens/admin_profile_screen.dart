import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/components/profile_picture_picker.dart';
import '../../core/utils/validators.dart';
import '../components/app_back_button.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';
import '../../core/components/skeleton_loader.dart';
import '../components/admin_scaffold.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fNameCtrl;
  late TextEditingController _lNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emergencyCtrl;
  String _gender = 'Male';
  bool _isSaving = false;
  bool _isLoading = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _fNameCtrl = TextEditingController();
    _lNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _emergencyCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    if (user != null && !_initialized) {
      _fNameCtrl.text = user.firstName;
      _lNameCtrl.text = user.lastName;
      _phoneCtrl.text = user.phone;
      _addressCtrl.text = user.address;
      _gender = ['Male', 'Female'].contains(user.gender) ? user.gender! : 'Male';
      _emergencyCtrl.text = user.emergencyContact;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fNameCtrl.dispose();
    _lNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final firestore = Provider.of<FirestoreService>(context, listen: false);

      final updatedData = {
        'firstName': formatCapitalized(_fNameCtrl.text),
        'lastName': formatCapitalized(_lNameCtrl.text),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'gender': _gender,
        'emergencyContact': _emergencyCtrl.text.trim(),
      };

      await firestore.updateUserProfile(auth.currentUser!.uid, updatedData);

      if (mounted) {
        await auth.fetchUserRole(auth.currentUser!.uid);
        _showSnack('Profile updated successfully!', hwOrange);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onImageSelected(dynamic bytes, bool isRemoved) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final storage = StorageService();

    try {
      String? url;
      if (isRemoved) {
        url = null;
      } else if (bytes != null) {
        url = await storage.uploadProfilePicture(auth.currentUser!.uid, bytes);
      } else {
        return;
      }

      await firestore.updateUserProfile(auth.currentUser!.uid, {'profilePhoto': url});

      if (mounted) {
        await auth.fetchUserRole(auth.currentUser!.uid);
        _showSnack('Profile picture updated.', hwOrange);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Upload failed: $e', Colors.redAccent);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (color == Colors.redAccent) {
      showTopError(context, msg);
    } else {
      showTopSuccess(context, msg);
    }
  }

  Widget _glass({
    required Widget child,
    double radius = 24,
    EdgeInsetsGeometry? padding,
  }) {
    return Builder(
      builder: (context) {
        final p = Pal.of(context);
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: p.glassFill,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: p.glassBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(color: p.shadow, blurRadius: 24, offset: const Offset(0, 12)),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHardwareBackground() => const SizedBox.shrink();

  InputDecoration _hwInputDecoration(BuildContext context, String label) {
    final p = Pal.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: p.faint, fontSize: 13),
      filled: true,
      fillColor: p.fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: hwOrange, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.currentUser;
    final p = Pal.of(context);

    if (auth.loadError != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('Error loading profile: ${auth.loadError}', style: const TextStyle(color: Colors.redAccent, fontSize: 16)),
        ),
      );
    }

    if (auth.isLoading || user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: 4,
          itemBuilder: (_, __) => const SkeletonCard(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
      children: [
        _buildHardwareBackground(),
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  // Header title
                  Row(
                    children: [
                      const Icon(Icons.engineering_rounded, color: hwOrange, size: 22),
                      const SizedBox(width: 10),
                      Text('My Workstation Profile', style: TextStyle(color: p.text, fontWeight: FontWeight.w800, fontSize: 20)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ---- Avatar + name card ----
                  _glass(
                    radius: 28,
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                    child: Column(
                      children: [
                        ProfilePicturePicker(
                          initialUrl: user?.profilePhoto,
                          initials: user?.firstName.isNotEmpty == true ? user!.firstName[0].toUpperCase() : 'A',
                          onImageSelected: _onImageSelected,
                        ),
                          const SizedBox(height: 20),
                          Text(
                            user != null ? '${user.firstName} ${user.lastName}' : 'Administrator',
                            style: TextStyle(color: p.text, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (user?.role.toUpperCase() ?? 'ADMIN'),
                            style: TextStyle(color: p.amber, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Editable details card ----
                    _glass(
                      radius: 28,
                      padding: const EdgeInsets.all(28),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.badge_outlined, color: hwOrange, size: 18),
                                const SizedBox(width: 8),
                                Text('Personal Details', style: TextStyle(color: p.text, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _fNameCtrl,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ\s'\-]"))],
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'First Name'),
                                    validator: Validators.validateFirstName,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lNameCtrl,
                                    textCapitalization: TextCapitalization.words,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÖØ-öø-ÿ\s'\-]"))],
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Last Name'),
                                    validator: Validators.validateLastName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _phoneCtrl,
                              style: TextStyle(color: p.text),
                              decoration: _hwInputDecoration(context, 'Contact Number (09...)'),
                              validator: Validators.validatePhone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(11),
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _addressCtrl,
                              style: TextStyle(color: p.text),
                              decoration: _hwInputDecoration(context, 'Home Address'),
                              validator: Validators.validateAddress,
                              inputFormatters: [LengthLimitingTextInputFormatter(50)],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _gender,
                                    dropdownColor: p.surface,
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Gender'),
                                    items: ['Male', 'Female']
                                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                        .toList(),
                                    onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _emergencyCtrl,
                                    style: TextStyle(color: p.text),
                                    decoration: _hwInputDecoration(context, 'Emergency Contact (09...)'),
                                    validator: Validators.validateEmergencyContact,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(11),
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: _isSaving
                                  ? const Center(
                                child: SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(color: hwOrange, strokeWidth: 2.6),
                                ),
                              )
                                  : ElevatedButton(
                                onPressed: _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: hwOrange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: hwOrange.withOpacity(0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text(
                                  'SAVE SETTINGS',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ---- Account info card ----
                    _glass(
                      radius: 28,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            context,
                            icon: Icons.lock_outline,
                            iconColor: hwYellow,
                            title: 'System Email (Login)',
                            subtitle: user?.email ?? '',
                          ),
                          Divider(color: p.line, height: 1),
                          _buildInfoRow(
                            context,
                            icon: Icons.verified_user_outlined,
                            iconColor: Colors.greenAccent,
                            title: 'Access Role',
                            subtitle: user?.role.toUpperCase() ?? '',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, {
        required IconData icon,
        required Color iconColor,
        required String title,
        required String subtitle,
      }) {
    final p = Pal.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.18), shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: TextStyle(color: p.faint, fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }
}
