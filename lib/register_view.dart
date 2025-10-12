import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_view.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _ashaIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _obscurePassword = true;  // ✅ ADDED
  bool _obscureConfirmPassword = true;  // ✅ ADDED

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ashaIdController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final ashaId = _ashaIdController.text.trim();  // ✅ REMOVED .toUpperCase()
    final fullName = _fullNameController.text.trim();

    // Extra checks
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    // ✅ REMOVED ASHA ID format restriction

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check for duplicate ASHA ID
      final querySnapshot = await _firestore
          .collection('users')
          .where('ashaId', isEqualTo: ashaId)
          .limit(1)
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'ASHA ID already registered. Please login.';
          _isLoading = false;
        });
        return;
      }

      // Create Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        // Try create Firestore doc
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'fullName': fullName,
            'ashaId': ashaId,
            'email': email,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Firestore doc created successfully');
        } catch (fsError) {
          print('Firestore create skipped (offline/billing?): $fsError');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('fullName', fullName);
          await prefs.setString('ashaId', ashaId);
        }

        // Success: redirect to login
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registered successfully! Please log in.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = e.message ?? 'Registration failed');
    } catch (e) {
      setState(() => _errorMessage = 'An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                  const Icon(
                    Icons.health_and_safety,
                    size: 80,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Register for Carebridge ASHA',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Full Name Field
                  TextFormField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.person, color: Colors.green),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z\s]+$'))
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // ASHA ID Field (NO RESTRICTIONS)
                  TextFormField(
                    controller: _ashaIdController,
                    decoration: InputDecoration(
                      labelText: 'ASHA ID *',  // ✅ SIMPLIFIED
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.badge, color: Colors.green),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      helperText: 'Enter your unique ASHA identifier',  // ✅ UPDATED
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your ASHA ID';
                      }
                      // ✅ REMOVED format validation
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.email, color: Colors.green),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field with Show/Hide Button
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,  // ✅ CHANGED
                    decoration: InputDecoration(
                      labelText: 'Password *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      suffixIcon: IconButton(  // ✅ ADDED
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Confirm Password Field with Show/Hide Button
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,  // ✅ CHANGED
                    decoration: InputDecoration(
                      labelText: 'Confirm Password *',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.green),
                      suffixIcon: IconButton(  // ✅ ADDED
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  
                  // Error Message Display
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  // Register Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Register',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Login Link
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginView()),
                    ),
                    child: const Text(
                      'Already have an account? Login',
                      style: TextStyle(color: Colors.green),
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
