import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ashaIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _ashaIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    print('=== Registration Debug Start ==='); // Trace entry
    if (_formKey.currentState!.validate()) {
      print('Form validation passed'); // Inputs OK
      if (_passwordController.text != _confirmPasswordController.text) {
        print('Error: Passwords mismatch'); // Mismatch
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Passwords do not match')),
          );
        }
        return;
      }
      print('Passwords match'); // Ready for auth
      bool authSuccess = false;
      bool writeSuccess = false;
      try {
        print('Calling createUserWithEmailAndPassword...'); // Before auth
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        print('Auth success! UID: ${userCredential.user?.uid}, Email: ${userCredential.user?.email}'); // Auth OK
        authSuccess = true;
        if (userCredential.user != null) {
          print('Updating displayName to: ${_fullNameController.text.trim()}'); // Before display
          await userCredential.user!.updateDisplayName(_fullNameController.text.trim());
          print('DisplayName updated'); // Display OK
          try {
            print('Calling Firestore set with ASHA ID: ${_ashaIdController.text.trim()}'); // Before write
            await _firestore.collection('users').doc(userCredential.user!.uid).set({
              'fullName': _fullNameController.text.trim(),
              'email': _emailController.text.trim(),
              'ashaId': _ashaIdController.text.trim(),
              'role': 'normal',
              'createdAt': FieldValue.serverTimestamp(),
            });
            print('Firestore write success! ASHA ID stored.'); // Write OK
            writeSuccess = true;
          } catch (writeError) {
            print('Firestore write failed: $writeError'); // Write error details
            // No return—continue to redirect
          }
          print('Signing out...'); // Before signout
          await _auth.signOut();
          print('Sign out complete'); // Signout OK
        }
      } on FirebaseAuthException catch (authError) {
        print('Auth exception: Code=${authError.code}, Message=${authError.message}'); // Auth error code
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Auth failed: ${authError.message ?? 'Unknown'} (${authError.code})')),
          );
        }
        // Force redirect on auth error for user feedback
        _forceRedirect();
        return;
      } catch (generalError) {
        print('General registration error: $generalError'); // Catch-all
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $generalError')),
          );
        }
        _forceRedirect(); // Ensure redirect
        return;
      }

      // Success path: Show message and redirect
      if (authSuccess) {
        if (mounted) {
          String msg = writeSuccess 
            ? 'Registration successful! Please log in.' 
            : 'Auth OK, but profile (ASHA ID) failed. Please log in and retry.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
          );
          print('Showing success message and redirecting'); // Before nav
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        print('Auth failed—no redirect'); // Fallback
      }
    } else {
      print('Form validation failed—check inputs'); // Invalid form
    }
    print('=== Registration Debug End ==='); // Trace exit
  }

  void _forceRedirect() { // Helper for errors
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.pink[50]!, Colors.cyan[100]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Register',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your email';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value ?? '')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your full name';
                      if ((value ?? '').length < 2) return 'Full name must be at least 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ashaIdController,
                    decoration: InputDecoration(
                      labelText: 'ASHA ID (Government Registered)',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your ASHA ID';
                      if ((value ?? '').length < 8 || !RegExp(r'^[A-Z]{4}-\d{4}$').hasMatch(value ?? '')) {
                        return 'ASHA ID must be e.g., ASHA-4567';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Enter your password';
                      if ((value ?? '').length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Confirm your password';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Register', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView())),
                    child: const Text('Already have an account? Login', style: TextStyle(color: Colors.purple)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
