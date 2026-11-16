import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/services/auth_service.dart';
import '../core/models/order.dart';
import '../core/models/inventory_item.dart';
import '../core/models/cart_item.dart';
import '../app/screens/login_screen.dart';
import '../app/screens/register_screen.dart';
import '../app/screens/landing_screen.dart';
import '../app/screens/catalog_screen.dart';
import '../app/screens/product_detail_screen.dart';
import '../app/screens/cart_screen.dart';
import '../app/screens/checkout_screen.dart';
import '../app/screens/order_history_screen.dart';
import '../staff/screens/order_list_screen.dart';
import '../staff/screens/order_detail_screen.dart';
import '../staff/screens/inventory_view_screen.dart';
import '../staff/screens/staff_profile_screen.dart';
import '../staff/screens/attendance_screen.dart';
import '../staff/screens/staff_payroll_screen.dart';
import '../staff/screens/driver_dashboard_screen.dart';
import '../staff/screens/walkin_counter_screen.dart';
import '../admin/screens/pending_payments_screen.dart';
import '../app/components/curved_nav_bar.dart';
import '../app/screens/account_screen.dart';
import '../core/theme/hardware_theme.dart';

class StorefrontRouter {
  final AuthService authService;

  StorefrontRouter(this.authService);

  late final GoRouter router = GoRouter(
    refreshListenable: authService,
    initialLocation: '/landing',
    routes: [
      GoRoute(
        path: '/landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // DRIVER DASHBOARD
      GoRoute(
        path: '/driver/deliveries',
        builder: (context, state) {
          final themeController = Provider.of<ThemeController>(context);
          return Pal(
            dark: themeController.dark,
            child: const DriverDashboardScreen(),
          );
        },
      ),

      // CUSTOMER DASHBOARD (Shell)
      ShellRoute(
        builder: (context, state, child) {
          final themeController = Provider.of<ThemeController>(context);
          return Pal(
            dark: themeController.dark,
            child: CustomerScaffold(child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/customer/catalog',
            builder: (context, state) => const CatalogScreen(),
          ),
          GoRoute(
            path: '/customer/product/:id',
            pageBuilder: (context, state) {
              final item = state.extra as InventoryItem?;
              return CustomTransitionPage(
                key: state.pageKey,
                child: ProductDetailScreen(productId: state.pathParameters['id'] ?? '', inventoryItem: item),
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 250),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.08),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                    child: FadeTransition(
                      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                      child: child,
                    ),
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/customer/cart',
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: '/customer/account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: '/customer/checkout',
            builder: (context, state) {
              final buyNowItems = state.extra as List<CartItem>?;
              return CheckoutScreen(buyNowItems: buyNowItems);
            },
          ),
          GoRoute(
            path: '/customer/orders',
            builder: (context, state) => const OrderHistoryScreen(),
          ),
          GoRoute(
            path: '/customer/profile',
            builder: (context, state) => const StaffProfileScreen(),
          ),
        ],
      ),

      // STAFF DASHBOARD (Shell)
      ShellRoute(
        builder: (context, state, child) {
          final themeController = Provider.of<ThemeController>(context);
          return Pal(
            dark: themeController.dark,
            child: StaffScaffold(child: child),
          );
        },
        routes: [
          GoRoute(
            path: '/staff/orders',
            builder: (context, state) => const OrderListScreen(),
          ),
          GoRoute(
            path: '/staff/pending-payments',
            builder: (context, state) => const PendingPaymentsScreen(),
          ),
          GoRoute(
            path: '/staff/walkin',
            builder: (context, state) => const WalkInCounterScreen(),
          ),
          GoRoute(
            path: '/staff/order/:id',
            builder: (context, state) {
              final o = state.extra as OrderModel;
              return OrderDetailScreen(order: o);
            },
          ),
          GoRoute(
            path: '/staff/inventory',
            builder: (context, state) => const InventoryViewScreen(),
          ),
          GoRoute(
            path: '/staff/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/staff/profile',
            builder: (context, state) => const StaffProfileScreen(),
          ),
          GoRoute(
            path: '/staff/payroll',
            builder: (context, state) => const StaffPayrollScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      if (authService.isLoading || (authService.hasActiveSession && authService.currentUser == null)) {
        return null;
      }

      final user = authService.currentUser;
      final isLanding = state.matchedLocation == '/landing' || state.matchedLocation == '/';
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // Unauthenticated users land on /landing (and can navigate to /login or /register)
      if (!authService.hasActiveSession || user == null) {
        if (state.matchedLocation.startsWith('/customer/checkout')) {
          return null;
        }
        return (isLanding || isLoggingIn || isRegistering) ? null : '/landing';
      }

      if (user.status == 'Inactive') return '/login';

      // Driver Role Redirection
      if (user.isDriver) {
        if (isLanding || isLoggingIn || isRegistering) {
          return '/driver/deliveries';
        }
        if (!state.matchedLocation.startsWith('/driver') && !state.matchedLocation.startsWith('/staff/payroll')) {
          return '/driver/deliveries';
        }
        return null;
      }

      if (isLanding || isLoggingIn) {
        if (user.role.toLowerCase() == 'staff') return '/staff/orders';
        return '/customer/catalog';
      }

      final isStaffRoute = state.matchedLocation.startsWith('/staff');
      final isCustomerRoute = state.matchedLocation.startsWith('/customer');

      if (isStaffRoute && user.role.toLowerCase() != 'staff') return '/customer/catalog';
      if (isCustomerRoute && user.role.toLowerCase() != 'customer') return '/staff/orders';

      return null;
    },
  );
}

class CustomerScaffold extends StatefulWidget {
  final Widget child;
  const CustomerScaffold({super.key, required this.child});

  @override
  State<CustomerScaffold> createState() => CustomerScaffoldState();

  static CustomerScaffoldState? of(BuildContext context) {
    return context.findAncestorStateOfType<CustomerScaffoldState>();
  }
}

class CustomerScaffoldState extends State<CustomerScaffold> {
  final GlobalKey cartKey = GlobalKey();

  void triggerFlyToCart(GlobalKey startKey, IconData icon) {
    final renderBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final cartRenderBox = cartKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null || cartRenderBox == null) return;

    final startPosition = renderBox.localToGlobal(Offset.zero);
    final endPosition = cartRenderBox.localToGlobal(Offset.zero);

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => FlyAnimationWidget(
        start: startPosition + Offset(renderBox.size.width / 2, renderBox.size.height / 2),
        end: endPosition + Offset(cartRenderBox.size.width / 2, cartRenderBox.size.height / 2),
        icon: icon,
        onComplete: () {
          overlayEntry.remove();
          if (mounted) setState(() {});
        },
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int currentIndex = 0;
    if (location.startsWith('/customer/cart')) currentIndex = 1;
    if (location.startsWith('/customer/account') || location.startsWith('/customer/orders') || location.startsWith('/customer/profile')) currentIndex = 2;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom),
              child: widget.child,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CurvedNavBar(
              currentIndex: currentIndex,
              cartKey: cartKey,
              onTabSelected: (index) {
                if (index == 0) {
                  context.go('/customer/catalog');
                } else if (index == 1) {
                  context.go('/customer/cart');
                } else if (index == 2) {
                  context.go('/customer/account');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StaffScaffold extends StatelessWidget {
  final Widget child;
  const StaffScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    int index = 0;
    if (location.startsWith('/staff/walkin')) index = 1;
    if (location.startsWith('/staff/inventory')) index = 2;
    if (location.startsWith('/staff/attendance')) index = 3;
    if (location.startsWith('/staff/profile') || location.startsWith('/staff/payroll')) index = 4;

    final p = Pal.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(bottom: 80 + MediaQuery.of(context).padding.bottom),
              child: child,
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 12),
              child: Glass(
                radius: 32.5,
                child: SizedBox(
                  height: 65,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStaffTab(context, 0, Icons.list_alt_rounded, 'Fulfillment', index == 0, p),
                      _buildStaffTab(context, 1, Icons.point_of_sale_rounded, 'POS', index == 1, p),
                      _buildStaffTab(context, 2, Icons.inventory_2_rounded, 'Stock', index == 2, p),
                      _buildStaffTab(context, 3, Icons.alarm_rounded, 'Attendance', index == 3, p),
                      _buildStaffTab(context, 4, Icons.person_outline_rounded, 'Me', index == 4, p),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTab(BuildContext context, int idx, IconData icon, String label, bool active, Pal p) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (idx == 0) context.go('/staff/orders');
        if (idx == 1) context.go('/staff/walkin');
        if (idx == 2) context.go('/staff/inventory');
        if (idx == 3) context.go('/staff/attendance');
        if (idx == 4) context.go('/staff/profile');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: active ? hwOrange : p.sub),
          const SizedBox(height: 2),
          Text(label, style: ts(active ? hwOrange : p.sub, 10, active ? FontWeight.w800 : FontWeight.w500)),
        ],
      ),
    );
  }
}
