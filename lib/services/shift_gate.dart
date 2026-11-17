import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const rfidRoles = {'staff', 'driver'};

StreamSubscription<DocumentSnapshot>? _shiftSubscription;

Future<bool> canEnter(User user) async {
  DocumentSnapshot<Map<String, dynamic>> doc;
  try {
    doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('[AUTH] canEnter: hindi nabasa ang profile, BLOCK. error=$e');
    return false;
  }

  if (!doc.exists || doc.data() == null) {
    debugPrint('[AUTH] canEnter: walang profile doc para sa ${user.uid}, BLOCK');
    return false;
  }

  final data = doc.data()!;
  final role = (data['role']?.toString() ?? '').toLowerCase();

  if (role == 'customer' || role == 'admin') {
    debugPrint('[AUTH] canEnter: role=$role, ALLOW');
    return true;
  }

  if (rfidRoles.contains(role)) {
    final onShift = data['onShift'] == true;
    debugPrint('[AUTH] canEnter: role=$role onShift=$onShift -> ${onShift ? "ALLOW" : "BLOCK"}');
    return onShift;
  }

  debugPrint('[AUTH] canEnter: hindi kilalang role "$role", BLOCK');
  return false;
}

void startShiftWatch(User user) {
  stopShiftWatch();
  _shiftSubscription = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
    if (!doc.exists) return;
    final data = doc.data();
    if (data == null) return;
    final role = (data['role']?.toString() ?? '').toLowerCase();
    if (role.isEmpty || rfidRoles.contains(role)) {
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
