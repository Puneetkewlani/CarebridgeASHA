import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_selection_page.dart';
import 'login_view.dart';
import 'phc_login_view.dart';
import 'register_view.dart';
import 'homepage.dart';
import 'pages/phc_dashboard.dart';  
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/role-selection': (context) => const RoleSelectionPage(),
        '/login': (context) => const LoginView(),
        '/phc-login': (context) => const PHCLoginView(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(),
        '/asha-dashboard': (context) => const HomePage(),
        '/phc-dashboard': (context) => const PHCDashboard(),
      },
    );
  }
}

/// Checks if user is already logged in and redirects accordingly
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFA8FBD3),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF31326F),
              ),
            ),
          );
        }

        // User is logged in - check their role
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<Widget>(
            future: _determineUserDashboard(snapshot.data!.uid),
            builder: (context, dashboardSnapshot) {
              if (dashboardSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFFA8FBD3),
                  body: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF31326F),
                    ),
                  ),
                );
              }

              if (dashboardSnapshot.hasError) {
                print('Error determining dashboard: ${dashboardSnapshot.error}');
                // If error, log out and show role selection
                FirebaseAuth.instance.signOut();
                return const RoleSelectionPage();
              }

              return dashboardSnapshot.data ?? const RoleSelectionPage();
            },
          );
        }

        // No user logged in - show role selection
        return const RoleSelectionPage();
      },
    );
  }

  /// Determine which dashboard to show based on user type
  Future<Widget> _determineUserDashboard(String uid) async {
    try {
      // Check if user is ASHA worker
      final ashaDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (ashaDoc.exists) {
        print('✅ ASHA user found - redirecting to ASHA dashboard');
        return const HomePage();
      }

      // Check if user is PHC staff
      final phcDoc = await FirebaseFirestore.instance
          .collection('phc_staff')
          .doc(uid)
          .get();

      if (phcDoc.exists) {
        print('✅ PHC staff found - redirecting to PHC dashboard');
        return const PHCDashboard();
      }

      // User exists in Firebase Auth but not in either collection
      print('⚠️ User authenticated but no profile found - logging out');
      await FirebaseAuth.instance.signOut();
      return const RoleSelectionPage();

    } catch (e) {
      print('❌ Error checking user type: $e');
      await FirebaseAuth.instance.signOut();
      return const RoleSelectionPage();
    }
  }
}
