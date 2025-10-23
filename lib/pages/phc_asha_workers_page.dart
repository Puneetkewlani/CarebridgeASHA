import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'phc_register_asha_page.dart';

class PHCAshaWorkersPage extends StatefulWidget {
  const PHCAshaWorkersPage({super.key});

  @override
  State<PHCAshaWorkersPage> createState() => _PHCAshaWorkersPageState();
}

class _PHCAshaWorkersPageState extends State<PHCAshaWorkersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String phcLocation = '';

  @override
  void initState() {
    super.initState();
    _loadPHCLocation();
  }

  Future<void> _loadPHCLocation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('phc_staff').doc(uid).get();
        if (doc.exists) {
          setState(() {
            phcLocation = doc.data()?['location'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading location: $e');
    }
  }

  Stream<QuerySnapshot> _getAshaWorkers() {
    if (phcLocation.isEmpty) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('users')
        .where('location', isEqualTo: phcLocation)
        .snapshots();
  }

  void _navigateToRegister() async {
    if (phcLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait, loading location...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PHCRegisterAshaPage(phcLocation: phcLocation),
      ),
    );

    // Refresh if registration was successful
    if (result == true && mounted) {
      setState(() {}); // Trigger rebuild to refresh stream
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToRegister,
        backgroundColor: const Color(0xFF31326F),
        icon: const Icon(Icons.person_add),
        label: const Text('Register ASHA'),
      ),
      body: phcLocation.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _getAshaWorkers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final workers = snapshot.data?.docs ?? [];

                if (workers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No ASHA Workers',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Register ASHA workers for your area',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _navigateToRegister,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Register First ASHA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF31326F),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: workers.length,
                  itemBuilder: (context, index) {
                    final doc = workers[index];
                    final worker = doc.data() as Map<String, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF637AB9),
                          child: Text(
                            worker['fullName']?.toString().substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          worker['fullName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.badge, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('ID: ${worker['ashaId'] ?? 'N/A'}'),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.email, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    worker['email'] ?? 'No email',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (worker['phoneNumber'] != null) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(worker['phoneNumber']),
                                ],
                              ),
                            ],
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showWorkerDetails(worker),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  void _showWorkerDetails(Map<String, dynamic> worker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(worker['fullName'] ?? 'ASHA Worker'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ASHA ID', worker['ashaId'] ?? 'N/A'),
              _buildDetailRow('Email', worker['email'] ?? 'N/A'),
              _buildDetailRow('Phone', worker['phoneNumber'] ?? 'N/A'),
              _buildDetailRow('Location', worker['location'] ?? 'N/A'),
              if (worker['createdAt'] != null) ...[
                const Divider(height: 24),
                _buildDetailRow(
                  'Registered',
                  _formatTimestamp(worker['createdAt'] as Timestamp),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
