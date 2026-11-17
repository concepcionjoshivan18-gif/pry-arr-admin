import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'core/components/boot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StorefrontRoot());
}

class StorefrontRoot extends StatefulWidget {
  const StorefrontRoot({super.key});

  @override
  State<StorefrontRoot> createState() => _StorefrontRootState();
}

class _StorefrontRootState extends State<StorefrontRoot> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BootScreen(
          steps: [
            BootStep(
              label: 'Connecting to server...',
              weight: 3,
              run: () async {
                if (Firebase.apps.isEmpty) {
                  await Firebase.initializeApp(
                    options: DefaultFirebaseOptions.currentPlatform,
                  );
                }
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                if (kIsWeb) {
                  try {
                    FirebaseFirestore.instance.settings =
                        const Settings(persistenceEnabled: false);
                  } catch (_) {
                    // Naitakda na, ituloy lang
                  }
                } else {
                  try {
                    FirebaseFirestore.instance.settings = const Settings(
                      persistenceEnabled: true,
                      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
                    );
                  } catch (_) {}
                }
              },
            ),
            BootStep(
              label: 'Loading notifications...',
              weight: 1,
              run: () async {
                try {
                  await NotificationService.instance.initialize();
                } catch (_) {}
              },
            ),
            BootStep(
              label: 'Checking session...',
              weight: 2,
              run: () async {
                await FirebaseAuth.instance.authStateChanges().first;
              },
            ),
          ],
          onDone: () => setState(() => _ready = true),
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService(target: AppTarget.storefront)),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: const PryArrStorefrontApp(),
    );
  }
}

class PryArrStorefrontApp extends StatelessWidget {
  final AuthService? authService;
  const PryArrStorefrontApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    if (authService != null) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService!),
          Provider<FirestoreService>(create: (_) => FirestoreService()),
          ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
          ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
        ],
        child: const StorefrontMaterialEntry(),
      );
    }
    return const StorefrontMaterialEntry();
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
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: hwOrange, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF8F5F0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: hwOrange, brightness: Brightness.dark),
        scaffoldBackgroundColor: hwCharcoal,
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
