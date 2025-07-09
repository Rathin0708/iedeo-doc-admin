import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iedeo_doc_admin/screens/side_nav_pages.dart';
import 'package:provider/provider.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_login.dart';
import 'services/admin_auth_service.dart';
import 'services/admin_firebase_service.dart';
import 'screens/setting_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDQLUHTHhGq468a11gW76aF27CKY04r8Hk",
      authDomain: "iedeo-43e6a.firebaseapp.com",
      projectId: "iedeo-43e6a",
      storageBucket: "iedeo-43e6a.firebasestorage.app",
      messagingSenderId: "439628553649",
      appId: "1:439628553649:web:3abb2a062255426a44b190",
      measurementId: "G-4B041WFCZV",
    ),
  );

  // Configure Firestore
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true, // Enable offline persistence
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Try to enable network, but don't fail if it doesn't work
    try {
      await FirebaseFirestore.instance.enableNetwork();
      if (kDebugMode) {
        print('🔥 Admin Firebase initialized successfully with network');
      }
    } catch (networkError) {
      print('⚠️ Admin Firebase network initialization warning: $networkError');
      print('🔄 Admin Firebase running in offline mode');
    }
  } catch (e) {
    print('⚠️ Admin Firebase configuration warning: $e');
    print('🔄 Admin Firebase using default settings');
  }

  runApp(IdeoAdminApp());
}

class IdeoAdminApp extends StatelessWidget {
  const IdeoAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminAuthService()),
        ChangeNotifierProvider(create: (_) => AdminFirebaseService()),
      ],
      child: MaterialApp(
        title: 'Ideo Health Admin Panel',
        debugShowCheckedModeBanner: false,
        routes: {
          '/dashboard': (_) => const AdminDashboard(),
          '/patients': (_) => const PatientsScreen(),
          '/visits': (_) => const VisitsScreen(),
          '/users': (_) => const UsersScreen(),
          '/reports': (_) => const ReportsScreen(),
          '/settings': (_) => const SettingsPageWithSidebar(),
        },
        theme: ThemeData(
          primarySwatch: Colors.red,
          useMaterial3: true,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        home: AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAuthService>(
      builder: (context, authService, child) {
        if (authService.isAuthenticated) {
          return AdminDashboard();
        } else {
          // Always show login screen
          return AdminLogin();
        }
      },
    );
  }
}