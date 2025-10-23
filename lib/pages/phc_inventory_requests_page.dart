import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';


class PHCInventoryRequestsPage extends StatefulWidget {
  const PHCInventoryRequestsPage({super.key});

  @override
  State<PHCInventoryRequestsPage> createState() => _PHCInventoryRequestsPageState();
}

class _PHCInventoryRequestsPageState extends State<PHCInventoryRequestsPage> {
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

  Stream<QuerySnapshot> _getInventoryRequests() {
    if (phcLocation.isEmpty) {
      return const Stream.empty();
    }
    
    return _firestore
        .collection('inventory_requests')
        .where('location', isEqualTo: phcLocation)
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<void> _approveRequest(String requestId, String ashaId, String vaccineName, int quantity) async {
  try {
    await _firestore.collection('inventory_requests').doc(requestId).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    final inventoryRef = _firestore.collection('inventory').doc(ashaId);
    await inventoryRef.update({
      vaccineName: FieldValue.increment(quantity),
    });

    // ✅ Send notification
    await NotificationService.sendRequestApprovedNotification(
      ashaId: ashaId,
      vaccineName: vaccineName,
      quantity: quantity,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Approved $quantity units of $vaccineName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  Future<void> _rejectRequest(String requestId, String ashaId, String vaccineName) async {
  try {
    await _firestore.collection('inventory_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
    });

    // ✅ Send notification
    await NotificationService.sendRequestRejectedNotification(
      ashaId: ashaId,
      vaccineName: vaccineName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Request rejected'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
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
        title: const Text('Inventory Requests'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
      ),
      body: phcLocation.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _getInventoryRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final requests = snapshot.data?.docs ?? [];
                final pendingRequests = requests.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == 'pending';
                }).toList();

                if (pendingRequests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'No Pending Requests',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All inventory requests have been processed',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final doc = pendingRequests[index];
                    final request = doc.data() as Map<String, dynamic>;
                    final requestId = doc.id;
                    final timestamp = (request['requestedAt'] as Timestamp?)?.toDate();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
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
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.inventory, color: Colors.orange, size: 24),
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
                                        'Requested by ${request['ashaName'] ?? 'Unknown'}',
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
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'PENDING',
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
                            
                            if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
                              _buildInfoTile(
                                'Reason',
                                request['reason'],
                                Icons.info_outline,
                              ),
                              const SizedBox(height: 12),
                            ],
                            
                            _buildInfoTile(
                              'Requested On',
                              timestamp != null 
                                  ? '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'
                                  : 'Unknown',
                              Icons.access_time,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showRejectDialog(
  requestId,
  request['ashaId'],
  request['vaccineName'],
),

                                    icon: const Icon(Icons.close),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showApproveDialog(
                                      requestId,
                                      request['ashaId'],
                                      request['vaccineName'],
                                      request['quantity'],
                                    ),
                                    icon: const Icon(Icons.check),
                                    label: const Text('Approve'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
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

  void _showApproveDialog(String requestId, String ashaId, String vaccineName, int quantity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Text('Approve $quantity units of $vaccineName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveRequest(requestId, ashaId, vaccineName, quantity);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String requestId, String ashaId, String vaccineName) {

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: const Text('Are you sure you want to reject this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectRequest(requestId, ashaId, vaccineName);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
