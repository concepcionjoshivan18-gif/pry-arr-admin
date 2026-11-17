import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/services/auth_service.dart';
import '../core/theme/hardware_theme.dart';
import '../core/components/top_notification.dart';
import '../admin/components/admin_scaffold.dart';
import '../admin/screens/dashboard_screen.dart';
import '../admin/screens/inventory_screen.dart';
import '../admin/screens/payroll_screen.dart';
import '../admin/screens/sales_reports_screen.dart';
import '../admin/screens/accounts_screen.dart';
import '../admin/screens/category_manager_screen.dart';
import '../admin/screens/admin_profile_screen.dart';
import '../admin/screens/admin_feedback_screen.dart';
import '../admin/screens/admin_chat_screen.dart';
import '../admin/screens/pending_payments_screen.dart';
import '../app/screens/login_screen.dart';

class AdminRouter {
  final AuthService authService;

  AdminRouter(this.authService);

  late final GoRouter router = GoRouter(
    refreshListenable: authService,
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(showRegister: false),
      ),
      GoRoute(
        path: '/error',
        builder: (context, state) {
          final auth = Provider.of<AuthService>(context);
          final roleText = auth.currentUser?.role;
          final errorMsg = auth.loadError ?? (roleText != null ? 'Role not recognized: $roleText' : 'User profile error');
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      errorMsg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => confirmAndSignOut(context, auth),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign Out'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          final themeController = Provider.of<ThemeController>(context);
          return Pal(
            dark: themeController.dark,
            child: AdminScaffold(currentRoute: state.matchedLocation, body: child),
          );
        },
        routes: [
          GoRoute(
            path: '/admin/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/admin/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/admin/pending-payments',
            builder: (context, state) => const PendingPaymentsScreen(),
          ),
          GoRoute(
            path: '/admin/payroll',
            builder: (context, state) => const PayrollScreen(),
          ),
          GoRoute(
            path: '/admin/sales',
            builder: (context, state) => const SalesReportsScreen(),
          ),
          GoRoute(
            path: '/admin/accounts',
            builder: (context, state) => const AccountsScreen(),
          ),
          GoRoute(
            path: '/admin/categories',
            builder: (context, state) => const CategoryManagerScreen(),
          ),
          GoRoute(
            path: '/admin/profile',
            builder: (context, state) => const AdminProfileScreen(),
          ),
          GoRoute(
            path: '/admin/feedback',
            builder: (context, state) => const AdminFeedbackScreen(),
          ),
          GoRoute(
            path: '/admin/chat',
            builder: (context, state) => const AdminChatScreen(),
          ),
          GoRoute(
            path: '/admin/products', // Redirect old route to new inventory
            builder: (context, state) => const InventoryScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';
      final isErrorRoute = state.matchedLocation == '/error';

      if (authService.loadError != null) {
        if (state.matchedLocation == '/login') return null;
        return '/login';
      }

      bool isLoggedOut = false;
      try {
        if (Firebase.apps.isNotEmpty) {
          isLoggedOut = FirebaseAuth.instance.currentUser == null;
        }
      } catch (_) {}

      if (isLoggedOut) {
        return state.matchedLocation == '/login' ? null : '/login';
      }

      if (authService.isLoading) {
        return null;
      }

      final user = authService.currentUser;
      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (user.role.toLowerCase() != 'admin') {
        return isErrorRoute ? null : '/error';
      }

      if (isLoggingIn) {
        return '/admin/dashboard';
      }

      return null;
    },
  );
}
