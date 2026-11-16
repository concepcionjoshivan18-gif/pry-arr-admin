import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/hardware_theme.dart';
import 'hover_sidebar.dart';

class AdminScaffold extends StatelessWidget {
  final Widget body;
  final String currentRoute;

  const AdminScaffold({super.key, required this.body, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final authService = Provider.of<AuthService>(context);
    final themeController = Provider.of<ThemeController>(context);
    final p = Pal.of(context);

    if (!isDesktop) {
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

    return Pal(
      dark: themeController.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            const Positioned.fill(child: Background()),
            // Body with 80px left padding for the floating collapsed HoverSidebar
            Padding(
              padding: const EdgeInsets.only(left: 80),
              child: body,
            ),
            // HoverSidebar floats over the left edge
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
