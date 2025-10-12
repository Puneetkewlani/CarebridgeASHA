import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> acceptedRequests = [];
  List<Map<String, dynamic>> visitLogs = [];

  final List<String> vaccines = [
    'BCG', 'OPV-0', 'Hep B-0',
    'OPV-1', 'Pentavalent-1', 'Rotavirus-1', 'PCV-1',
    'OPV-2', 'Pentavalent-2', 'Rotavirus-2', 'PCV-2',
    'OPV-3', 'Pentavalent-3', 'Rotavirus-3', 'PCV-3', 'IPV-1',
    'Measles-1', 'JE-1',
    'DPT Booster-1', 'OPV Booster', 'Measles-2', 'JE-2',
  ];

  bool _isLoading = true;
  bool _firestoreEnabled = false;
  bool _isOffline = false;

  static const int maxStockPerVaccine = 50;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null) _email = user.email ?? '';
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      setState(() => _isLoading = false);
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isOffline = false;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          fullName = data['fullName'] ?? prefs.getString('fullName') ?? _email.split('@')[0].replaceAll('.', ' ');
          ashaId = data['ashaId'] ?? prefs.getString('ashaId') ?? '';
        });
        await prefs.setString('fullName', fullName);
        await prefs.setString('ashaId', ashaId);
        _firestoreEnabled = true;
        print('Firestore user load: $ashaId');
      } else {
        final storedAsha = prefs.getString('ashaId');
        final storedName = prefs.getString('fullName');
        if (storedAsha != null && storedAsha.isNotEmpty) {
          await _firestore.collection('users').doc(user.uid).set({
            'fullName': storedName ?? _email.split('@')[0].replaceAll('.', ' '),
            'ashaId': storedAsha,
            'email': _email,
            'role': 'user',
            'createdAt': FieldValue.serverTimestamp(),
          });
          setState(() {
            fullName = storedName ?? _email.split('@')[0].replaceAll('.', ' ');
            ashaId = storedAsha;
          });
          await prefs.setString('fullName', fullName);
          await prefs.setString('ashaId', ashaId);
          _firestoreEnabled = true;
          print('Firestore user created: $ashaId');
        } else {
          _showSnackBar('User data missing. Please re-register.', isError: true);
          if (mounted) Navigator.pushReplacementNamed(context, '/register');
          return;
        }
      }
      await Future.wait([
        _loadAppointments(),
        _loadInventory(),
        _loadRequests(),
        _loadWeeklyVaccinated(),
        _loadVisitLogs(),
      ]);
    } catch (e) {
      print('Load error: $e');
      _isOffline = true;
      setState(() {
        fullName = prefs.getString('fullName') ?? _email.split('@')[0].replaceAll('.', ' ');
        ashaId = prefs.getString('ashaId') ?? '';
        if (ashaId.isEmpty) ashaId = 'TEMP-${math.Random().nextInt(1000)}';
        todayTotalVisits = 0;
        todayDoneVisits = 0;
        pendingVisits = 0;
        weeklyVaccinated = 0;
        inventoryPercent = 50.0 + math.Random().nextDouble() * 30;
        todayAppointments = [];
        pendingRequests = [];
        acceptedRequests = [];
        visitLogs = [];
        vaccineStock = {for (var v in vaccines) v: 25 + math.Random().nextInt(26)};
      });
      if (e.toString().contains('PERMISSION_DENIED')) {
        _showSnackBar('Check rules—data load denied.', isError: true);
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadVisitLogs() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) {
      setState(() => visitLogs = []);
      return;
    }
    try {
      final now = DateTime.now();
      final startOfWeek = now.weekday == 7 
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday));
      
      print('Loading visit logs from: $startOfWeek (Sunday)');
      
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      final logs = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final completedAt = data['completedAt'] as Timestamp?;
        final dateStr = data['date'] as String?;
        
        DateTime? appointmentDate;
        if (completedAt != null) {
          appointmentDate = completedAt.toDate();
        } else if (dateStr != null) {
          try {
            appointmentDate = DateTime.parse(dateStr);
          } catch (e) {
            print('Error parsing date: $dateStr');
          }
        }
        
        if (appointmentDate != null && 
            appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
          logs.add(data..['id'] = doc.id);
        }
      }
      
      logs.sort((a, b) {
        final aTime = (a['completedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b['completedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      print('Visit logs: ${logs.length} completed appointments this week (since Sunday)');
      
      setState(() {
        visitLogs = logs;
      });
    } catch (e) {
      print('Visit logs error: $e');
      setState(() => visitLogs = []);
    }
  }

  Future<void> _loadAppointments() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) {
      setState(() {
        todayTotalVisits = 0;
        todayDoneVisits = 0;
        pendingVisits = 0;
        todayAppointments = [];
      });
      return;
    }
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      print('Loading appointments for date: $today');
      
      final allSnapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('date', isEqualTo: today)
          .get();
      final allToday = allSnapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
      
      final pendingSnapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('date', isEqualTo: today)
          .where('status', isEqualTo: 'pending')
          .get();
      
      setState(() {
        todayAppointments = pendingSnapshot.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
        todayTotalVisits = allToday.length;
        pendingVisits = todayAppointments.length;
        todayDoneVisits = todayTotalVisits - pendingVisits;
      });
      
      print('Today ($today): Total=$todayTotalVisits, Done=$todayDoneVisits, Pending=$pendingVisits');
    } catch (e) {
      print('Appointments error: $e');
      setState(() {
        todayTotalVisits = 0;
        todayDoneVisits = 0;
        pendingVisits = 0;
        todayAppointments = [];
      });
    }
  }

  Future<void> _loadInventory() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) {
      setState(() {
        vaccineStock = {for (var v in vaccines) v: maxStockPerVaccine};
        inventoryPercent = 100.0;
      });
      return;
    }
    try {
      final doc = await _firestore.collection('inventory').doc(ashaId).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data() ?? {});
        setState(() {
          vaccineStock = {};
          int totalStock = 0;
          for (var vaccine in vaccines) {
            final stock = (data[vaccine] as int? ?? 0).clamp(0, maxStockPerVaccine);
            vaccineStock[vaccine] = stock;
            totalStock += stock;
          }
          final maxPossible = vaccines.length * maxStockPerVaccine;
          inventoryPercent = (totalStock / maxPossible * 100).clamp(0.0, 100.0);
          print('Inventory: ${inventoryPercent.toStringAsFixed(1)}% (Total: $totalStock / $maxPossible)');
        });
      } else {
        await _firestore.collection('inventory').doc(ashaId).set(
          {for (var v in vaccines) v: maxStockPerVaccine},
          SetOptions(merge: true),
        );
        await _loadInventory();
      }
    } catch (e) {
      print('Inventory error: $e');
      setState(() {
        vaccineStock = {for (var v in vaccines) v: 25 + math.Random().nextInt(26)};
        int totalStock = vaccineStock.values.fold(0, (a, b) => a + b);
        inventoryPercent = (totalStock / (vaccines.length * maxStockPerVaccine) * 100).clamp(0.0, 100.0);
      });
    }
  }

  Future<void> _loadRequests() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) {
      setState(() {
        pendingRequests = [];
        acceptedRequests = [];
      });
      return;
    }
    
    try {
      print('📦 Loading requests for ashaId: $ashaId');
      
      final pendingSnap = await _firestore
          .collection('requests')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('📦 Pending requests query returned: ${pendingSnap.docs.length}');
      
      final pendingList = pendingSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        print('📦 Pending: ${data['vaccine']} qty:${data['quantity']}');
        return data;
      }).toList();
      
      pendingList.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      
      setState(() => pendingRequests = pendingList);

      final acceptedSnap = await _firestore
          .collection('requests')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'accepted')
          .get();
      
      print('📦 Accepted requests query returned: ${acceptedSnap.docs.length}');
      
      final acceptedList = acceptedSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      acceptedList.sort((a, b) {
        final aTime = (a['acceptedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTime = (b['acceptedAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      
      setState(() => acceptedRequests = acceptedList);
      
      print('📦 Final: ${pendingRequests.length} pending, ${acceptedRequests.length} accepted');
    } catch (e) {
      print('❌ Requests error: $e');
      print('❌ Error details: ${e.toString()}');
      setState(() {
        pendingRequests = [];
        acceptedRequests = [];
      });
    }
  }

  Future<void> _loadWeeklyVaccinated() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) {
      setState(() => weeklyVaccinated = 0);
      return;
    }
    try {
      final now = DateTime.now();
      final startOfWeek = now.weekday == 7 
          ? DateTime(now.year, now.month, now.day)
          : DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday));
      
      print('📊 Loading weekly vaccinated - Start of week (Sunday): $startOfWeek');
      
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      print('📊 Total completed appointments found: ${snapshot.docs.length}');
      
      int count = 0;
      int withTimestamp = 0;
      int withoutTimestamp = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final completedAt = data['completedAt'] as Timestamp?;
        final dateStr = data['date'] as String?;
        
        DateTime? appointmentDate;
        
        if (completedAt != null) {
          appointmentDate = completedAt.toDate();
          withTimestamp++;
        } else if (dateStr != null) {
          try {
            appointmentDate = DateTime.parse(dateStr);
            withoutTimestamp++;
            print('⚠️ No completedAt for: ${data['childName']} (using date: $dateStr)');
          } catch (e) {
            print('❌ Error parsing date: $dateStr');
          }
        }
        
        if (appointmentDate != null && 
            appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1)))) {
          count++;
        }
      }
      
      print('📊 Weekly count: $count (with timestamp: $withTimestamp, without: $withoutTimestamp)');
      
      setState(() {
        weeklyVaccinated = count;
      });
    } catch (e) {
      print('❌ Weekly error: $e');
      setState(() => weeklyVaccinated = 0);
    }
  }

  // Continue to Part 2...
  // Continuing from Part 1...

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('This will sign you out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      _showSnackBar('Logout failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _navigateToInventory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventoryPage(
          ashaId: ashaId,
          fullName: fullName,
          vaccines: vaccines,
          vaccineStock: vaccineStock,
          onInventoryUpdated: _loadInventory,
          onRequestCreated: _loadRequests,
          firestoreEnabled: _firestoreEnabled,
          isOffline: _isOffline,
        ),
      ),
    );
    await Future.wait([_loadInventory(), _loadRequests()]);
    setState(() {});
  }

  void _navigateToAccepted() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AcceptedRequestsPage(
          acceptedRequests: acceptedRequests,
          onRefresh: _loadRequests,
        ),
      ),
    );
  }

  void _navigateToVisitLog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VisitLogPage(
          ashaId: ashaId,
          visitLogs: visitLogs,
          onRefresh: () => Future.wait([
            _loadAppointments(),
            _loadWeeklyVaccinated(),
            _loadInventory(),
            _loadVisitLogs(),
          ]),
          firestoreEnabled: _firestoreEnabled,
          isOffline: _isOffline,
        ),
      ),
    );
  }

  void _navigateToWeeklyRecord() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WeeklyRecordPage(ashaId: ashaId)),
    );
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final docId = request['id'] as String?;
    if (docId == null || docId.isEmpty) {
      _showSnackBar('Invalid request', isError: true);
      return;
    }

    if (_isOffline) {
      setState(() {
        pendingRequests.removeWhere((r) => r['id'] == docId);
        acceptedRequests.add(request..['status'] = 'accepted');
      });
      _showSnackBar('Accepted locally (sync later)', isError: false);
      return;
    }

    try {
      if (request['type'] == 'vaccine_request' && ashaId.isNotEmpty) {
        final vaccine = request['vaccine'] as String?;
        final quantity = request['quantity'] as int? ?? 0;
        if (vaccine != null && quantity > 0 && vaccines.contains(vaccine)) {
          final currentStock = vaccineStock[vaccine] ?? 0;
          final newStock = currentStock + quantity;
          if (newStock > maxStockPerVaccine) {
            _showSnackBar('Reject: $vaccine would exceed max $maxStockPerVaccine (current $currentStock + $quantity)', isError: true);
            return;
          }
          await _firestore.collection('inventory').doc(ashaId).update({vaccine: FieldValue.increment(quantity)});
          _showSnackBar('$vaccine +$quantity (now $newStock/$maxStockPerVaccine)');
        }
      }

      await _firestore.collection('requests').doc(docId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      await Future.wait([_loadRequests(), _loadInventory()]);
      _showSnackBar('Request accepted!');
    } catch (e) {
      setState(() {
        pendingRequests.removeWhere((r) => r['id'] == docId);
        acceptedRequests.add(request..['status'] = 'accepted');
      });
      _showSnackBar('Accepted locally: $e', isError: false);
    }
  }

  // ✅ NEW METHOD: Delete Request with Confirmation
  Future<void> _deleteRequest(Map<String, dynamic> request) async {
  final docId = request['id'] as String?;
  if (docId == null || docId.isEmpty) {
    _showSnackBar('Invalid request', isError: true);
    return;
  }

  // ✅ Show confirmation dialog FIRST
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Request?'),
      content: Text(
        'Are you sure you want to delete the request for:\n\n'
        'Vaccine: ${request['vaccine'] ?? 'Unknown'}\n'
        'Quantity: ${request['quantity'] ?? 'N/A'} doses\n\n'
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  // ✅ If user cancelled, exit immediately
  if (confirmed != true) return;

  // ✅ User confirmed - now delete from Firestore
  try {
    await _firestore.collection('requests').doc(docId).delete();
    print('✅ Request deleted from Firestore: $docId');
    
    // ✅ Reload requests from Firestore
    await _loadRequests();
    
    // ✅ Update UI
    if (mounted) {
      setState(() {});
    }
    
    _showSnackBar('Request deleted successfully');
  } catch (e) {
    print('❌ Delete request error: $e');
    // ✅ If Firestore fails, at least remove from local state
    setState(() {
      pendingRequests.removeWhere((r) => r['id'] == docId);
    });
    _showSnackBar('Request deleted (local)', isError: false);
  }
}


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'ASHA: $ashaId',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  onPressed: _logout,
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard('Today\'s Visits', '$todayTotalVisits', Icons.calendar_today),
                        _buildStatCard('Done', '$todayDoneVisits', Icons.check_circle),
                        _buildStatCard('Pending', '$pendingVisits', Icons.pending),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard('Weekly Vaccinated', '$weeklyVaccinated', Icons.vaccines),
                        _buildStatCard('Inventory', '${inventoryPercent.toStringAsFixed(0)}%', Icons.inventory),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceEvenly,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToVisitLog,
                        icon: const Icon(Icons.list_alt, size: 24),
                        label: const Text('Visit Log', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          minimumSize: const Size(150, 60),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToInventory,
                        icon: const Icon(Icons.inventory_2, size: 24),
                        label: const Text('Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          minimumSize: const Size(150, 60),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
  child: ElevatedButton.icon(
    onPressed: () => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingRequestsPage(
          ashaId: ashaId,  // ✅ CHANGED: Pass ashaId instead of list
          onAccept: _acceptRequest,
          onRefresh: _loadRequests,
        ),
      ),
    ),

                        icon: const Icon(Icons.pending_actions, size: 24),
                        label: Text('Pending (${pendingRequests.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          minimumSize: const Size(150, 60),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _navigateToAccepted,
                        icon: const Icon(Icons.check_circle, size: 24),
                        label: Text('Accepted (${acceptedRequests.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                          minimumSize: const Size(150, 60),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToWeeklyRecord,
                icon: const Icon(Icons.bar_chart, size: 24, color: Colors.white),
                label: const Text('Weekly Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addSchedule,
                icon: const Icon(Icons.add, size: 24),
                label: const Text('Add Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.today, size: 24, color: Colors.green),
                title: Text('Today\'s Appointments (${todayAppointments.length})', style: const TextStyle(fontSize: 18)),
                children: todayAppointments.isEmpty
                    ? [const Padding(padding: EdgeInsets.all(16), child: Text('No pending appointments today.'))]
                    : [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: todayAppointments.map((apt) {
                              final index = todayAppointments.indexOf(apt);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(apt['childName'] ?? 'Unknown', style: const TextStyle(fontSize: 16)),
                                  subtitle: Text(
                                    'Vaccine: ${apt['vaccination'] ?? 'N/A'}\n'
                                    'Address: ${apt['address'] ?? 'N/A'}\n'
                                    'Phone: ${apt['phone'] ?? 'N/A'}',
                                  ),
                                  leading: const Icon(Icons.pending, color: Colors.orange),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () => _confirmMarkCompleted(index),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        child: const Text('Mark', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 4),
                                      ElevatedButton(
                                        onPressed: () => _confirmDelete(index),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        ),
                                        child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.green),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
        ],
      ),
    );
  }

  // Continue to Part 3...
  // Continuing from Part 2...

  void _confirmMarkCompleted(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Completed?'),
        content: Text('This will deduct inventory and update counts.${_isOffline ? ' (Local only)' : ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markVisit(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAppointment(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSchedule() async {
    if (ashaId == 'Loading...') {
      _showSnackBar('Please wait for load...');
      return;
    }

    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedVaccine;

    final nameFormatter = FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z\s]+$'));

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add New Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  inputFormatters: [nameFormatter],
                  decoration: const InputDecoration(
                    labelText: 'Child Name *',
                    prefixIcon: Icon(Icons.person, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
  controller: ageController,
  inputFormatters: [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(2),  // ✅ ADDED: Limit to 2 digits
  ],
  decoration: const InputDecoration(
    labelText: 'Age (months)',
    prefixIcon: Icon(Icons.child_care, color: Colors.green),
    border: OutlineInputBorder(),
    helperStyle: TextStyle(fontSize: 12, color: Colors.grey),
  ),
  keyboardType: TextInputType.number,
),

                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedVaccine,
                  decoration: const InputDecoration(
                    labelText: 'Vaccine *',
                    prefixIcon: Icon(Icons.vaccines, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                  items: vaccines.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (value) => setDialogState(() => selectedVaccine = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address *',
                    prefixIcon: Icon(Icons.location_on, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone * (10 digits)',
                    prefixIcon: Icon(Icons.phone, color: Colors.green),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final childName = nameController.text.trim();
                final addr = addressController.text.trim();
                final phone = phoneController.text.trim();
                if (childName.isEmpty || selectedVaccine == null || addr.isEmpty || phone.length != 10) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please complete all required fields correctly'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(dialogContext);

                final apt = {
                  'childName': childName,
                  'age': int.tryParse(ageController.text ?? '0') ?? 0,
                  'vaccination': selectedVaccine,
                  'address': addr,
                  'phone': phone,
                  'date': DateTime.now().toIso8601String().split('T')[0],
                  'status': 'pending',
                  'ashaId': ashaId,
                  'fullName': fullName,
                  'createdAt': FieldValue.serverTimestamp(),
                };

                if (!_isOffline) {
                  try {
                    await _firestore.collection('appointments').add(apt);
                    await _loadAppointments();
                    _showSnackBar('Appointment added!');
                  } catch (e) {
                    _addLocalAppointment(apt);
                    _showSnackBar('Added locally: $e', isError: false);
                  }
                } else {
                  _addLocalAppointment(apt);
                  _showSnackBar('Added locally', isError: false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _addLocalAppointment(Map<String, dynamic> apt) {
    setState(() {
      apt['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      todayAppointments.add(apt);
      pendingVisits++;
      todayTotalVisits++;
    });
  }

  Future<void> _markVisit(int index) async {
    final apt = todayAppointments[index];
    final docId = apt['id'] as String?;
    if (docId == null) {
      _showSnackBar('Invalid appointment', isError: true);
      return;
    }

    try {
      print('=== MARKING VISIT ===');
      print('Appointment ID: $docId');
      print('Child: ${apt['childName']}');
      
      await _firestore.collection('appointments').doc(docId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      print('✓ Appointment updated with completedAt timestamp');

      final vaccine = apt['vaccination'] as String?;
      if (vaccine != null && (vaccineStock[vaccine] ?? 0) > 0) {
        await _firestore.collection('inventory').doc(ashaId).update({vaccine: FieldValue.increment(-1)});
        print('✓ Inventory updated for $vaccine');
      }

      print('Waiting for Firestore propagation...');
      await Future.delayed(const Duration(milliseconds: 1000));
      
      print('Reloading all data...');
      await _loadAppointments();
      await _loadInventory();
      await _loadWeeklyVaccinated();
      await _loadVisitLogs();
      
      if (mounted) {
        setState(() {});
      }
      
      print('=== MARK COMPLETE DONE ===');
      _showSnackBar('Visit marked! Weekly count: $weeklyVaccinated');
    } catch (e) {
      print('❌ Error marking visit: $e');
      _markLocalVisit(index);
      _showSnackBar('Marked locally: $e', isError: false);
    }
  }

  void _markLocalVisit(int index) {
    final apt = todayAppointments[index];
    setState(() {
      todayAppointments.removeAt(index);
      pendingVisits--;
      todayDoneVisits++;
      weeklyVaccinated++;
      final vaccine = apt['vaccination'] as String?;
      if (vaccine != null && (vaccineStock[vaccine] ?? 0) > 0) {
        vaccineStock[vaccine] = (vaccineStock[vaccine]! - 1).clamp(0, maxStockPerVaccine);
        int total = vaccineStock.values.fold(0, (a, b) => a + b);
        inventoryPercent = (total / (vaccines.length * maxStockPerVaccine) * 100).clamp(0.0, 100.0);
      }
      visitLogs.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'childName': apt['childName'],
        'vaccination': apt['vaccination'],
        'age': apt['age'],
        'completedAt': Timestamp.now(),
      });
    });
  }

  Future<void> _deleteAppointment(int index) async {
    final apt = todayAppointments[index];
    final docId = apt['id'] as String?;
    if (docId == null) {
      _showSnackBar('Invalid appointment', isError: true);
      return;
    }

    try {
      await _firestore.collection('appointments').doc(docId).delete();
      await _loadAppointments();
      _showSnackBar('Deleted');
    } catch (e) {
      _deleteLocalAppointment(index);
      _showSnackBar('Deleted locally: $e', isError: false);
    }
  }

  void _deleteLocalAppointment(int index) {
    setState(() {
      todayAppointments.removeAt(index);
      pendingVisits--;
      todayTotalVisits--;
    });
  }

  // ONE-TIME FIX METHOD
  Future<void> _fixAllData() async {
    try {
      print('🔧 Starting comprehensive data fix...');
      
      final completedSnap = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      int fixedCompleted = 0;
      for (var doc in completedSnap.docs) {
        final data = doc.data();
        if (data['completedAt'] == null) {
          final dateStr = data['date'] as String?;
          if (dateStr != null) {
            final date = DateTime.parse(dateStr);
            await _firestore.collection('appointments').doc(doc.id).update({
              'completedAt': Timestamp.fromDate(date),
            });
            fixedCompleted++;
            print('✓ Fixed completed: ${data['childName']} on $dateStr');
          }
        }
      }
      
      final today = DateTime.now().toIso8601String().split('T')[0];
      final allTodaySnap = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('date', isEqualTo: today)
          .get();
      
      print('Found ${allTodaySnap.docs.length} appointments for today');
      
      await _loadWeeklyVaccinated();
      await _loadAppointments();
      await _loadRequests();
      await _loadVisitLogs();
      
      print('✅ Fix complete!');
      _showSnackBar('✅ Fixed $fixedCompleted appointments!\nToday: $todayTotalVisits, Weekly: $weeklyVaccinated, Pending Requests: ${pendingRequests.length}');
    } catch (e) {
      print('❌ Fix error: $e');
      _showSnackBar('Fix error: $e', isError: true);
    }
  }
}

// Continue to Part 4 (Inner Classes)...
// Continuing from Part 3...

// ===== WEEKLY RECORD PAGE (Sunday-Saturday with Bar Chart) =====
class WeeklyRecordPage extends StatefulWidget {
  final String ashaId;

  const WeeklyRecordPage({super.key, required this.ashaId});

  @override
  State<WeeklyRecordPage> createState() => _WeeklyRecordPageState();
}

class _WeeklyRecordPageState extends State<WeeklyRecordPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime selectedWeekStart = DateTime.now();
  Map<String, int> weeklyData = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedWeekStart = _getWeekStart(DateTime.now());
    _loadWeeklyData();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.weekday == 7 
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday));
  }

  Future<void> _loadWeeklyData() async {
    setState(() => isLoading = true);
    try {
      final startOfWeek = DateTime(selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      print('Loading weekly data from $startOfWeek (Sunday) to $endOfWeek (Saturday)');
      
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: widget.ashaId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      print('Query returned ${snapshot.docs.length} completed appointments');
      
      Map<String, int> data = {};
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        data[dayKey] = 0;
      }
      
      for (var doc in snapshot.docs) {
        final appointmentData = doc.data();
        final timestamp = appointmentData['completedAt'] as Timestamp?;
        final dateStr = appointmentData['date'] as String?;
        
        DateTime? appointmentDate;
        if (timestamp != null) {
          appointmentDate = timestamp.toDate();
        } else if (dateStr != null) {
          try {
            appointmentDate = DateTime.parse(dateStr);
          } catch (e) {
            print('Error parsing date: $dateStr');
          }
        }
        
        if (appointmentDate != null) {
          if (appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
              appointmentDate.isBefore(endOfWeek)) {
            final dayKey = '${appointmentDate.year}-${appointmentDate.month.toString().padLeft(2, '0')}-${appointmentDate.day.toString().padLeft(2, '0')}';
            if (data.containsKey(dayKey)) {
              data[dayKey] = (data[dayKey] ?? 0) + 1;
            }
          }
        }
      }
      
      setState(() {
        weeklyData = data;
        isLoading = false;
      });
      
      print('Weekly data loaded: ${data.values.fold(0, (a, b) => a + b)} total');
    } catch (e) {
      print('Weekly data error: $e');
      setState(() {
        Map<String, int> fallbackData = {};
        final startOfWeek = DateTime(selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
        for (int i = 0; i < 7; i++) {
          final day = startOfWeek.add(Duration(days: i));
          final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          fallbackData[dayKey] = 0;
        }
        weeklyData = fallbackData;
        isLoading = false;
      });
    }
  }

  void _previousWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadWeeklyData();
  }

  void _nextWeek() {
    final nextWeek = selectedWeekStart.add(const Duration(days: 7));
    if (nextWeek.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        selectedWeekStart = nextWeek;
      });
      _loadWeeklyData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final endOfWeek = selectedWeekStart.add(const Duration(days: 6));
    final totalVaccinations = weeklyData.values.fold(0, (sum, count) => sum + count);

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Weekly Record'),
        backgroundColor: Colors.pinkAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: _previousWeek,
                              ),
                              Column(
                                children: [
                                  Text(
                                    '${selectedWeekStart.day}/${selectedWeekStart.month}/${selectedWeekStart.year} - ${endOfWeek.day}/${endOfWeek.month}/${endOfWeek.year}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Total: $totalVaccinations children vaccinated',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: _nextWeek,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 280,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Children Vaccinated Each Day',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: _buildBarChart(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Breakdown',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ...weeklyData.entries.map((entry) {
                            final date = DateTime.parse(entry.key);
                            final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday == 7 ? 0 : date.weekday];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: entry.value > 0 ? Colors.green : Colors.grey,
                                child: Text('${entry.value}', style: const TextStyle(color: Colors.white)),
                              ),
                              title: Text('$dayName, ${date.day}/${date.month}/${date.year}'),
                              subtitle: Text('${entry.value} ${entry.value == 1 ? 'child' : 'children'} vaccinated'),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBarChart() {
    final maxValue = weeklyData.values.fold(0, (max, val) => val > max ? val : max);
    final chartHeight = 150.0;

    return SizedBox(
      height: chartHeight + 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weeklyData.entries.map((entry) {
          final date = DateTime.parse(entry.key);
          final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday == 7 ? 0 : date.weekday];
          final barHeight = maxValue > 0 ? (entry.value / maxValue) * chartHeight : 10.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entry.value}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: barHeight.clamp(10.0, chartHeight),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: entry.value > 0 ? Colors.green : Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      boxShadow: entry.value > 0
                          ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 4)]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ===== VISIT LOG PAGE (with Week Navigation) =====
class VisitLogPage extends StatefulWidget {
  final String ashaId;
  final List<Map<String, dynamic>> visitLogs;
  final VoidCallback onRefresh;
  final bool firestoreEnabled;
  final bool isOffline;

  const VisitLogPage({
    super.key,
    required this.ashaId,
    required this.visitLogs,
    required this.onRefresh,
    required this.firestoreEnabled,
    required this.isOffline,
  });

  @override
  State<VisitLogPage> createState() => _VisitLogPageState();
}

class _VisitLogPageState extends State<VisitLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> localLogs = [];
  DateTime selectedWeekStart = DateTime.now();
  bool isLoading = false;
  bool isRefreshing = false; 

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    widget.onRefresh();
    await _loadWeekLogs();
    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    selectedWeekStart = _getWeekStart(DateTime.now());
    _loadWeekLogs();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.weekday == 7 
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday));
  }

  Future<void> _loadWeekLogs() async {
    setState(() => isLoading = true);
    try {
      final startOfWeek = DateTime(selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      
      print('Loading visit logs from $startOfWeek to $endOfWeek');
      
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: widget.ashaId)
          .where('status', isEqualTo: 'completed')
          .get();
      
      print('Visit logs query returned ${snapshot.docs.length} appointments');
      
      final logs = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['completedAt'] as Timestamp?;
        final dateStr = data['date'] as String?;
        
        DateTime? appointmentDate;
        if (timestamp != null) {
          appointmentDate = timestamp.toDate();
        } else if (dateStr != null) {
          try {
            appointmentDate = DateTime.parse(dateStr);
          } catch (e) {
            print('Error parsing date: $dateStr');
          }
        }
        
        if (appointmentDate != null) {
          if (appointmentDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) && 
              appointmentDate.isBefore(endOfWeek)) {
            logs.add(data..['id'] = doc.id);
          }
        }
      }
      
      logs.sort((a, b) {
        final aTime = (a['completedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final bTime = (b['completedAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      print('Filtered to ${logs.length} visits in this week');
      
      setState(() {
        localLogs = logs;
        isLoading = false;
      });
    } catch (e) {
      print('Visit logs error: $e');
      setState(() {
        localLogs = [];
        isLoading = false;
      });
    }
  }

  void _previousWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadWeekLogs();
  }

  void _nextWeek() {
    final nextWeek = selectedWeekStart.add(const Duration(days: 7));
    if (nextWeek.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() {
        selectedWeekStart = nextWeek;
      });
      _loadWeekLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final endOfWeek = selectedWeekStart.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Visit Log'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : _handleRefresh,  // UPDATED
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _previousWeek,
                  ),
                  Column(
                    children: [
                      Text(
                        '${selectedWeekStart.day}/${selectedWeekStart.month} - ${endOfWeek.day}/${endOfWeek.month}/${endOfWeek.year}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${localLogs.length} visits this week',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _nextWeek,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : localLogs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No visits this week', style: TextStyle(fontSize: 16, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Navigate to view other weeks', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: localLogs.length,
                        itemBuilder: (context, index) {
                          final log = localLogs[index];
                          final date = (log['completedAt'] as Timestamp?)?.toDate() ?? 
                                      (log['createdAt'] as Timestamp?)?.toDate() ?? 
                                      DateTime.now();
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.vaccines, color: Colors.green),
                              title: Text(log['childName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Vaccine: ${log['vaccination'] ?? 'N/A'}\n'
                                'Date: ${date.toString().split(' ')[0]}\n'
                                'Age: ${log['age'] ?? 'N/A'} months\n'
                                'Address: ${log['address'] ?? 'N/A'}',
                              ),
                              trailing: Text('#${index + 1}'),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// Continue to Part 5 (InventoryPage and PendingRequestsPage)...
// Continuing from Part 4...

// ===== INVENTORY PAGE =====
class InventoryPage extends StatefulWidget {
  final String ashaId;
  final String fullName;
  final List<String> vaccines;
  final Map<String, int> vaccineStock;
  final VoidCallback onInventoryUpdated;
  final VoidCallback onRequestCreated;
  final bool firestoreEnabled;
  final bool isOffline;

  const InventoryPage({
    super.key,
    required this.ashaId,
    required this.fullName,
    required this.vaccines,
    required this.vaccineStock,
    required this.onInventoryUpdated,
    required this.onRequestCreated,
    required this.firestoreEnabled,
    required this.isOffline,
  });

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late Map<String, int> localStock;
  final _firestore = FirebaseFirestore.instance;
  static const int maxStock = 50;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    localStock = {for (var entry in widget.vaccineStock.entries) entry.key: entry.value.clamp(0, maxStock)};
  }
  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onInventoryUpdated();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }

  Future<void> _editStock(String vaccine, int current) async {
    final controller = TextEditingController(text: current.toString());
    final newStock = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $vaccine Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'New Stock (Max $maxStock)',
                helperText: 'Enter 0-$maxStock doses',
                helperStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text ?? '');
              if (value == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid number'), backgroundColor: Colors.red),
                );
                return;
              }
              if (value > maxStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Max $maxStock doses per vaccine'), backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(context, value.clamp(0, maxStock));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newStock != null) {
      final clampedStock = newStock.clamp(0, maxStock);
      setState(() => localStock[vaccine] = clampedStock);
      if (widget.firestoreEnabled && !widget.isOffline) {
        try {
          await _firestore.collection('inventory').doc(widget.ashaId).update({vaccine: clampedStock});
          widget.onInventoryUpdated();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Updated locally'), backgroundColor: Colors.green),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated locally'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _requestStock(String vaccine) async {
  final current = localStock[vaccine] ?? 0;
  final maxRequest = maxStock - current;
  if (maxRequest <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$vaccine at max capacity ($maxStock doses)'), backgroundColor: Colors.orange),
    );
    return;
  }

  final qtyController = TextEditingController();
  
  // ✅ Show dialog and get result
  final result = await showDialog<int?>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Request $vaccine'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current: $current doses | Max: $maxStock', style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Quantity (Max $maxRequest)',
              helperText: 'Enter 1-$maxRequest doses',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final qty = int.tryParse(qtyController.text ?? '');
            Navigator.pop(dialogContext, qty);  // ✅ Return quantity
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Request'),
        ),
      ],
    ),
  );

  // ✅ Process after dialog closes (now we're back on the main page context)
  if (result == null) return; // User cancelled

  final qty = result;

  // Validate quantity
  if (qty <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid quantity'), backgroundColor: Colors.red),
    );
    return;
  }

  if (qty > maxRequest) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exceeds max capacity. Request max $maxRequest.'), backgroundColor: Colors.orange),
    );
    return;
  }

  // Send request to Firestore
  try {
    await _firestore.collection('requests').add({
      'type': 'vaccine_request',
      'vaccine': vaccine,
      'quantity': qty,
      'ashaId': widget.ashaId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    widget.onRequestCreated();
    
    // ✅ Show success message (now on correct context)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent successfully! $qty $vaccine requested'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e'), backgroundColor: Colors.red),
      );
    }
  }
}



  @override
  Widget build(BuildContext context) {
    int totalStock = localStock.values.map((s) => s.clamp(0, maxStock)).fold(0, (sum, stock) => sum + stock);
    final totalPercent = (totalStock / (widget.vaccines.length * maxStock) * 100).clamp(0.0, 100.0);

    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Vaccine Inventory'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : _handleRefresh,  // UPDATED
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green[50],
            child: Column(
              children: [
                const Text(
                  'Overall Inventory Level',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (totalPercent / 100),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  backgroundColor: Colors.grey[300],
                  minHeight: 10,
                ),
                const SizedBox(height: 8),
                Text('${totalPercent.toStringAsFixed(1)}% ($totalStock/${widget.vaccines.length * maxStock} doses)'),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: widget.vaccines.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final vaccine = widget.vaccines[index];
                final stock = (localStock[vaccine] ?? 0).clamp(0, maxStock);
                final percent = (stock / maxStock * 100).clamp(0.0, 100.0);
                Color barColor = stock == 0
                    ? Colors.red
                    : stock >= maxStock
                        ? Colors.green
                        : stock < 20
                            ? Colors.orange
                            : Colors.lightGreen;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: barColor,
                    child: Text('$stock', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(vaccine, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$stock/$maxStock doses\n${percent.toStringAsFixed(0)}% available'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 80,
                        child: LinearProgressIndicator(
                          value: (percent / 100),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _editStock(vaccine, stock),
                      ),
                      if (stock < maxStock)
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart, color: Colors.orange),
                          onPressed: () => _requestStock(vaccine),
                        ),
                    ],
                  ),
                  onTap: () => _editStock(vaccine, stock),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ===== PENDING REQUESTS PAGE (WITH DELETE BUTTON) =====
// ===== PENDING REQUESTS PAGE (STATEFUL WITH WORKING REFRESH) =====
// ===== PENDING REQUESTS PAGE (WITH IMMEDIATE UI UPDATE) =====
// ===== PENDING REQUESTS PAGE (FIXED: PROPER CONFIRMATION & SYNC) =====
// ===== PENDING REQUESTS PAGE (SELF-CONTAINED, LOADS OWN DATA) =====
class PendingRequestsPage extends StatefulWidget {
  final String ashaId;
  final Function(Map<String, dynamic>) onAccept;
  final VoidCallback onRefresh;

  const PendingRequestsPage({
    super.key,
    required this.ashaId,
    required this.onAccept,
    required this.onRefresh,
  });

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> pendingRequests = [];
  bool isLoading = true;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadPendingRequests();
  }

  Future<void> _loadPendingRequests() async {
    setState(() => isLoading = true);
    try {
      print('📦 Loading pending requests for ashaId: ${widget.ashaId}');
      
      final pendingSnap = await _firestore
          .collection('requests')
          .where('ashaId', isEqualTo: widget.ashaId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      print('📦 Found ${pendingSnap.docs.length} pending requests');
      
      final pendingList = pendingSnap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      pendingList.sort((a, b) {
        final aTime = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bTime = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      
      setState(() {
        pendingRequests = pendingList;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading pending requests: $e');
      setState(() {
        pendingRequests = [];
        isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    widget.onRefresh();
    await _loadPendingRequests();
    setState(() => isRefreshing = false);
  }

  Future<void> _handleAccept(Map<String, dynamic> request) async {
  // ✅ ADDED: Show confirmation dialog first
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Accept Request?'),
      content: Text(
        'Accept vaccine request for:\n\n'
        'Vaccine: ${request['vaccine'] ?? 'Unknown'}\n'
        'Quantity: ${request['quantity'] ?? 'N/A'} doses\n\n'
        'This will add the vaccines to your inventory.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Accept'),
        ),
      ],
    ),
  );

  // If user cancelled, exit
  if (confirmed != true) return;

  // User confirmed - proceed with acceptance
  await widget.onAccept(request);
  await _loadPendingRequests(); // Reload to remove accepted item
  widget.onRefresh(); // Update parent too
}


  Future<void> _handleDelete(Map<String, dynamic> request) async {
    final docId = request['id'] as String?;
    if (docId == null || docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid request'), backgroundColor: Colors.red),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request?'),
        content: Text(
          'Are you sure you want to delete the request for:\n\n'
          'Vaccine: ${request['vaccine'] ?? 'Unknown'}\n'
          'Quantity: ${request['quantity'] ?? 'N/A'} doses\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Delete from Firestore
    try {
      await _firestore.collection('requests').doc(docId).delete();
      print('✅ Request deleted: $docId');
      
      // Reload list immediately
      await _loadPendingRequests();
      widget.onRefresh(); // Update parent too
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request deleted successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print('❌ Delete error: $e');
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
        title: Text('Pending Requests (${pendingRequests.length})'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : pendingRequests.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No pending requests', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: pendingRequests.length,
                  itemBuilder: (context, index) {
                    final request = pendingRequests[index];
                    final createdAt = request['createdAt'] != null
                        ? (request['createdAt'] as Timestamp).toDate().toString().split(' ')[0]
                        : 'Recently';
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        leading: const Icon(Icons.pending, color: Colors.orange),
                        title: Text(request['vaccine'] ?? request['title'] ?? 'Unknown Request'),
                        subtitle: Text(
                          'Quantity: ${request['quantity'] ?? 'N/A'}\n'
                          'Type: ${request['type'] ?? 'General'}\n'
                          'Requested: $createdAt',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _handleAccept(request),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              child: const Text('Accept', style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _handleDelete(request),
                              tooltip: 'Delete Request',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}





// ===== ACCEPTED REQUESTS PAGE =====
// ===== ACCEPTED REQUESTS PAGE (STATEFUL WITH WORKING REFRESH) =====
class AcceptedRequestsPage extends StatefulWidget {
  final List<Map<String, dynamic>> acceptedRequests;
  final VoidCallback onRefresh;

  const AcceptedRequestsPage({
    super.key,
    required this.acceptedRequests,
    required this.onRefresh,
  });

  @override
  State<AcceptedRequestsPage> createState() => _AcceptedRequestsPageState();
}

class _AcceptedRequestsPageState extends State<AcceptedRequestsPage> {
  bool isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 500));
    widget.onRefresh();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() => isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Accepted Requests'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: isRefreshing 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
      body: widget.acceptedRequests.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text('No accepted requests', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: widget.acceptedRequests.length,
              itemBuilder: (context, index) {
                final request = widget.acceptedRequests[index];
                final acceptedAt = request['acceptedAt'] != null
                    ? (request['acceptedAt'] as Timestamp).toDate().toString().split(' ')[0]
                    : 'Recently';
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.check, color: Colors.green),
                    title: Text(request['vaccine'] ?? request['title'] ?? 'Unknown'),
                    subtitle: Text(
                      'Quantity: ${request['quantity'] ?? 'N/A'}\nAccepted: $acceptedAt',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

