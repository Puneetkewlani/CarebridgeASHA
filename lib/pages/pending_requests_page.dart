import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingRequestsPage extends StatefulWidget {
  final String ashaId;

  const PendingRequestsPage({super.key, required this.ashaId});

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, int> currentStock = {};
  List<String> pendingVaccines = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentStock();
    _loadPendingRequests();
  }

  Future<void> _loadCurrentStock() async {
    try {
      final invDoc = await _firestore.collection('inventory').doc(widget.ashaId).get();
      if (invDoc.exists) {
        setState(() {
          currentStock = Map<String, int>.from(
            invDoc.data()!.map((k, v) => MapEntry(k, v is int ? v : 0))
          );
        });
      }
    } catch (e) {
      print('Error loading stock: $e');
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final snapshot = await _firestore
          .collection('inventory_requests')
          .where('ashaId', isEqualTo: widget.ashaId)
          .where('status', isEqualTo: 'pending')
          .get();

      setState(() {
        pendingVaccines = snapshot.docs
            .map((doc) => doc.data()['vaccineName'] as String)
            .toList();
      });
    } catch (e) {
      print('Error loading pending: $e');
    }
  }

  // ✅ Get vaccines from inventory that need restocking and have no pending requests
  List<String> get availableVaccines {
    return currentStock.entries
        .where((entry) => 
          entry.value < 50 && // Stock less than 50
          !pendingVaccines.contains(entry.key) // No pending request
        )
        .map((entry) => entry.key)
        .toList();
  }

  Stream<QuerySnapshot> _getPendingRequests() {
    return _firestore
        .collection('inventory_requests')
        .where('ashaId', isEqualTo: widget.ashaId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Future<void> _deleteRequest(String requestId) async {
    try {
      await _firestore.collection('inventory_requests').doc(requestId).delete();
      await _loadPendingRequests(); // Refresh available vaccines
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request cancelled'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: Colors.orange,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequestDialog(),
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }

          final requests = snapshot.data?.docs ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text('No pending requests', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showRequestDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
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
              final requestId = doc.id;
              final timestamp = (request['requestedAt'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            request['vaccineName'] ?? 'Unknown',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'PENDING',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Quantity: ${request['quantity']} units', style: const TextStyle(fontSize: 16)),
                      if (request['reason'] != null && request['reason'].toString().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Reason: ${request['reason']}', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        timestamp != null ? 'Requested: ${timestamp.day}/${timestamp.month}/${timestamp.year}' : 'Requested: Unknown',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Waiting for PHC approval...', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.w500)),
                          ),
                          TextButton.icon(
                            onPressed: () => _deleteRequest(requestId),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
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

  void _showRequestDialog() {
  String? selectedVaccine;
  int quantity = 10;
  String reason = '';

  // Check if there are any vaccines available to request
  if (availableVaccines.isEmpty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700]),
            const SizedBox(width: 8),
            const Text('All Set!'),
          ],
        ),
        content: Text(
          pendingVaccines.isNotEmpty
              ? 'You have pending requests for:\n${pendingVaccines.join(', ')}\n\nWait for approval before requesting more.'
              : 'All vaccines have 50 or more units in stock!\n\nYou can only request vaccines when stock is below 50.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final currentQty = selectedVaccine != null ? (currentStock[selectedVaccine] ?? 0) : 0;
        final maxQty = 50 - currentQty;

        return AlertDialog(
          title: const Text('Request Inventory'),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
               maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedVaccine,
                    decoration: const InputDecoration(
                      labelText: 'Select Vaccine',
                      border: OutlineInputBorder(),
                      helperText: 'Only vaccines needing restock',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: availableVaccines.map((v) {
                      final stock = currentStock[v] ?? 0;
                      final needed = 50 - stock;
                      return DropdownMenuItem(
                        value: v,
                        child: Text('$v (Stock: $stock, Need: $needed)'),
                      );
                    }).toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedVaccine = v;
                      if (v != null) {
                        quantity = 50 - (currentStock[v] ?? 0);
                      }
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (selectedVaccine != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Current: $currentQty | Max: $maxQty units',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    key: ValueKey(selectedVaccine),
                    initialValue: selectedVaccine != null ? maxQty.toString() : '10',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: const OutlineInputBorder(),
                      helperText: selectedVaccine != null ? 'Max: $maxQty units' : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) => quantity = int.tryParse(v) ?? 10,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Reason (optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) => reason = v,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedVaccine == null) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please select a vaccine')),
                  );
                  return;
                }

                if (quantity <= 0) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Quantity must be greater than 0')),
                  );
                  return;
                }

                if (quantity > maxQty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Max $maxQty units allowed (to reach 50 total)')),
                  );
                  return;
                }

                // Get user details
                final userSnapshot = await _firestore
                    .collection('users')
                    .where('ashaId', isEqualTo: widget.ashaId)
                    .limit(1)
                    .get();

                final userData = userSnapshot.docs.isNotEmpty 
                    ? userSnapshot.docs.first.data() 
                    : {};

                // Submit request
                await _firestore.collection('inventory_requests').add({
                  'ashaId': widget.ashaId,
                  'ashaName': userData['fullName'] ?? 'ASHA Worker',
                  'location': userData['location'] ?? 'Unknown',
                  'vaccineName': selectedVaccine,
                  'quantity': quantity,
                  'reason': reason.trim(),
                  'status': 'pending',
                  'requestedAt': FieldValue.serverTimestamp(),
                });

                // Reload pending requests
                await _loadPendingRequests();

                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text('✅ Request for $selectedVaccine submitted!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }

                // Reset form
                setDialogState(() {
                  selectedVaccine = null;
                  quantity = 10;
                  reason = '';
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    ),
  );
}
}
