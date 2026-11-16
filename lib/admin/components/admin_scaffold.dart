import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/hardware_theme.dart';
import '../../core/utils/responsive.dart';
import 'hover_sidebar.dart';

class AdminScaffold extends StatelessWidget {
  final Widget body;
  final String currentRoute;

  const AdminScaffold({super.key, required this.body, required this.currentRoute});

  int _getSelectedIndex(String route) {
    if (route.startsWith('/admin/dashboard')) return 0;
    if (route.startsWith('/admin/inventory') || route.startsWith('/admin/categories') || route.startsWith('/admin/products')) return 1;
    if (route.startsWith('/admin/pending-payments')) return 2;
    if (route.startsWith('/admin/sales')) return 3;
    if (route.startsWith('/admin/accounts')) return 4;
    if (route.startsWith('/admin/payroll')) return 5;
    if (route.startsWith('/admin/feedback')) return 6;
    if (route.startsWith('/admin/chat')) return 7;
    if (route.startsWith('/admin/profile')) return 8;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeController = Provider.of<ThemeController>(context);
    final p = Pal.of(context);

    if (Breakpoints.isMobile(context)) {
      return Pal(
        dark: themeController.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('PRY-ARR Admin'),
            backgroundColor: p.surface,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: ThemeSwitchWidget(
                  dark: themeController.dark,
                  onToggle: () => themeController.toggleTheme(),
                ),
              ),
            ],
          ),
          drawer: Drawer(
            backgroundColor: p.dark ? const Color(0xFF181C26) : const Color(0xFF1F2430),
            child: HoverSidebar(
              currentRoute: currentRoute,
              onSignOut: () => authService.signOut(),
            ),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: Background()),
              body,
            ],
          ),
        ),
      );
    }

    if (Breakpoints.isTablet(context)) {
      final selectedIndex = _getSelectedIndex(currentRoute);
      return Pal(
        dark: themeController.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const Positioned.fill(child: Background()),
              Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      if (index < HoverSidebar.items.length) {
                        context.go(HoverSidebar.items[index].$3);
                      }
                    },
                    backgroundColor: p.dark ? const Color(0xFF181C26) : const Color(0xFF1F2430),
                    selectedIconTheme: const IconThemeData(color: hwOrange),
                    unselectedIconTheme: const IconThemeData(color: Colors.white70),
                    labelType: NavigationRailLabelType.none,
                    destinations: [
                      for (final item in HoverSidebar.items)
                        NavigationRailDestination(
                          icon: Icon(item.$2),
                          label: Text(item.$1),
                        ),
                    ],
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                            onPressed: () => authService.signOut(),
                            tooltip: 'Sign Out',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop
    return Pal(
      dark: themeController.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: Background()),
            Padding(
              padding: const EdgeInsets.only(left: 80),
              child: body,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: HoverSidebar(
                currentRoute: currentRoute,
                onSignOut: () => authService.signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
