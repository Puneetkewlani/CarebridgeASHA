import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'register_view.dart';
import 'homepage.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    print('=== _login() STARTED ===');
    if (_formKey.currentState!.validate()) {
      print('Validation passed - Proceeding to login');
      setState(() => _isLoading = true);
      final emailInput = _emailController.text.trim().toLowerCase();
      print('Login attempt: Email = $emailInput');
      
      try {
        print('Attempting signInWithEmailAndPassword...');
        await _auth.signInWithEmailAndPassword(
          email: emailInput,
          password: _passwordController.text,
        );
        print('Sign-in successful - Navigating to /home');
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on FirebaseAuthException catch (e) {
        print('FirebaseAuthException: Code=${e.code}, Message=${e.message}');
        String errorMsg = 'Login failed: ${e.message}';
        
        if (e.code == 'user-not-found') {
          errorMsg = 'No account found with this email. Please register first.';
        } else if (e.code == 'wrong-password') {
          errorMsg = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          errorMsg = 'Invalid email format. Please check your email.';
        } else if (e.code == 'user-disabled') {
          errorMsg = 'This account has been disabled. Contact support.';
        } else if (e.code == 'network-request-failed') {
          errorMsg = 'Network error. Please check your internet connection.';
        }
        
        _showSnackBar(errorMsg, Colors.red);
      } catch (e) {
        print('General catch: $e');
        _showSnackBar('Unexpected error. Please restart and try again.', Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
        print('=== _login() ENDED ===');
      }
    } else {
      print('Validation FAILED - _login() exited early');
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    print('Showing snackbar: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    }
  }

  Future<void> _forgotPassword() async {
    print('Forgot password dialog opened');
    final TextEditingController forgotController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot Password?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your email to receive a password reset link.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: forgotController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.isEmpty) {
                  return 'Enter your email';
                }
                if (!trimmed.contains('@')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final forgotEmail = forgotController.text.trim().toLowerCase();
              if (forgotEmail.isEmpty || !forgotEmail.contains('@')) {
                _showSnackBar('Please enter a valid email.', Colors.orange);
                return;
              }
              
              try {
                await _auth.sendPasswordResetEmail(email: forgotEmail);
                _showSnackBar('Reset link sent to $forgotEmail. Check your inbox/spam.', Colors.green);
                Navigator.pop(context);
              } on FirebaseAuthException catch (e) {
                String msg = 'Reset failed: ${e.message}';
                if (e.code == 'user-not-found') {
                  msg = 'No account found with this email.';
                } else if (e.code == 'invalid-email') {
                  msg = 'Invalid email format.';
                }
                _showSnackBar(msg, Colors.red);
              } catch (e) {
                print('Forgot error: $e');
                _showSnackBar('Reset unavailable. Please try again later.', Colors.red);
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  String? _emailValidator(String? value) {
    print('Email Validator called: Raw value="$value"');
    final trimmed = (value ?? '').trim();
    print('Email Validator: Trimmed="$trimmed"');
    
    if (trimmed.isEmpty) {
      print('Email Validator: Empty - Error');
      return 'Enter your email';
    }
    
    if (!trimmed.contains('@') || !trimmed.contains('.')) {
      print('Email Validator: Invalid format - Error');
      return 'Enter a valid email';
    }
    
    print('Email Validator: Passed');
    return null;
  }

  String? _passwordValidator(String? value) {
    print('Password Validator: Raw="$value"');
    if ((value ?? '').trim().isEmpty) {
      print('Password Validator: Empty - Error');
      return 'Enter your password';
    }
    print('Password Validator: Passed');
    return null;
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
                  // ✅ ADDED: Icon at top to match register page
                  const Icon(
                    Icons.health_and_safety,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  // ✅ CHANGED: Updated text style to match register
                  const Text(
                    'Login to Carebridge ASHA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.email, color: Colors.green), // ✅ CHANGED: Green icon
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.green), // ✅ CHANGED: Green icon
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: _passwordValidator,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.green, fontSize: 14), // ✅ CHANGED: Green color
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        print('=== LOGIN BUTTON PRESSED ===');
                        _login();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // ✅ CHANGED: Green button
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Login',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      print('Register button pressed - Navigating');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      "Don't have an account? Register",
                      style: TextStyle(color: Colors.green), // ✅ CHANGED: Green color
                    ),
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
