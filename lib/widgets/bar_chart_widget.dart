import 'package:flutter/material.dart';

class BarChartWidget extends StatelessWidget {
  final Map<String, int> weeklyData;
  final double height;

  const BarChartWidget({
    super.key,
    required this.weeklyData,
    this.height = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = weeklyData.values.fold(0, (max, val) => val > max ? val : max);

    return SizedBox(
      height: height + 50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weeklyData.entries.map((entry) {
          final date = DateTime.parse(entry.key);
          final dayName = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][
              date.weekday == 7 ? 0 : date.weekday];
          final barHeight = maxValue > 0 ? (entry.value / maxValue) * height : 10.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Value label at top
                  Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Bar
                  Container(
                    height: barHeight.clamp(10.0, height),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: entry.value > 0 ? Colors.green : Colors.grey[300],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      boxShadow: entry.value > 0
                          ? [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Day name
                  Text(
                    dayName,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  // Date
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
