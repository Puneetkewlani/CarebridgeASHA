import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PHCReportsPage extends StatefulWidget {
  const PHCReportsPage({super.key});

  @override
  State<PHCReportsPage> createState() => _PHCReportsPageState();
}

class _PHCReportsPageState extends State<PHCReportsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String phcLocation = '';
  bool isLoading = true;
  
  Map<String, int> vaccineBreakdown = {};
  int totalVaccinations = 0;
  int childrenVaccinated = 0;
  
  int selectedWeekDuration = 7; // 7, 14, 28, or 56 days
  int weekOffset = 0; // 0 = current, 1 = previous, 2 = 2 weeks ago, etc.

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await _firestore.collection('phc_staff').doc(uid).get();
        if (doc.exists) {
          phcLocation = doc.data()?['location'] ?? '';
          await _calculateStats();
        }
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
    
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _calculateStats() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      // Calculate date range based on selected week and offset
      final now = DateTime.now();
      final endDate = now.subtract(Duration(days: weekOffset * selectedWeekDuration));
      final startDate = endDate.subtract(Duration(days: selectedWeekDuration));
      
      print('Calculating stats from ${startDate} to ${endDate}');
      
      // Query visits from the selected period
      final visitsSnapshot = await _firestore
          .collection('visits')
          .where('location', isEqualTo: phcLocation)
          .where('visitDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('visitDate', isLessThan: Timestamp.fromDate(endDate))
          .get();

      print('Found ${visitsSnapshot.docs.length} visits');

      // Calculate statistics
      Set<String> uniqueChildren = {};
      Map<String, int> vaccines = {};
      int total = 0;

      for (var doc in visitsSnapshot.docs) {
        final data = doc.data();
        
        // Count unique children
        if (data['childName'] != null) {
          uniqueChildren.add(data['childName'].toString().toLowerCase());
        }
        
        // Count vaccines
        if (data['vaccinesGiven'] != null) {
          final vaccinesList = data['vaccinesGiven'] as List<dynamic>;
          for (var vaccine in vaccinesList) {
            final vaccineName = vaccine.toString();
            vaccines[vaccineName] = (vaccines[vaccineName] ?? 0) + 1;
            total++;
          }
        }
      }

      if (mounted) {
        setState(() {
          childrenVaccinated = uniqueChildren.length;
          totalVaccinations = total;
          vaccineBreakdown = vaccines;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error calculating stats: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _getPeriodText() {
    String durationText;
    if (selectedWeekDuration == 7) durationText = '1 Week';
    else if (selectedWeekDuration == 14) durationText = '2 Weeks';
    else if (selectedWeekDuration == 28) durationText = '4 Weeks';
    else durationText = '8 Weeks';

    if (weekOffset == 0) return 'Current $durationText';
    if (weekOffset == 1) return 'Previous $durationText';
    return '$weekOffset ${selectedWeekDuration == 7 ? "weeks" : "periods"} ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA8FBD3),
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: const Color(0xFF31326F),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF31326F), Color(0xFF637AB9)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vaccination Report',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_getPeriodText()} • $phcLocation',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Duration Selector
                  const Text(
                    'Select Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildDurationChip('1 Week', 7),
                        _buildDurationChip('2 Weeks', 14),
                        _buildDurationChip('4 Weeks', 28),
                        _buildDurationChip('8 Weeks', 56),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Week Navigation
                  const Text(
                    'Select Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      IconButton(
                        onPressed: weekOffset < 10
                            ? () {
                                setState(() => weekOffset++);
                                _calculateStats();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_back),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getPeriodText(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: weekOffset > 0
                            ? () {
                                setState(() => weekOffset--);
                                _calculateStats();
                              }
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Key Statistics
                  const Text(
                    'Key Statistics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Children Vaccinated',
                          childrenVaccinated.toString(),
                          Icons.child_care,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Total Doses',
                          totalVaccinations.toString(),
                          Icons.vaccines,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Vaccine Breakdown
                  const Text(
                    'Vaccine Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (vaccineBreakdown.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.assessment, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'No vaccination data for this period',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: vaccineBreakdown.entries.map((entry) {
                            final percentage = (entry.value / totalVaccinations * 100).toStringAsFixed(1);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${entry.value} doses ($percentage%)',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: entry.value / totalVaccinations,
                                      minHeight: 8,
                                      backgroundColor: Colors.grey[200],
                                      color: _getVaccineColor(entry.key),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Additional Stats
                  const Text(
                    'Additional Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            'Average doses per child',
                            childrenVaccinated > 0
                                ? (totalVaccinations / childrenVaccinated).toStringAsFixed(1)
                                : '0',
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            'Most administered',
                            vaccineBreakdown.entries.isEmpty
                                ? 'N/A'
                                : vaccineBreakdown.entries.reduce((a, b) => a.value > b.value ? a : b).key,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            'Report Period',
                            _getPeriodText(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDurationChip(String label, int days) {
    final isSelected = selectedWeekDuration == days;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            selectedWeekDuration = days;
            weekOffset = 0; // Reset to current period
          });
          _calculateStats();
        },
        selectedColor: const Color(0xFF31326F),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _getVaccineColor(String vaccine) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    return colors[vaccine.hashCode % colors.length];
  }
}
