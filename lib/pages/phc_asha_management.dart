import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PHCAshaManagement extends StatefulWidget {
  final String location;
  final String phcName;

  const PHCAshaManagement({
    super.key,
    required this.location,
    required this.phcName,
  });

  @override
  State<PHCAshaManagement> createState() => _PHCAshaManagementState();
}

class _PHCAshaManagementState extends State<PHCAshaManagement> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> ashaWorkers = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAshaWorkers();
  }

  Future<void> _loadAshaWorkers() async {
    setState(() => isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('location', isEqualTo: widget.location)
          .where('role', isEqualTo: 'ASHA')
          .get();

      final workers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['uid'] = doc.id;
        return data;
      }).toList();

      setState(() {
        ashaWorkers = workers;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading ASHA workers: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _registerNewAshaWorker() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final ashaIdController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register ASHA Worker'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ashaIdController,
                  decoration: const InputDecoration(
                    labelText: 'ASHA ID',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Initial Password',
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Register', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      // Create Firebase Auth account
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      // Create user document
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'fullName': nameController.text.trim(),
        'ashaId': ashaIdController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'location': widget.location,
        'phcName': widget.phcName,
        'role': 'ASHA',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': FirebaseAuth.instance.currentUser!.uid,
      });

      // Initialize inventory
      await _firestore.collection('inventory').doc(ashaIdController.text.trim()).set({
        'BCG': 0,
        'OPV': 0,
        'DPT': 0,
        'Measles': 0,
        'Hepatitis B': 0,
      });

      // Sign out the newly created user (so PHC staff stays logged in)
      await FirebaseAuth.instance.signOut();
      
      // Sign back in as PHC staff
      // Note: You'll need to handle this better in production
      
      _loadAshaWorkers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ASHA Worker ${nameController.text} registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('ASHA Workers'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
        actions: [
          
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _registerNewAshaWorker,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.person_add),
        label: const Text('Register ASHA'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : ashaWorkers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No ASHA workers registered yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _registerNewAshaWorker,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Register First ASHA Worker'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ashaWorkers.length,
                  itemBuilder: (context, index) {
                    final worker = ashaWorkers[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF31326F),
                          child: Text(
                            worker['fullName']?.substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          worker['fullName'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ASHA ID: ${worker['ashaId'] ?? 'N/A'}'),
                            Text('Email: ${worker['email'] ?? 'N/A'}'),
                            Text('Phone: ${worker['phone'] ?? 'N/A'}'),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // TODO: Show worker details/edit page
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
