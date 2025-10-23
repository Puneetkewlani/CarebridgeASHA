import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'phc_inventory_requests_page.dart';
import 'phc_asha_workers_page.dart';
import 'phc_reports_page.dart';
import 'phc_settings_page.dart';
import 'phc_approved_requests_page.dart';
import 'phc_send_notification_page.dart';


class PHCDashboard extends StatefulWidget {
  const PHCDashboard({super.key});

  @override
  State<PHCDashboard> createState() => _PHCDashboardState();
}

class _PHCDashboardState extends State<PHCDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic> phcData = {};
  bool isLoading = true;
  int pendingRequestsCount = 0;
  int ashaWorkersCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPHCData();
    _loadStats();
  }

  Future<void> _loadPHCData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('phc_staff').doc(uid).get();
        if (doc.exists) {
          setState(() {
            phcData = doc.data()!;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading PHC data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await _firestore.collection('phc_staff').doc(uid).get();
      if (!doc.exists) return;

      final location = doc.data()?['location'] ?? '';

      // Count pending requests
      final requestsSnapshot = await _firestore
          .collection('inventory_requests')
          .where('location', isEqualTo: location)
          .where('status', isEqualTo: 'pending')
          .get();

      // Count ASHA workers
      final workersSnapshot = await _firestore
          .collection('users')
          .where('location', isEqualTo: location)
          .get();

      setState(() {
        pendingRequestsCount = requestsSnapshot.docs.length;
        ashaWorkersCount = workersSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _logout() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Logout', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/role-selection');
    }
  }
}


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFA8FBD3),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('PHC Dashboard'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
        actions: [
         
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF31326F),
                    child: Text(
                      phcData['fullName']?.toString().substring(0, 1).toUpperCase() ?? 'P',
                      style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${phcData['fullName'] ?? 'PHC Admin'}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phcData['phcName'] ?? 'Primary Health Centre',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                        Text(
                          phcData['location'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Pending Requests',
                    pendingRequestsCount.toString(),
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'ASHA Workers',
                    ashaWorkersCount.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Main Menu
            const Text(
              'Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildMenuCard(
              'Inventory Requests',
              'View and approve ASHA inventory requests',
              Icons.inventory,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PHCInventoryRequestsPage()),
                ).then((_) => _loadStats());
              },
            ),

_buildMenuCard(
  'Approved Requests',
  'View history of approved requests',
  Icons.history,
  Colors.green,
  () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PHCApprovedRequestsPage()),
    );
  },
),

            _buildMenuCard(
              'ASHA Workers',
              'Manage ASHA worker accounts',
              Icons.people_alt,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PHCAshaWorkersPage()),
                ).then((_) => _loadStats());
              },
            ),

            _buildMenuCard(
              'Reports',
              'View vaccination and health reports',
              Icons.assessment,
              Colors.green,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PHCReportsPage()),
                );
              },
            ),

            _buildMenuCard(
              'Settings',
              'PHC settings and configuration',
              Icons.settings,
              Colors.purple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PHCSettingsPage()),
                ).then((_) => _loadPHCData());
              },
            ),
            _buildMenuCard(
  'Send Notification',
  'Send custom messages to ASHA workers',
  Icons.notifications_active,
  Colors.blue,
  () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PHCSendNotificationPage()),
    );
  },
),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
