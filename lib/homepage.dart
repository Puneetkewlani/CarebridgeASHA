import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  int todayTotalVisits = 0;
  int todayDoneVisits = 0;
  int weeklyVaccinated = 0;
  int pendingVisits = 0;
  double inventoryPercent = 0.0;
  List<Map<String, dynamic>> todayAppointments = [];
  Map<String, int> vaccineStock = {};
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> acceptedRequests = [];

  // UIP-aligned vaccines for children in India (2025 schedule)
  final List<String> vaccines = [
    'BCG', 'OPV-0', 'Hep B-0', 'OPV-1', 'Pentavalent-1', 'Rotavirus-1', 'PCV-1',
    'OPV-2', 'Pentavalent-2', 'Rotavirus-2', 'PCV-2',
    'OPV-3', 'Pentavalent-3', 'Rotavirus-3', 'PCV-3', 'IPV-1',
    'Measles-1', 'JE-1',
    'DPT Booster-1', 'OPV Booster', 'Measles-2', 'JE-2'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            fullName = data['fullName'] ?? 'User';
            ashaId = data['ashaId'] ?? 'ID Not Set';
          });
          await Future.wait([_loadAppointments(), _loadInventory(), _loadRequests(), _loadWeeklyVaccinated()]);
        }
      } catch (e) {
        print('User load error: $e');
        _showSnackBar('Load failed: Ensure Firestore setup. $e', isError: true);
      }
    }
  }

  Future<void> _loadAppointments() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) return;
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('date', isEqualTo: today)
          .get();
      setState(() {
        todayAppointments = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        pendingVisits = todayAppointments.where((apt) => (apt['status'] ?? '') == 'pending').length;
        todayTotalVisits = todayAppointments.length;
        todayDoneVisits = todayTotalVisits - pendingVisits;
      });
    } catch (e) {
      print('Appointments load error: $e');
    }
  }

  Future<void> _loadInventory() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) return;
    try {
      final doc = await _firestore.collection('inventory').doc(ashaId).get();
      if (doc.exists) {
  final data = (doc.data() as Map<String, dynamic>?) ?? {};
        setState(() {
          vaccineStock = {};
          for (var entry in data.entries) {
            vaccineStock[entry.key] = entry.value as int? ?? 50;
          }
          final totalStock = vaccineStock.values.fold(0, (sum, val) => sum + val);
          final totalMax = vaccines.length * 50;
          inventoryPercent = totalMax > 0 ? (totalStock / totalMax) * 100 : 0;
        });
      } else {
        await _firestore.collection('inventory').doc(ashaId).set(
          {for (var v in vaccines) v: 50},
          SetOptions(merge: true),
        );
        await _loadInventory();
      }
    } catch (e) {
      print('Inventory load error: $e');
    }
  }

  Future<void> _loadRequests() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) return;
    try {
      final pendingSnap = await _firestore
          .collection('requests')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'pending')
          .get();
  setState(() => pendingRequests = pendingSnap.docs.map((doc) => doc.data()).toList());
      final acceptedSnap = await _firestore
          .collection('requests')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'accepted')
          .get();
  setState(() => acceptedRequests = acceptedSnap.docs.map((doc) => doc.data()).toList());
    } catch (e) {
      print('Requests load error: $e');
    }
  }

  Future<void> _loadWeeklyVaccinated() async {
    if (ashaId == 'Loading...' || ashaId.isEmpty) return;
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday start
      final startTimestamp = Timestamp.fromDate(startOfWeek);
      final snapshot = await _firestore
          .collection('visits')
          .where('ashaId', isEqualTo: ashaId)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .get();
      setState(() => weeklyVaccinated = snapshot.docs.length);
    } catch (e) {
      print('Weekly vaccinated load error: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('Logout error: $e');
    }
  }

  Future<void> _addSchedule() async {
    if (ashaId == 'Loading...') {
      _showSnackBar('Wait for load...');
      return;
    }
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final addressController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedVaccine;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Child Name')),
                TextField(controller: ageController, decoration: const InputDecoration(labelText: 'Age (months)'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: selectedVaccine,
                  decoration: const InputDecoration(labelText: 'Vaccination'),
                  items: vaccines.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (value) => setDialogState(() => selectedVaccine = value),
                ),
                TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final childName = nameController.text.trim();
                final addr = addressController.text.trim();
                if (childName.isEmpty || selectedVaccine == null || addr.isEmpty) {
                  _showSnackBar('Need name, vaccine, address');
                  return;
                }
                try {
                  final today = DateTime.now().toIso8601String().split('T')[0];
                  await _firestore.collection('appointments').add({
                    'ashaId': ashaId,
                    'fullName': fullName,
                    'childName': childName,
                    'age': int.tryParse(ageController.text) ?? 0,
                    'vaccination': selectedVaccine,
                    'address': addr,
                    'phone': phoneController.text.trim(),
                    'date': today,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  await _loadAppointments();
                  Navigator.pop(dialogContext);
                  _showSnackBar('Added! Check appointments.');
                } catch (e) {
                  String msg = 'Add failed: $e';
                  if (e.toString().contains('PERMISSION_DENIED')) msg += '\nCheck rules!';
                  _showSnackBar(msg, isError: true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markVisit(int globalIndex) async {
    if (globalIndex < 0 || globalIndex >= todayAppointments.length) return;
    final apt = todayAppointments[globalIndex];
    final docId = apt['id'] as String?;
    if (docId == null || (apt['status'] ?? '') != 'pending') {
      _showSnackBar('Invalid appointment');
      return;
    }

    final confirm = await _showConfirmationDialog('Mark as Done', 'Complete this visit? Stock will be deducted.');
    if (!confirm || !mounted) return;

    final prevWeekly = weeklyVaccinated;
    final prevDone = todayDoneVisits;
    final prevPending = pendingVisits;

    try {
      setState(() {
        apt['status'] = 'done';
        todayDoneVisits++;
        pendingVisits--;
        weeklyVaccinated++;
      });

      final batch = _firestore.batch();
      batch.update(_firestore.collection('appointments').doc(docId), {'status': 'done'});
      final vaccineUsed = apt['vaccination'] ?? '';
      batch.update(_firestore.collection('inventory').doc(ashaId), {vaccineUsed: FieldValue.increment(-1)});
      batch.set(_firestore.collection('visits').doc(), {
        'ashaId': ashaId,
        'fullName': fullName,
        'childName': apt['childName'] ?? '',
        'age': apt['age'] ?? 0,
        'vaccination': apt['vaccination'] ?? '',
        'address': apt['address'] ?? '',
        'phone': apt['phone'] ?? '',
        'date': DateTime.now().toIso8601String().split('T')[0],
        'status': 'done',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      print('Batch mark success');

      await _loadInventory();
      await _loadAppointments();
      _showSnackBar('Marked done! Visit logged.');
    } catch (e) {
      setState(() {
        apt['status'] = 'pending';
        todayDoneVisits = prevDone;
        pendingVisits = prevPending;
        weeklyVaccinated = prevWeekly;
      });
      print('Mark error: $e');
      _showSnackBar('Mark failed: $e', isError: true);
    }
  }

  Future<void> _deleteAppointment(int index) async {
    if (index < 0 || index >= todayAppointments.length) return;
    final apt = todayAppointments[index];
    final docId = apt['id'];
    if (docId == null) return;

    final confirm = await _showConfirmationDialog('Delete Appointment', 'Remove this entry? It cannot be recovered.');
    if (!confirm || !mounted) return;

    try {
      setState(() {
        todayAppointments.removeAt(index);
        todayTotalVisits--;
        if ((apt['status'] ?? '') == 'pending') pendingVisits--;
        else todayDoneVisits--;
      });

      await _firestore.collection('appointments').doc(docId).delete();
      print('Delete success');
      _showSnackBar('Appointment deleted.');
    } catch (e) {
      await _loadAppointments();
      print('Delete error: $e');
      _showSnackBar('Delete failed: $e', isError: true);
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildDialogList(List<Map<String, dynamic>> items, String emptyText, String titleKey, String subtitleKey1, String? subtitleKey2) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4,
      width: double.maxFinite,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(emptyText),
              )
            else
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final titleList = (item[titleKey] as List?) ?? [];
                    String title = titleList.isNotEmpty ? titleList.join(', ') : 'Unknown';
                    String subtitle = '${item[subtitleKey1]?.toDate()?.toString() ?? 'N/A'}';
                    if (subtitleKey2 != null) {
                      subtitle += '\n${item[subtitleKey2]?.toDate()?.toString() ?? 'N/A'}';
                    }
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: ListTile(
                          title: Text(title),
                          subtitle: Text(subtitle),
                          minLeadingWidth: 0,
                          dense: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInventory() async {
    await _loadInventory();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Inventory - Edit'),
        content: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          width: double.maxFinite,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 400,
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vaccines.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
                      itemBuilder: (context, index) {
                        final vaccine = vaccines[index];
                        final currentStock = vaccineStock[vaccine] ?? 50;
                        final percent = (currentStock / 50.0) * 100;
                        final isLow = percent < 20;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(vaccine),
                              subtitle: Text('${currentStock}/50 (${percent.toStringAsFixed(0)}%)'),
                              leading: SizedBox(
                                width: 100,
                                height: 4,
                                child: LinearProgressIndicator(
                                  value: percent / 100.clamp(0.0, 1.0),
                                  color: isLow ? Colors.red : Colors.green,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                    onPressed: () => _editStock(vaccine, currentStock),
                                  ),
                                  if (isLow)
                                    IconButton(
                                      icon: const Icon(Icons.request_page, color: Colors.orange, size: 20),
                                      onPressed: () => _requestStock(vaccine),
                                    ),
                                ],
                              ),
                              dense: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(onPressed: () => _requestStock(''), child: const Text('Request More')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _editStock(String vaccine, int currentStock) async {
    final controller = TextEditingController(text: currentStock.toString());
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Edit $vaccine'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Stock'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newStockStr = controller.text;
              int newStock = int.tryParse(newStockStr) ?? currentStock;
              if (newStock < 0) newStock = 0;
              try {
                setState(() => vaccineStock[vaccine] = newStock);
                final totalStock = vaccineStock.values.fold(0, (sum, val) => sum + val);
                final totalMax = vaccines.length * 50;
                setState(() => inventoryPercent = totalMax > 0 ? (totalStock / totalMax) * 100 : 0);

                await _firestore.collection('inventory').doc(ashaId).update({vaccine: newStock});
                Navigator.pop(dialogContext);
                _showSnackBar('Updated $vaccine to $newStock');
              } catch (e) {
                setState(() => vaccineStock[vaccine] = currentStock);
                _showSnackBar('Update failed: $e', isError: true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestStock(String specificVaccine) async {
    final Map<String, int> quantities = {};
    Set<String> selectedVaccines = {};
    if (specificVaccine.isNotEmpty) {
      selectedVaccines.add(specificVaccine);
      quantities[specificVaccine] = 0;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(specificVaccine.isEmpty ? 'Request Stock' : 'Request $specificVaccine'),
          content: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (specificVaccine.isEmpty) ...[
                    const Text('Select vaccines:'),
                    SizedBox(
                      height: 300,
                      child: ListView(
                        children: vaccines.map((v) => CheckboxListTile(
                          title: Text(v),
                          value: selectedVaccines.contains(v),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedVaccines.add(v);
                                if (!quantities.containsKey(v)) quantities[v] = 0;
                              } else {
                                selectedVaccines.remove(v);
                                quantities.remove(v);
                              }
                            });
                          },
                          dense: true,
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('Enter quantities (per dose):'),
                  ...selectedVaccines.map((v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w500))),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Qty',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => setDialogState(() {
                              quantities[v] = int.tryParse(val) ?? 0;
                            }),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final validReqs = quantities.entries.where((e) => e.value > 0).toList();
                if (validReqs.isEmpty) {
                  _showSnackBar('Enter qty >0 for at least one');
                  return;
                }
                try {
                  await _firestore.collection('requests').add({
                    'ashaId': ashaId,
                    'fullName': fullName,
                    'vaccines': selectedVaccines.toList(),
                    'quantities': {for (var e in validReqs) e.key: e.value},
                    'status': 'pending',
                    'requestedDate': Timestamp.now(),
                    'specificVaccine': specificVaccine,
                  });
                  await _loadRequests();
                  Navigator.pop(dialogContext);
                  _showSnackBar('Request sent with quantities!');
                } catch (e) {
                  _showSnackBar('Request failed: $e', isError: true);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPendingRequests() async {
    await _loadRequests();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (BuildContext _) => PendingRequestsPage(pendingRequests: pendingRequests)),
    );
  }

  Future<void> _showAcceptedRequests() async {
    await _loadRequests();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Accepted History'),
        content: _buildDialogList(acceptedRequests, 'None', 'vaccines', 'requestedDate', 'acceptedDate'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _showVisitLog() async {
    if (ashaId.isEmpty) return;
    try {
      final snapshot = await _firestore
          .collection('visits')
          .where('ashaId', isEqualTo: ashaId)
          .limit(20)
          .get();
  final visits = snapshot.docs.map((doc) => doc.data()).toList();
      visits.sort((a, b) {
        final dateA = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        final dateB = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          title: const Text('Visit Log'),
          content: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.6,
            width: double.maxFinite,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (visits.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No visits'),
                      )
                    else
                      SizedBox(
                        height: 400,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: visits.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final visit = visits[index];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  title: Text('${visit['childName'] ?? ''} (${visit['age'] ?? 0}m) - ${visit['vaccination'] ?? ''}'),
                                  subtitle: Text('${visit['address'] ?? ''}\n${visit['phone'] ?? ''}\n${visit['date'] ?? ''}'),
                                  minLeadingWidth: 0,
                                  dense: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Visit log error: $e');
      _showSnackBar('Log failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = {
      'primary': const Color(0xFFA8FBD3),
      'highlight': const Color(0xFF4FB7B3),
      'secondary': const Color(0xFF637AB9),
      'toning': const Color(0xFF31326F),
    };
    final screenHeight = MediaQuery.of(context).size.height;
    final scale = screenHeight > 700 ? 1.0 : (screenHeight > 500 ? 0.8 : 0.6);

    if (ashaId == 'Loading...') {
      return Scaffold(
        backgroundColor: colors['primary']!,
        body: Center(child: CircularProgressIndicator(color: colors['toning']!)),
      );
    }

    final pendingAppts = todayAppointments.where((apt) => (apt['status'] ?? '') == 'pending').toList();

    return Scaffold(
      backgroundColor: colors['primary']!,
      appBar: AppBar(
        title: Text('Dashboard - $fullName', style: const TextStyle(color: Colors.white)),
        backgroundColor: colors['toning']!,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(8 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16 * scale),
                decoration: BoxDecoration(color: colors['secondary']!, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('ASHA ID: $ashaId', style: TextStyle(fontSize: 16 * scale, color: Colors.white.withOpacity(0.8))),
                  ],
                ),
              ),
              SizedBox(height: 16 * scale),
              Row(
                children: [
                  Expanded(child: _statCard('Today\'s Visits', '$todayDoneVisits of $todayTotalVisits', Icons.today, colors['secondary']!, scale)),
                  SizedBox(width: 8 * scale),
                  Expanded(child: _statCard('Children Vaccinated This Week', '$weeklyVaccinated', Icons.local_hospital, colors['highlight']!, scale)),
                  SizedBox(width: 8 * scale),
                  Expanded(child: _statCard('Pending Visits', '$pendingVisits', Icons.schedule, Colors.orange, scale)),
                ],
              ),
              SizedBox(height: 16 * scale),
              Card(
                color: colors['secondary']!,
                child: Padding(
                  padding: EdgeInsets.all(12 * scale),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Inventory (${vaccineStock.length}/${vaccines.length})', style: TextStyle(fontSize: 16 * scale, color: Colors.white)),
                          Text('${inventoryPercent.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: colors['highlight']!)),
                        ],
                      ),
                      SizedBox(height: 8 * scale),
                      SizedBox(
                        height: 150 * scale,
                        child: vaccineStock.isEmpty
                            ? Center(child: Text('Loading... (${vaccines.length} vaccines)', style: TextStyle(fontSize: 14 * scale, color: Colors.white.withOpacity(0.7))))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemExtent: 120 * scale,
                                itemCount: vaccines.length,
                                itemBuilder: (context, index) {
                                  final vaccine = vaccines[index];
                                  final stock = vaccineStock[vaccine] ?? 50;
                                  final percent = (stock / 50.0) * 100;
                                  return Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(8 * scale),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(vaccine, style: TextStyle(fontSize: 12 * scale, color: Colors.black), textAlign: TextAlign.center),
                                          LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0), color: percent < 20 ? Colors.red : Colors.green),
                                          Text('$stock/50', style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      ElevatedButton(onPressed: _showInventory, child: const Text('View All & Edit')),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * scale),
              Text('Quick Actions', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: colors['toning']!)),
              SizedBox(height: 8 * scale),
              Row(
                children: [
                  Expanded(child: _actionButton(Icons.add, 'Add Schedule', colors['highlight']!, _addSchedule, scale)),
                  SizedBox(width: 8 * scale),
                  Expanded(child: _actionButton(Icons.history, 'Visit Log', Colors.blue, _showVisitLog, scale)),
                  SizedBox(width: 8 * scale),
                  Expanded(child: _actionButton(Icons.inventory_2, 'Inventory', colors['secondary']!, _showInventory, scale)),
                ],
              ),
              SizedBox(height: 16 * scale),
              Text('Requests', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: colors['toning']!)),
              SizedBox(height: 8 * scale),
              Row(
                children: [
                  Expanded(child: ElevatedButton(onPressed: _showPendingRequests, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: const Text('Pending'))),
                  SizedBox(width: 8 * scale),
                  Expanded(child: ElevatedButton(onPressed: _showAcceptedRequests, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Accepted'))),
                ],
              ),
              SizedBox(height: 16 * scale),
              Text('Today\'s Pending Appointments ($pendingVisits)', style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: colors['toning']!)),
              SizedBox(height: 8 * scale),
              if (pendingAppts.isEmpty)
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16 * scale),
                    child: Column(
                      children: [
                        Text('No pending appointments today.', style: TextStyle(fontSize: 14 * scale)),
                        ElevatedButton(onPressed: _addSchedule, child: const Text('Add One')),
                      ],
                    ),
                  ),
                )
              else
                ...pendingAppts.asMap().entries.map((entry) {
                  // localIndex not used; using entry.key directly when needed
                  final apt = entry.value;
                  final globalIndex = todayAppointments.indexWhere((a) => a['id'] == apt['id']);
                  if (globalIndex == -1) return const SizedBox.shrink();
                  return Card(
                    margin: EdgeInsets.only(bottom: 8 * scale),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: 48 * scale),
                      child: Padding(
                        padding: EdgeInsets.all(12 * scale),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Child: ${apt['childName'] ?? ''} (${apt['age'] ?? 0} months)', style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.bold)),
                            Text('Vaccine: ${apt['vaccination'] ?? ''}', style: TextStyle(fontSize: 14 * scale)),
                            Text('Address: ${apt['address'] ?? ''}', style: TextStyle(fontSize: 14 * scale)),
                            Text('Phone: ${apt['phone'] ?? ''}', style: TextStyle(fontSize: 14 * scale)),
                            SizedBox(height: 8 * scale),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteAppointment(globalIndex),
                                  tooltip: 'Delete',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: Colors.green),
                                  onPressed: () => _markVisit(globalIndex),
                                  tooltip: 'Mark Done',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              SizedBox(height: 80 * scale),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchedule,
        backgroundColor: colors['toning']!,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Schedule', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, double scale) {
    return Card(
      color: color,
      child: Padding(
        padding: EdgeInsets.all(12 * scale),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24 * scale),
            Text(title, style: TextStyle(fontSize: 12 * scale, color: Colors.white)),
            Text(value, style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, Color color, VoidCallback onTap, double scale) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(12 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 32 * scale),
              Text(label, style: TextStyle(fontSize: 12 * scale, fontWeight: FontWeight.bold, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-screen Pending Requests Page
class PendingRequestsPage extends StatelessWidget {
  final List<Map<String, dynamic>> pendingRequests;
  const PendingRequestsPage({super.key, required this.pendingRequests});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'primary': const Color(0xFFA8FBD3),
      'toning': const Color(0xFF31326F),
    };
    return Scaffold(
      backgroundColor: colors['primary']!,
      appBar: AppBar(
        title: const Text('Pending Requests', style: TextStyle(color: Colors.white)),
        backgroundColor: colors['toning']!,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: pendingRequests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No pending requests', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text('All requests processed or none submitted.', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Dashboard'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pendingRequests.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final req = pendingRequests[index];
                final vaccines = req['vaccines'] as List? ?? [];
                final requestedDate = (req['requestedDate'] as Timestamp?)?.toDate().toString().split(' ')[0] ?? 'N/A';
                final quantities = req['quantities'] as Map<String, dynamic>? ?? {};
                return Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.request_page, color: Colors.orange, size: 24),
                            const SizedBox(width: 8),
                            const Text('Stock Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Vaccines Needed:', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: vaccines.map((v) {
                            final qty = quantities[v] as int? ?? 0;
                            return Chip(
                              label: Text('$v ${qty > 0 ? '($qty)' : ''}', style: const TextStyle(color: Colors.white)),
                              backgroundColor: Colors.orange,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('Requested: $requestedDate', style: TextStyle(fontSize: 14, color: Colors.grey)),
                          ],
                        ),
                        if (req['specificVaccine'] != null && (req['specificVaccine'] as String).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Specific: ${req['specificVaccine']}',
                              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blue),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleAcceptRequest(context, req),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accept'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _handleAcceptRequest(BuildContext context, Map<String, dynamic> req) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request accepted!')));
    Navigator.pop(context);
  }
}
