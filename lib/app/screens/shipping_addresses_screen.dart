import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/components/top_notification.dart';

class ShippingAddressesScreen extends StatefulWidget {
  const ShippingAddressesScreen({super.key});

  @override
  State<ShippingAddressesScreen> createState() => _ShippingAddressesScreenState();
}

class _ShippingAddressesScreenState extends State<ShippingAddressesScreen> {
  final TextEditingController _newAddressController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _newAddressController.dispose();
    super.dispose();
  }

  void _addAddress(AuthService authService, FirestoreService firestoreService) async {
    final user = authService.currentUser;
    final newAddress = _newAddressController.text.trim();
    if (user == null || newAddress.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      final updatedAddresses = List<String>.from(user.shippingAddresses);
      if (!updatedAddresses.contains(newAddress)) {
        updatedAddresses.add(newAddress);
        await firestoreService.updateUserProfile(user.uid, {'shippingAddresses': updatedAddresses});
        authService.updateLocalUser({'shippingAddresses': updatedAddresses});
        _newAddressController.clear();
        if (mounted) {
          showTopNotification(context, 'Shipping address added successfully!', isSuccess: true);
        }
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _deleteAddress(String address, AuthService authService, FirestoreService firestoreService) async {
    final user = authService.currentUser;
    if (user == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final p = Pal.of(context);
        return AlertDialog(
          backgroundColor: p.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              Text('Delete Address?', style: TextStyle(color: p.text, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to remove "$address"?',
            style: TextStyle(color: p.sub, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text('Cancel', style: TextStyle(color: p.faint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final updatedAddresses = List<String>.from(user.shippingAddresses)..remove(address);
      await firestoreService.updateUserProfile(user.uid, {'shippingAddresses': updatedAddresses});
      authService.updateLocalUser({'shippingAddresses': updatedAddresses});
      if (mounted) {
        showTopNotification(context, 'Address removed', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, 'Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final firestoreService = Provider.of<FirestoreService>(context);
    final user = authService.currentUser;
    final addresses = user?.shippingAddresses ?? [];
    final p = Pal.of(context);

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
                      Text('Shipping Addresses', style: ts(p.text, 22, FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text('Your Saved Addresses', style: ts(p.text, 16, FontWeight.w800)),
                      const SizedBox(height: 12),
                      if (addresses.isEmpty)
                        Glass(
                          radius: 20,
                          padding: const EdgeInsets.all(24),
                          child: Center(child: Text('No shipping addresses saved yet.', style: ts(p.faint, 14))),
                        )
                      else
                        ...addresses.map((addr) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Glass(
                            radius: 20,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: hwOrange),
                                const SizedBox(width: 12),
                                Expanded(child: Text(addr, style: ts(p.text, 14, FontWeight.w600))),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, color: p.danger),
                                  onPressed: () => _deleteAddress(addr, authService, firestoreService),
                                ),
                              ],
                            ),
                          ),
                        )),
                      const SizedBox(height: 28),
                      Text('Add New Address', style: ts(p.text, 16, FontWeight.w800)),
                      const SizedBox(height: 12),
                      Glass(
                        radius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _newAddressController,
                              maxLines: 2,
                              style: ts(p.text, 14),
                              decoration: InputDecoration(
                                hintText: 'Enter complete street, barangay, city...',
                                hintStyle: ts(p.faint, 14),
                                filled: true,
                                fillColor: p.fill,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: hwOrange, width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_isAdding)
                              const CircularProgressIndicator()
                            else
                              GestureDetector(
                                onTap: () => _addAddress(authService, firestoreService),
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
                                  child: Text('SAVE NEW ADDRESS', style: ts(Colors.white, 14, FontWeight.w800)),
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
