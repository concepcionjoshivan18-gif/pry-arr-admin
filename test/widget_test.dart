// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pry_arr/core/services/auth_service.dart';
import 'package:pry_arr/core/models/app_user.dart';
import 'package:pry_arr/main_storefront.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  AppUser? get currentUser => null;

  @override
  bool get isLoading => false;

  @override
  String? get loadError => null;

  @override
  bool get hasActiveSession => false;

  @override
  AppTarget get target => AppTarget.storefront;

  @override
  Future<void> signOut({String? preserveError}) async {}

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {}

  @override
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
  }) async {}

  @override
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
  }) async {}

  @override
  Future<void> fetchUserRole(userOrUid) async {}

  @override
  void updateLocalUser(Map<String, dynamic> data) {}

  @override
  Future<bool> isEmailAlreadyInUse(String email) async => false;
}

void main() {
  testWidgets('PRY-ARR Storefront smoke test', (WidgetTester tester) async {
    final mockAuth = MockAuthService();
    // Build our app and trigger a frame.
    await tester.pumpWidget(PryArrStorefrontApp(authService: mockAuth));
    await tester.pump();
  });
}
