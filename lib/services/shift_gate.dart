import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const rfidRoles = {'staff', 'driver'};

StreamSubscription<DocumentSnapshot>? _shiftSubscription;

Future<bool> canEnter(User user) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!doc.exists) return false;
    final data = doc.data();
    if (data == null) return false;
    final role = (data['role']?.toString() ?? '').toLowerCase();
    if (!rfidRoles.contains(role)) {
      return true;
    }
    final onShift = data['onShift'] == true;
    return onShift;
  } catch (_) {
    return false;
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
