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
import 'routing/admin_router.dart';
import 'core/theme/hardware_theme.dart';
import 'core/components/boot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminRoot());
}

class AdminRoot extends StatefulWidget {
  const AdminRoot({super.key});

  @override
  State<AdminRoot> createState() => _AdminRootState();
}

class _AdminRootState extends State<AdminRoot> {
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
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService(target: AppTarget.admin)),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: const PryArrAdminApp(),
    );
  }
}

class PryArrAdminApp extends StatelessWidget {
  const PryArrAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminMaterialEntry();
  }
}

class AdminMaterialEntry extends StatefulWidget {
  const AdminMaterialEntry({super.key});

  @override
  State<AdminMaterialEntry> createState() => _AdminMaterialEntryState();
}

class _AdminMaterialEntryState extends State<AdminMaterialEntry> {
  late AdminRouter _adminRouter;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _adminRouter = AdminRouter(authService);
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);
    
    return MaterialApp.router(
      title: 'PRY-ARR OMS Admin',
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
      routerConfig: _adminRouter.router,
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
