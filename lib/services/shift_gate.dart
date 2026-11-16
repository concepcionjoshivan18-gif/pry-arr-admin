import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const rfidRoles = {'staff', 'driver'};

StreamSubscription<DocumentSnapshot>? _shiftSubscription;

Future<bool> canEnter(User user) async {
  try {
    DocumentSnapshot? doc;
    try {
      doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      try {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {}
    }

    if (doc == null || !doc.exists) return true; // Default allow if user profile not yet created
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return true;
    
    final role = (data['role']?.toString() ?? '').toLowerCase();
    
    // Customers and Admins never need to time in with RFID
    if (role == 'customer' || role == 'admin' || role.isEmpty) {
      return true;
    }

    // Only staff and drivers require onShift == true
    if (rfidRoles.contains(role)) {
      final onShift = data['onShift'] == true;
      return onShift;
    }

    return true;
  } catch (_) {
    return true; // Default allow on error to prevent accidental lockouts/hangs
  }
}

void startShiftWatch(User user) {
  stopShiftWatch();
  _shiftSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
    if (!doc.exists) return;
    final data = doc.data();
    if (data == null) return;
    final role = (data['role']?.toString() ?? '').toLowerCase();
    if (rfidRoles.contains(role)) {
      final onShift = data['onShift'] == true;
      if (!onShift) {
        FirebaseAuth.instance.signOut();
      }
    }
  });
}

void stopShiftWatch() {
  _shiftSubscription?.cancel();
  _shiftSubscription = null;
}
