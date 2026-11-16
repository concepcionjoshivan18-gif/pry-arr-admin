import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/providers/cart_provider.dart';
import 'routing/storefront_router.dart';
import 'core/theme/hardware_theme.dart';
import 'services/shift_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    await NotificationService.instance.initialize();
    // Ensure mobile phone app always opens to the login page first on launch
    stopShiftWatch();
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Firebase init: $e');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: const PryArrStorefrontApp(),
    ),
  );
}

class PryArrStorefrontApp extends StatelessWidget {
  const PryArrStorefrontApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => const StorefrontMaterialEntry(),
    );
  }
}

class StorefrontMaterialEntry extends StatefulWidget {
  const StorefrontMaterialEntry({super.key});

  @override
  State<StorefrontMaterialEntry> createState() => _StorefrontMaterialEntryState();
}

class _StorefrontMaterialEntryState extends State<StorefrontMaterialEntry> {
  late StorefrontRouter _storefrontRouter;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _storefrontRouter = StorefrontRouter(authService);
    // Ensure storefront lands on login screen on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authService.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp.router(
      title: 'PRY-ARR Hardware',
      debugShowCheckedModeBanner: false,
      themeMode: themeController.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: hwOrange, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: hwOrange, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.transparent,
      ),
      routerConfig: _storefrontRouter.router,
      builder: (context, child) {
        return Pal(
          dark: themeController.dark,
          child: ChangeNotifierProvider.value(
            value: themeController,
            child: Stack(
              children: [
                const Positioned.fill(child: Background()),
                if (child != null) child,
              ],
            ),
          ),
         );
      },
    );
  }
}
