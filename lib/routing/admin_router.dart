import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/services/auth_service.dart';
import '../core/theme/hardware_theme.dart';
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
    initialLocation: '/admin/dashboard',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(showRegister: false),
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
      final user = authService.currentUser;
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final isLoggingIn = state.matchedLocation == '/login';

      // Preserve current route during web refresh while Firebase Auth or Firestore profile is loading
      if (authService.isLoading || (user == null && firebaseUser != null)) {
        return null;
      }

      if (user == null && firebaseUser == null) {
        return isLoggingIn ? null : '/login';
      }

      if (user?.role != 'admin') {
        // Strict boundary: lock out non-admins entirely from admin panel web target
        return '/login';
      }

      if (isLoggingIn) {
        return '/admin/dashboard';
      }

      return null;
    },
  );
}
