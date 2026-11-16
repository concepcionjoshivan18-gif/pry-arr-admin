import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'routing/admin_router.dart';
import 'core/theme/hardware_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    }
  } catch (e) {
    debugPrint('Firebase init: $e');
  }

  try {
    await NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Notification init: $e');
  }

  runApp(const PryArrAdminApp());
}

class PryArrAdminApp extends StatelessWidget {
  final AuthService? authService;
  const PryArrAdminApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
          value: authService ?? AuthService(target: AppTarget.admin),
        ),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: const AdminMaterialEntry(),
    );
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
