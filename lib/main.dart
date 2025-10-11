import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';  // Generate with 'flutterfire configure' if missing
import 'login_view.dart';  // Your LoginView (ASHA ID login)
import 'register_view.dart';  // Register page (create with code below if missing)
import 'homepage.dart';  // Fixed HomePage (from previous response; ensures context scoping)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASHA Vaccine Tracker',
      theme: ThemeData(
        primarySwatch: Colors.green,  // Matches your app's primary color (0xFFA8FBD3)
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',  // Starts on your LoginView
      routes: {
        '/login': (context) => const LoginView(),  // Your ASHA ID login page
        '/home': (context) => const HomePage(),  // Dashboard (matches your Navigator.pushReplacementNamed('/home'))
        '/register': (context) => const RegisterView(),  // Register page (for signup flow)
      },
      debugShowCheckedModeBanner: false,  // Clean screen; check console for errors
    );
  }
}
