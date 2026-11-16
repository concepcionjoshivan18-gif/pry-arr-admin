import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import '../models/app_user.dart';
import '../../services/shift_gate.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isLoading = true;
  bool _hasActiveSession = false;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get hasActiveSession => _auth.currentUser != null || _hasActiveSession;

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        stopShiftWatch();
        _userDocSubscription?.cancel();
        _currentUser = null;
        _hasActiveSession = false;
        _isLoading = false;
        notifyListeners();
      } else {
        final allowed = await canEnter(user);
        if (!allowed) {
          stopShiftWatch();
          await _auth.signOut();
          _currentUser = null;
          _hasActiveSession = false;
          _isLoading = false;
          notifyListeners();
        } else {
          _hasActiveSession = true;
          startShiftWatch(user);
          _startUserDocListener(user.uid);
        }
      }
    });
  }

  void _startUserDocListener(String uid) {
    _hasActiveSession = true;
    _userDocSubscription?.cancel();
    _userDocSubscription = _db.collection('users').doc(uid).snapshots().listen((doc) {
      if (doc.exists) {
        _currentUser = AppUser.fromMap(doc.data() as Map<String, dynamic>, uid);
      } else {
        // Fallback for new users or hardcoded admins not yet in DB
        if (_currentUser == null || _currentUser!.uid != uid) {
          _currentUser = AppUser(
            uid: uid,
            email: _auth.currentUser?.email ?? '',
            firstName: '',
            lastName: '',
            phone: '',
            role: 'customer',
            marketingOptIn: false,
            createdAt: DateTime.now(),
          );
        }
      }
      _isLoading = false;
      NotificationService.instance.startListeningToOrders(FirestoreService(), this);
      notifyListeners();
    });
  }

  Future<void> fetchUserRole(dynamic userOrUid) async {
    try {
      final String uid = (userOrUid is User) ? userOrUid.uid : userOrUid.toString();
      DocumentSnapshot? doc;
      try {
        doc = await _db.collection('users').doc(uid).get(const GetOptions(source: Source.server));
      } catch (_) {
        // Fallback to default cache/offline get if server fetch fails
        doc = await _db.collection('users').doc(uid).get();
      }

      if (doc != null && doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(doc.data() as Map<String, dynamic>, uid);
      } else if (userOrUid is User) {
        _currentUser = AppUser(
          uid: uid,
          email: userOrUid.email ?? '',
          firstName: '',
          lastName: '',
          phone: '',
          role: 'customer',
          marketingOptIn: false,
          createdAt: DateTime.now(),
        );
      }
      NotificationService.instance.startListeningToOrders(FirestoreService(), this);
    } catch (e) {
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateLocalUser(Map<String, dynamic> data) {
    if (_currentUser != null) {
      final currentMap = _currentUser!.toMap();
      data.forEach((key, value) {
        currentMap[key] = value;
      });
      _currentUser = AppUser.fromMap(currentMap, _currentUser!.uid);
      notifyListeners();
    }
  }

  Future<bool> isEmailAlreadyInUse(String email) async {
    try {
      final list = await _auth.fetchSignInMethodsForEmail(email.trim());
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      if (cred.user != null) {
        final allowed = await canEnter(cred.user!);
        if (!allowed) {
          await _auth.signOut();
          _hasActiveSession = false;
          _isLoading = false;
          notifyListeners();
          throw Exception('Please time in with your RFID card at the device before signing in.');
        }

        _hasActiveSession = true;
        await fetchUserRole(cred.user!);
        notifyListeners();
      }
    } catch (e) {
      _hasActiveSession = false;
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> registerCustomerUser({
    required String email,
    required String password,
    required String firstName,
    String? middleName,
    required String lastName,
    required String phone,
    String? businessName,
    required bool marketingOptIn,
    DateTime? birthday,
  }) async {
    _isLoading = true;
    notifyListeners();
    User? newlyCreatedAuthUser;

    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      newlyCreatedAuthUser = credential.user;

      if (newlyCreatedAuthUser != null) {
        AppUser newUserProfile = AppUser(
          uid: newlyCreatedAuthUser.uid,
          email: email.trim(),
          firstName: firstName.trim(),
          middleName: (middleName != null && middleName.trim().isNotEmpty) ? middleName.trim() : null,
          lastName: lastName.trim(),
          phone: phone.trim(),
          role: 'customer',
          businessName: (businessName != null && businessName.trim().isNotEmpty) ? businessName.trim() : null,
          marketingOptIn: marketingOptIn,
          createdAt: DateTime.now(),
          birthday: birthday,
        );

        await _db.collection('users').doc(newlyCreatedAuthUser.uid).set(newUserProfile.toMap());
        _currentUser = newUserProfile;
        _hasActiveSession = true;
      }
    } catch (e) {
      if (newlyCreatedAuthUser != null) {
        try {
          await newlyCreatedAuthUser.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createStaffAccount({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String assignedRole,
    required double basicSalary,
    String? phone,
    String? address,
    String? gender,
    String? emergencyContact,
    DateTime? birthday,
    String? rfidUid,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      FirebaseApp secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );

      UserCredential credential = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      User? staffUser = credential.user;

      if (staffUser != null) {
        final cleanRfid = rfidUid?.trim().toUpperCase();
        AppUser staffProfile = AppUser(
          uid: staffUser.uid,
          email: email.trim(),
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          phone: phone ?? '',
          role: assignedRole.toLowerCase() == 'driver' ? 'driver' : 'staff',
          assignedRole: assignedRole,
          basicSalary: basicSalary,
          marketingOptIn: false,
          createdAt: DateTime.now(),
          status: 'Active',
          address: address ?? '',
          gender: gender ?? 'Male',
          emergencyContact: emergencyContact ?? '',
          birthday: birthday,
          rfidUid: cleanRfid,
          onShift: false,
        );

        await _db.collection('users').doc(staffUser.uid).set(staffProfile.toMap());

        if (cleanRfid != null && cleanRfid.isNotEmpty) {
          await _db.collection('cards').doc(cleanRfid).set({'staffId': staffUser.uid});
        }
      }

      await secondaryApp.delete();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    stopShiftWatch();
    _hasActiveSession = false;
    _currentUser = null;
    notifyListeners();
    await _auth.signOut();
  }
}
