import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PHCApprovedRequestsPage extends StatefulWidget {
  const PHCApprovedRequestsPage({super.key});

  @override
  State<PHCApprovedRequestsPage> createState() => _PHCApprovedRequestsPageState();
}

class _PHCApprovedRequestsPageState extends State<PHCApprovedRequestsPage> {
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

  Stream<QuerySnapshot> _getApprovedRequests() {
    if (phcLocation.isEmpty) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('inventory_requests')
        .where('location', isEqualTo: phcLocation)
        .where('status', isEqualTo: 'approved')
        .orderBy('approvedAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Approved Requests'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
      ),
      body: phcLocation.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _getApprovedRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final requests = snapshot.data?.docs ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No Approved Requests',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Approved requests will appear here',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final doc = requests[index];
                    final request = doc.data() as Map<String, dynamic>;
                    final approvedAt = (request['approvedAt'] as Timestamp?)?.toDate();
                    final approvedBy = request['approvedBy'] as String?;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        request['vaccineName'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'By ${request['ashaName'] ?? 'Unknown'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'APPROVED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            const Divider(height: 24),
                            
                            // Details
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoTile(
                                    'Quantity',
                                    '${request['quantity']} units',
                                    Icons.numbers,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoTile(
                                    'Location',
                                    request['location'] ?? 'N/A',
                                    Icons.location_on,
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Approval Info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  FutureBuilder<DocumentSnapshot>(
                                    future: approvedBy != null 
                                        ? _firestore.collection('phc_staff').doc(approvedBy).get()
                                        : null,
                                    builder: (context, staffSnapshot) {
                                      final staffName = staffSnapshot.data?.data() != null
                                          ? (staffSnapshot.data!.data() as Map<String, dynamic>)['fullName']
                                          : 'Unknown';
                                      
                                      return Row(
                                        children: [
                                          const Icon(Icons.person, size: 16, color: Colors.green),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Approved by: ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            staffName ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Approved on: ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      Text(
                                        approvedAt != null
                                            ? '${approvedAt.day}/${approvedAt.month}/${approvedAt.year} at ${approvedAt.hour}:${approvedAt.minute.toString().padLeft(2, '0')}'
                                            : 'Unknown',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
