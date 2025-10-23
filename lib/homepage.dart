import 'package:care_bridge/pages/appointments_by_date_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:care_bridge/pages/visit_log_page.dart';
import 'package:care_bridge/pages/inventory_page.dart';
import 'package:care_bridge/pages/pending_requests_page.dart';
import 'package:care_bridge/pages/accepted_requests_page.dart';
import 'package:care_bridge/pages/weekly_record_page.dart';
import 'package:care_bridge/pages/add_schedule_page.dart';
import 'package:care_bridge/widgets/stat_card.dart';
import 'package:care_bridge/widgets/appointment_card.dart';
import 'package:care_bridge/services/appointment_archiver.dart';
import 'pages/asha_notifications_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String fullName = 'Loading...';
  String ashaId = 'Loading...';
  String _email = '';
  int todayTotalVisits = 0;
  int todayDoneVisits = 0;
  int weeklyVaccinated = 0;
  int pendingVisits = 0;
  double inventoryPercent = 0.0;
  List<Map<String, dynamic>> todayAppointments = [];
  Map<String, int> vaccineStock = {};
  bool isRefreshing = false;  // ✅ Loading state

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => _email = user.email ?? '');

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        setState(() {
          fullName = data['fullName'] ?? 'Unknown';
          ashaId = data['ashaId'] ?? 'Unknown';
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fullName', fullName);
        await prefs.setString('ashaId', ashaId);
        
        await AppointmentArchiver.checkAndArchive(ashaId);
        
        _loadDashboardData();
      }
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        fullName = prefs.getString('fullName') ?? 'Offline User';
        ashaId = prefs.getString('ashaId') ?? 'N/A';
      });
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    if (ashaId == 'Loading...' || ashaId == 'Unknown') return;

    setState(() => isRefreshing = true);  // ✅ Start loading

    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    try {
      final apptSnapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('date', isEqualTo: todayStr)
          .get();

      final appts = apptSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort: Pending first, then done
      appts.sort((a, b) {
        final aStatus = a['status'] ?? 'pending';
        final bStatus = b['status'] ?? 'pending';
        if (aStatus == 'pending' && bStatus == 'done') return -1;
        if (aStatus == 'done' && bStatus == 'pending') return 1;
        return 0;
      });

      final doneCount = appts.where((a) => a['status'] == 'done').length;
      final pendingCount = appts.where((a) => a['status'] != 'done').length;

      final visitsSnapshot = await _firestore
          .collection('visits')
          .where('ashaId', isEqualTo: ashaId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek.add(const Duration(days: 1))))
          .get();

      final completedApptSnapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'done')
          .get();

      final thisWeekCompleted = completedApptSnapshot.docs.where((doc) {
        final data = doc.data();
        final dateStr = data['date'] as String?;
        if (dateStr == null) return false;
        
        try {
          final apptDate = DateTime.parse(dateStr);
          final startDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          final endDate = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
          return apptDate.isAfter(startDate.subtract(const Duration(days: 1))) && 
                 apptDate.isBefore(endDate.add(const Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).length;

      final weeklyCount = visitsSnapshot.docs.length + thisWeekCompleted;

      final invDoc = await _firestore.collection('inventory').doc(ashaId).get();
      Map<String, int> stock = {};
      if (invDoc.exists) {
        final data = invDoc.data()!;
        stock = Map<String, int>.from(data.map((k, v) => MapEntry(k, v is int ? v : 0)));
      }

      final totalStock = stock.values.fold(0, (sum, val) => sum + val);
      final maxStock = stock.length * 50;
      final percent = maxStock > 0 ? (totalStock / maxStock) * 100 : 0.0;

      setState(() {
        todayAppointments = appts;
        todayTotalVisits = appts.length;
        todayDoneVisits = doneCount;
        pendingVisits = pendingCount;
        weeklyVaccinated = weeklyCount;
        vaccineStock = stock;
        inventoryPercent = percent;
        isRefreshing = false;  // ✅ Stop loading
      });
    } catch (e) {
      print('Dashboard load error: $e');
      setState(() => isRefreshing = false);  // ✅ Stop loading on error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _markComplete(String appointmentId, String vaccination) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Complete?'),
        content: const Text('Are you sure you want to mark this appointment as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes, Mark Complete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('appointments').doc(appointmentId).update({
        'status': 'done',
        'completedAt': FieldValue.serverTimestamp(),
      });

      final invDoc = await _firestore.collection('inventory').doc(ashaId).get();
      if (invDoc.exists) {
        final stock = Map<String, int>.from(invDoc.data()!.map((k, v) => MapEntry(k, v is int ? v : 0)));
        final currentStock = stock[vaccination] ?? 0;
        if (currentStock > 0) {
          stock[vaccination] = currentStock - 1;
          await _firestore.collection('inventory').doc(ashaId).update(stock);
        }
      }

      _loadDashboardData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Appointment marked as complete!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking complete: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Appointment?'),
        content: const Text(
          'This will permanently delete this appointment. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _firestore.collection('appointments').doc(appointmentId).delete();
      _loadDashboardData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Appointment deleted'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('ASHA Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
        actions: [
  // ✅ Notification Bell with Badge
  // ✅ Notification Bell with Error Handling
StreamBuilder<QuerySnapshot>(
  stream: _auth.currentUser != null 
      ? FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: _auth.currentUser!.uid)
          .where('read', isEqualTo: false)
          .snapshots()
      : null,
  builder: (context, snapshot) {
    // Handle errors silently (index not ready yet)
    if (snapshot.hasError) {
      return IconButton(
        icon: const Icon(Icons.notifications_outlined),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AshaNotificationsPage(),
            ),
          );
        },
        tooltip: 'Notifications',
      );
    }
    
    final unreadCount = snapshot.data?.docs.length ?? 0;
    
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AshaNotificationsPage(),
              ),
            );
          },
          tooltip: 'Notifications',
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  },
),

  
  // Refresh Button
  IconButton(
    icon: isRefreshing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : const Icon(Icons.refresh),
    onPressed: isRefreshing ? null : _loadDashboardData,
    tooltip: 'Refresh Dashboard',
  ),
  
  // Logout Button
  IconButton(
    icon: const Icon(Icons.logout),
    onPressed: () async {
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
        await _auth.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    },
    tooltip: 'Logout',
  ),
],

      ),
      body: Stack(
        children: [
          // Main content
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Info Card
                Card(
                  color: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Color(0xFF31326F),
                          child: Icon(Icons.person, size: 35, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ASHA ID: $ashaId',
                                style: const TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                              Text(
                                _email,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Grid
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    StatCard(
                      title: 'Today\'s Visits',
                      value: todayTotalVisits.toString(),
                      icon: Icons.calendar_today,
                      color: const Color(0xFF637AB9),
                    ),
                    StatCard(
                      title: 'Completed',
                      value: todayDoneVisits.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green,
                    ),
                    StatCard(
                      title: 'Pending',
                      value: pendingVisits.toString(),
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),
                    StatCard(
                      title: 'Weekly Vaccinated',
                      value: weeklyVaccinated.toString(),
                      icon: Icons.vaccines,
                      color: const Color(0xFF4FB7B3),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Inventory Status Card
                Card(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Inventory Status',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: inventoryPercent / 100,
                          backgroundColor: Colors.grey[300],
                          color: inventoryPercent > 50 ? Colors.green : Colors.red,
                          minHeight: 10,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${inventoryPercent.toStringAsFixed(1)}% stocked',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF31326F)),
                ),
                const SizedBox(height: 12),
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton('Visit Log', Icons.history, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => VisitLogPage(ashaId: ashaId)),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton('Inventory', Icons.inventory, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => InventoryPage(ashaId: ashaId)),
                            ).then((_) => _loadDashboardData());
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton('Requests', Icons.inbox, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PendingRequestsPage(ashaId: ashaId)),
                            ).then((_) => _loadDashboardData());
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton('Accepted', Icons.check_box, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AcceptedRequestsPage(ashaId: ashaId)),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton('Weekly Record', Icons.bar_chart, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => WeeklyRecordPage(ashaId: ashaId)),
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton('View by Date', Icons.date_range, () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppointmentsByDatePage(
                                  ashaId: ashaId,
                                  fullName: fullName,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFullWidthActionButton('Add Schedule', Icons.add_circle, () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddSchedulePage(
                            ashaId: ashaId,
                            fullName: fullName,
                          ),
                        ),
                      );
                      if (result == true) {
                        _loadDashboardData();
                      }
                    }),
                  ],
                ),
                const SizedBox(height: 20),

                // Today's Appointments
                const Text(
                  'Today\'s Appointments',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF31326F)),
                ),
                const SizedBox(height: 12),
                todayAppointments.isEmpty
                    ? Card(
                        color: Colors.white,
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.event_busy, size: 60, color: Colors.grey[400]),
                                const SizedBox(height: 12),
                                Text(
                                  'No appointments for today',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap "Add Schedule" to create new appointments',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: todayAppointments.length,
                        itemBuilder: (context, index) {
                          final appt = todayAppointments[index];
                          return AppointmentCard(
                            appointment: appt,
                            onMarkComplete: () => _markComplete(appt['id'], appt['vaccination'] ?? 'Unknown'),
                            onDelete: () => _deleteAppointment(appt['id']),
                          );
                        },
                      ),
              ],
            ),
          ),
          
          // ✅ FULL-SCREEN LOADING OVERLAY
          if (isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.green,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF31326F),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 70,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF31326F), Color(0xFF637AB9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
