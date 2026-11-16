import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import '../core/models/inventory_item.dart';
import '../core/theme/hardware_theme.dart';

// Import storefront client screens
import '../app/screens/login_screen.dart';
import '../app/screens/catalog_screen.dart';
import '../app/screens/product_detail_screen.dart';
import '../app/screens/cart_screen.dart';
import '../app/screens/checkout_screen.dart';
import '../app/screens/order_history_screen.dart';

// Import administrative panels
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
import '../admin/screens/order_manager_screen.dart';

class AppRouter {
  final AuthService authService;

  AppRouter(this.authService);

  // Compile-time configuration switch via environment variable
  static const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'both');

  late final GoRouter router = GoRouter(
    refreshListenable: authService,
    initialLocation: _determineInitialLocation(),
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      
      // Storefront Customer Bundle
      if (appMode != 'admin') ...[
        GoRoute(
          path: '/catalog',
          builder: (context, state) => const CatalogScreen(),
        ),
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final inventoryItem = state.extra as InventoryItem?;
            final id = state.pathParameters['id'] ?? '';
            return ProductDetailScreen(inventoryItem: inventoryItem, productId: id);
          },
        ),
        GoRoute(
          path: '/cart',
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (context, state) => const OrderHistoryScreen(),
        ),
      ],

      // Staff Administrative Bundle
      if (appMode != 'customer') ...[
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
              path: '/admin/products',
              builder: (context, state) => const InventoryScreen(),
            ),
            GoRoute(
              path: '/admin/orders',
              builder: (context, state) => const OrderManagerScreen(),
            ),
          ],
        ),
      ],
    ],
    redirect: (context, state) {
      final user = authService.currentUser;
      final isLoggingIn = state.matchedLocation == '/login';

      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return user.role == 'admin' ? '/admin/dashboard' : '/catalog';
      }

      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (isAdminRoute && user.role != 'admin') {
        return '/catalog';
      }
      if (!isAdminRoute && user.role == 'admin' && state.matchedLocation == '/') {
        return '/admin/dashboard';
      }

      return null;
    },
  );

  String _determineInitialLocation() {
    if (appMode == 'admin') return '/admin/dashboard';
    if (appMode == 'customer') return '/catalog';
    return '/catalog';
  }
}
