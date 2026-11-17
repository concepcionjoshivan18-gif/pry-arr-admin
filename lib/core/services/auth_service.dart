import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import '../models/app_user.dart';
import '../../services/shift_gate.dart';

enum AppTarget { admin, storefront }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AppTarget target;

  AppUser? _currentUser;
  bool _isLoading = true;
  bool _hasActiveSession = false;
  bool _signingIn = false;
  bool _registering = false;
  String? _loadError;
  String? _activeUid;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isSigningIn => _signingIn;
  String? get loadError => _loadError;
  bool get hasActiveSession => _auth.currentUser != null || _hasActiveSession;

  AuthService({this.target = AppTarget.storefront}) {
    _auth.authStateChanges().listen((User? user) async {
      if (_signingIn || _registering) return;
      _loadError = null;
      debugPrint('[AUTH] authStateChanges fired -> target: $target, user: ${user?.uid}');
      if (user == null) {
        stopShiftWatch();
        _userDocSubscription?.cancel();
        _userDocSubscription = null;
        _activeUid = null;
        _currentUser = null;
        _hasActiveSession = false;
        _isLoading = false;
        _loadError = null;
        debugPrint('[AUTH] user null -> state cleared');
        notifyListeners();
      } else {
        _hasActiveSession = true;
        _startUserDocListener(user);
      }
    });
  }

  Future<void> _startUserDocListener(User firebaseUser) async {
    _hasActiveSession = true;
    _loadError = null;
    _activeUid = firebaseUser.uid;
    _userDocSubscription?.cancel();
    _userDocSubscription = null;

    try {
      var doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (!doc.exists && firebaseUser.email != null && firebaseUser.email!.isNotEmpty) {
        try {
          final query = await _db.collection('users').where('email', isEqualTo: firebaseUser.email!.trim()).limit(1).get();
          if (query.docs.isNotEmpty) {
            final existingDoc = query.docs.first;
            final data = existingDoc.data();
            await _db.collection('users').doc(firebaseUser.uid).set(data, SetOptions(merge: true));
            doc = await _db.collection('users').doc(firebaseUser.uid).get();
          }
        } catch (e) {
          debugPrint('Migration query error: $e');
        }
      }

      if (!doc.exists || doc.data() == null) {
        final email = firebaseUser.email ?? '';
        final isAdmin = email.toLowerCase().contains('admin');
        if (!isAdmin) {
          _currentUser = null;
          _loadError = 'User profile not found for UID: ${firebaseUser.uid}';
          _isLoading = false;
          notifyListeners();
          return;
        }
        final defaultProfile = AppUser(
          uid: firebaseUser.uid,
          email: email,
          firstName: 'Josh',
          lastName: 'Concepcion',
          phone: '',
          role: 'admin',
          marketingOptIn: false,
          createdAt: DateTime.now(),
        );
        await _db.collection('users').doc(firebaseUser.uid).set(defaultProfile.toMap(), SetOptions(merge: true));
        doc = await _db.collection('users').doc(firebaseUser.uid).get();
      }

      if (doc.exists && doc.data() != null) {
        final loadedUser = AppUser.fromMap(doc.data()!, doc.id);
        final role = loadedUser.role.toLowerCase();
        debugPrint('[AUTH] Snapshot received -> target: $target, uid: ${firebaseUser.uid}, role: $role');

        if (target == AppTarget.admin) {
          if (role != 'admin') {
            debugPrint('[AUTH] Target admin mismatch for role: $role -> signing out');
            stopShiftWatch();
            _userDocSubscription?.cancel();
            _userDocSubscription = null;
            _activeUid = null;
            _currentUser = null;
            _hasActiveSession = false;
            _loadError = 'You do not have access to the admin app.';
            _isLoading = false;
            notifyListeners();
            await _auth.signOut();
            return;
          }
          _currentUser = loadedUser;
          _loadError = null;
          _isLoading = false;
          debugPrint('[AUTH] Admin target success -> currentUser: ${_currentUser?.fullName}');
          notifyListeners();
          NotificationService.instance.startListeningToOrders(FirestoreService(), this);
        } else {
          // AppTarget.storefront
          if (role == 'admin') {
            debugPrint('[AUTH] Target storefront error: admin account logged in -> signing out');
            stopShiftWatch();
            _userDocSubscription?.cancel();
            _userDocSubscription = null;
            _activeUid = null;
            _currentUser = null;
            _hasActiveSession = false;
            _loadError = 'Please use the admin app for this account.';
            _isLoading = false;
            notifyListeners();
            await _auth.signOut();
            return;
          }

          if (role == 'staff' || role == 'driver') {
            startShiftWatch(firebaseUser);
          }

          _currentUser = loadedUser;
          _loadError = null;
          _isLoading = false;
          debugPrint('[AUTH] Storefront target success -> currentUser: ${_currentUser?.fullName}, role: $role');
          notifyListeners();
          NotificationService.instance.startListeningToOrders(FirestoreService(), this);
        }
      } else {
        debugPrint('[AUTH] User profile not found for UID: ${firebaseUser.uid}');
        _currentUser = null;
        _loadError = 'User profile not found for UID: ${firebaseUser.uid}';
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AUTH] _startUserDocListener exception: $e');
      _currentUser = null;
      _loadError = e.toString();
      _isLoading = false;
      notifyListeners();
      return;
    }

    _userDocSubscription = _db.collection('users').doc(firebaseUser.uid).snapshots().listen(
      (doc) {
        if (_activeUid != firebaseUser.uid || _auth.currentUser?.uid != firebaseUser.uid) {
          return;
        }

        if (doc.exists && doc.data() != null) {
          _currentUser = AppUser.fromMap(doc.data()!, doc.id);
          _loadError = null;
          _isLoading = false;
          notifyListeners();
          NotificationService.instance.startListeningToOrders(FirestoreService(), this);
        }
      },
      onError: (e) {
        debugPrint('[AUTH] Firestore snapshot error for UID ${firebaseUser.uid}: $e');
        if (_activeUid == firebaseUser.uid) {
          _currentUser = null;
          _loadError = e.toString();
          _isLoading = false;
          notifyListeners();
        }
      },
    );
  }

  Future<void> fetchUserRole(dynamic userOrUid) async {
    notifyListeners();
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
    _signingIn = true;
    _isLoading = true;
    _loadError = null;
    notifyListeners();

    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user;
      if (user != null) {
        final allowed = await canEnter(user);
        debugPrint('[AUTH] sign-in uid=${user.uid} allowed=$allowed');
        if (!allowed) {
          await _auth.signOut();
          _currentUser = null;
          _hasActiveSession = false;
          throw Exception('Please time in with your RFID card at the device before signing in.');
        }
        _hasActiveSession = true;
        await _startUserDocListener(user);
      }
    } catch (e) {
      _hasActiveSession = false;
      _loadError = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _signingIn = false;
      _isLoading = false;
      notifyListeners();
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
    String? address,
    String? gender,
    String? emergencyContact,
  }) async {
    _registering = true;
    _isLoading = true;
    _loadError = null;
    notifyListeners();
    User? newlyCreatedAuthUser;

    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      newlyCreatedAuthUser = credential.user;

      if (newlyCreatedAuthUser != null) {
        try {
          await newlyCreatedAuthUser.getIdToken(true);
        } catch (_) {}

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
          address: address?.trim() ?? '',
          gender: gender ?? '',
          emergencyContact: emergencyContact?.trim() ?? '',
        );

        try {
          await _db.collection('users').doc(newlyCreatedAuthUser.uid).set(newUserProfile.toMap());
        } catch (e) {
          debugPrint('[AUTH] Initial set failed ($e), retrying set with merge...');
          await Future.delayed(const Duration(milliseconds: 300));
          await _db.collection('users').doc(newlyCreatedAuthUser.uid).set(newUserProfile.toMap(), SetOptions(merge: true));
        }

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
      _registering = false;
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
    _loadError = null;
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

  Future<void> signOut({String? preserveError}) async {
    final err = preserveError ?? _loadError;
    stopShiftWatch();
    await _userDocSubscription?.cancel();
    _userDocSubscription = null;
    NotificationService.instance.stopListening();
    await _auth.signOut();
    _activeUid = null;
    _hasActiveSession = false;
    _currentUser = null;
    _loadError = err;
    notifyListeners();
  }
}
