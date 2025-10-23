import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class PHCSendNotificationPage extends StatefulWidget {
  const PHCSendNotificationPage({super.key});

  @override
  State<PHCSendNotificationPage> createState() => _PHCSendNotificationPageState();
}

class _PHCSendNotificationPageState extends State<PHCSendNotificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String? _selectedAshaId;
  List<Map<String, dynamic>> _ashaWorkers = [];
  String _phcLocation = '';
  bool _isLoading = true;
  bool _isSending = false;
  bool _sendToAll = false;

  @override
  void initState() {
    super.initState();
    _loadAshaWorkers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAshaWorkers() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final phcDoc = await FirebaseFirestore.instance
            .collection('phc_staff')
            .doc(uid)
            .get();
        
        _phcLocation = phcDoc.data()?['location'] ?? '';

        final workersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('location', isEqualTo: _phcLocation)
            .get();

        setState(() {
          _ashaWorkers = workersSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['fullName'] ?? 'Unknown',
                    'ashaId': doc.data()['ashaId'] ?? 'N/A',
                  })
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading ASHA workers: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_sendToAll && _selectedAshaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an ASHA worker'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      if (_sendToAll) {
        // Broadcast to all ASHA workers
        await NotificationService.sendBroadcastNotification(
          location: _phcLocation,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Notification sent to ${_ashaWorkers.length} ASHA workers'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Send to specific ASHA worker
        await NotificationService.sendCustomNotification(
          userId: _selectedAshaId!,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Notification sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Clear form
      _titleController.clear();
      _messageController.clear();
      setState(() {
        _selectedAshaId = null;
        _sendToAll = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Send Notification'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Send Custom Notification',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'To ASHA workers in $_phcLocation',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Send to All Toggle
                    Card(
                      elevation: 2,
                      child: SwitchListTile(
                        title: const Text('Send to All ASHA Workers'),
                        subtitle: Text('${_ashaWorkers.length} workers in $_phcLocation'),
                        value: _sendToAll,
                        onChanged: (value) {
                          setState(() {
                            _sendToAll = value;
                            if (value) _selectedAshaId = null;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Select ASHA Worker (if not sending to all)
                    if (!_sendToAll) ...[
                      const Text(
                        'Select ASHA Worker',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
  elevation: 2,
  child: DropdownButtonFormField<String>(
    decoration: const InputDecoration(
      contentPadding: EdgeInsets.all(16),
      border: InputBorder.none,
      prefixIcon: Icon(Icons.person),
    ),
    hint: const Text('Choose ASHA worker'),
    value: _selectedAshaId,
    items: _ashaWorkers.map<DropdownMenuItem<String>>((worker) {
      return DropdownMenuItem<String>(
        value: worker['id'] as String,
        child: Text('${worker['name']} (${worker['ashaId']})'),
      );
    }).toList(),
    onChanged: (value) {
      setState(() => _selectedAshaId = value);
    },
  ),
),

                      const SizedBox(height: 16),
                    ],

                    // Title
                    const Text(
                      'Notification Title',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter notification title',
                        prefixIcon: const Icon(Icons.title),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Title is required' : null,
                    ),

                    const SizedBox(height: 16),

                    // Message
                    const Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Enter your message here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Message is required' : null,
                    ),

                    const SizedBox(height: 24),

                    // Send Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF31326F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          _isSending ? 'Sending...' : 'Send Notification',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
