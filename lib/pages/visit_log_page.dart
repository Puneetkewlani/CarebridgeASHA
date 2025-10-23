import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VisitLogPage extends StatefulWidget {
  final String ashaId;

  const VisitLogPage({super.key, required this.ashaId});

  @override
  State<VisitLogPage> createState() => _VisitLogPageState();
}

class _VisitLogPageState extends State<VisitLogPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> localLogs = [];
  DateTime selectedWeekStart = DateTime.now();
  bool isLoading = false;
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    selectedWeekStart = _getWeekStart(DateTime.now());
    _loadWeekLogs();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.weekday == 7
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday));
  }

  Future<void> _loadWeekLogs() async {
    setState(() => isLoading = true);
    try {
      final startOfWeek = DateTime(
          selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      // ✅ ONLY query visits collection - these are archived completed appointments
      final visitsSnapshot = await _firestore
          .collection('visits')
          .where('ashaId', isEqualTo: widget.ashaId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
          .get();

      final logs = visitsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Sort by completion time (newest first)
      logs.sort((a, b) {
        final aTime = (a['completedAt'] as Timestamp?)?.toDate() ?? 
                      (a['createdAt'] as Timestamp?)?.toDate() ?? 
                      DateTime(2000);
        final bTime = (b['completedAt'] as Timestamp?)?.toDate() ?? 
                      (b['createdAt'] as Timestamp?)?.toDate() ?? 
                      DateTime(2000);
        return bTime.compareTo(aTime);
      });

      setState(() {
        localLogs = logs;
        isLoading = false;
      });

      print('📋 Loaded ${logs.length} visits from visits collection');
    } catch (e) {
      print('Visit logs error: $e');
      setState(() {
        localLogs = [];
        isLoading = false;
      });
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await _loadWeekLogs();
    if (mounted) {
      setState(() => isRefreshing = false);
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
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: isRefreshing ? null : _handleRefresh,
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
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green))
                : localLogs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No visits logged this week',
                                style: TextStyle(fontSize: 16, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('Completed appointments will appear here after midnight',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center),
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
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.vaccines, color: Colors.green),
                              title: Text(log['childName'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Vaccine: ${log['vaccination'] ?? 'N/A'}\n'
                                'Date: ${log['date'] ?? date.toString().split(' ')[0]}\n'
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
