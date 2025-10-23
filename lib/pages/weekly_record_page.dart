import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:care_bridge/widgets/bar_chart_widget.dart';

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
  bool isRefreshing = false;

  @override
  void initState() {
    super.initState();
    selectedWeekStart = _getWeekStart(DateTime.now());
    _loadWeeklyData();
  }

  DateTime _getWeekStart(DateTime date) {
    return date.weekday == 7
        ? DateTime(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day)
            .subtract(Duration(days: date.weekday));
  }

  Future<void> _loadWeeklyData() async {
  setState(() => isLoading = true);
  try {
    final startOfWeek = DateTime(
        selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    print('📅 Loading data for week: ${startOfWeek.toString().split(' ')[0]} to ${endOfWeek.toString().split(' ')[0]}');

    // ✅ Get archived visits from previous days
    final visitsSnapshot = await _firestore
        .collection('visits')
        .where('ashaId', isEqualTo: widget.ashaId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfWeek))
        .get();

    print('📦 Found ${visitsSnapshot.docs.length} archived visits');

    // ✅ Get ALL completed appointments (to count this week's)
    final completedApptSnapshot = await _firestore
        .collection('appointments')
        .where('ashaId', isEqualTo: widget.ashaId)
        .where('status', isEqualTo: 'done')
        .get();

    print('✅ Found ${completedApptSnapshot.docs.length} completed appointments');

    // Initialize daily counts
    Map<String, int> data = {};
    for (int i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final dayKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      data[dayKey] = 0;
    }

    // Count archived visits by their completion date
    for (var doc in visitsSnapshot.docs) {
      final visitData = doc.data();
      final dateStr = visitData['date'] as String?; // Use appointment date, not createdAt
      
      if (dateStr != null && data.containsKey(dateStr)) {
        data[dateStr] = (data[dateStr] ?? 0) + 1;
        print('📊 Added visit on $dateStr');
      }
    }

    // Count completed appointments by their appointment date (not completedAt)
    for (var doc in completedApptSnapshot.docs) {
      final apptData = doc.data();
      final dateStr = apptData['date'] as String?;
      
      if (dateStr != null) {
        try {
          final apptDate = DateTime.parse(dateStr);
          final apptDay = DateTime(apptDate.year, apptDate.month, apptDate.day);
          final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
          final weekEnd = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);
          
          // Only count if appointment date is within this week
          if (!apptDay.isBefore(weekStart) && apptDay.isBefore(weekEnd)) {
            if (data.containsKey(dateStr)) {
              data[dateStr] = (data[dateStr] ?? 0) + 1;
              print('📊 Added completed appointment on $dateStr');
            }
          }
        } catch (e) {
          print('Error parsing appointment date: $dateStr - $e');
        }
      }
    }

    setState(() {
      weeklyData = data;
      isLoading = false;
    });

    final totalCount = data.values.fold(0, (sum, count) => sum + count);
    print('📊 Weekly record total: $totalCount vaccinations');
    print('📊 Daily breakdown: $data');
  } catch (e) {
    print('Weekly data error: $e');
    setState(() {
      Map<String, int> fallbackData = {};
      final startOfWeek = DateTime(
          selectedWeekStart.year, selectedWeekStart.month, selectedWeekStart.day);
      for (int i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayKey =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        fallbackData[dayKey] = 0;
      }
      weeklyData = fallbackData;
      isLoading = false;
    });
  }
}



  Future<void> _handleRefresh() async {
    setState(() => isRefreshing = true);
    await _loadWeeklyData();
    setState(() => isRefreshing = false);
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Week Navigation Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios, color: Colors.green),
                                onPressed: _previousWeek,
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '${selectedWeekStart.day}/${selectedWeekStart.month}/${selectedWeekStart.year} - ${endOfWeek.day}/${endOfWeek.month}/${endOfWeek.year}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: $totalVaccinations children vaccinated',
                                      style: const TextStyle(
                                          fontSize: 14, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, color: Colors.green),
                                onPressed: _nextWeek,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bar Chart Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Children Vaccinated Each Day',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          BarChartWidget(
                            weeklyData: weeklyData,
                            height: 180,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Daily Breakdown Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.list, color: Colors.green),
                              const SizedBox(width: 8),
                              const Text(
                                'Daily Breakdown',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          ...weeklyData.entries.map((entry) {
                            final date = DateTime.parse(entry.key);
                            final dayName = [
                              'Sunday',
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday'
                            ][date.weekday == 7 ? 0 : date.weekday];
                            return Card(
                              color: entry.value > 0
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: entry.value > 0
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  dayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${date.day}/${date.month}/${date.year}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: Text(
                                  '${entry.value} ${entry.value == 1 ? 'child' : 'children'}',
                                  style: TextStyle(
                                    color: entry.value > 0
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
}
