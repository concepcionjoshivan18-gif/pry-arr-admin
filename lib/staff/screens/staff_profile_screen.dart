import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/components/profile_picture_picker.dart';
import '../../core/components/top_notification.dart';
import '../../core/theme/hardware_theme.dart';
import '../../app/screens/edit_profile_screen.dart';

class StaffProfileScreen extends StatefulWidget {
  const StaffProfileScreen({super.key});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  bool _isUploading = false;

  void _onImageSelected(dynamic bytes, bool isRemoved) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    final storage = StorageService();

    if (auth.currentUser == null) return;

    setState(() => _isUploading = true);
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
        showTopNotification(context, 'Profile picture updated successfully!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Upload failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeController = Provider.of<ThemeController>(context);
    final user = authService.currentUser;
    final p = Pal.of(context);

    final roleLabel = user?.assignedRole ?? (user?.isDriver == true ? 'Delivery Driver' : (user?.role.toUpperCase() ?? 'STAFF'));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back', style: ts(p.faint, 13)),
                      const SizedBox(height: 2),
                      Text('Account Profile', style: ts(p.text, 26, FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Profile Card
            Glass(
              radius: 28,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                children: [
                  ProfilePicturePicker(
                    initials: user?.firstName.isNotEmpty == true ? user!.firstName[0].toUpperCase() : 'S',
                    initialUrl: user?.profilePhoto,
                    onImageSelected: _onImageSelected,
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(color: hwOrange),
                  ],
                  const SizedBox(height: 14),
                  Text(user?.fullName ?? 'Staff Member', style: ts(p.text, 22, FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '', style: ts(p.faint, 13)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: hwOrange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.stars_rounded, size: 18, color: hwOrange),
                        const SizedBox(width: 6),
                        Text(
                          roleLabel,
                          style: ts(hwOrange, 13, FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Menu Items Card
            Glass(
              radius: 24,
              child: Column(
                children: [
                  _menuTile(
                    p,
                    icon: Icons.settings_rounded,
                    title: 'Settings (Edit Profile)',
                    subtitle: 'Edit personal & account information',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                      );
                    },
                  ),

                  Divider(height: 1, indent: 72, endIndent: 16, color: p.line),

                  // Theme Switcher Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (themeController.dark ? hwYellow : hwOrange).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            themeController.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: themeController.dark ? hwYellow : hwOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                themeController.dark ? 'Dark Theme' : 'Light Theme',
                                style: ts(p.text, 15, FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                themeController.dark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                                style: ts(p.faint, 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: themeController.dark,
                          activeColor: hwOrange,
                          onChanged: (_) => themeController.toggleTheme(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Sign Out Button
            GestureDetector(
              onTap: () async {
                await authService.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: p.danger.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: p.danger.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: p.danger, size: 20),
                    const SizedBox(width: 8),
                    Text('Sign Out', style: ts(p.danger, 15, FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(Pal p, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hwOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: hwOrange, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ts(p.text, 15, FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: ts(p.faint, 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.faint, size: 20),
          ],
        ),
      ),
    );
  }
}
