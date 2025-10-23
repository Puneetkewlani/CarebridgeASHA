import 'package:flutter/material.dart';

class AppointmentCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onMarkComplete;
  final VoidCallback onDelete;
  final VoidCallback? onReschedule;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onMarkComplete,
    required this.onDelete,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final status = appointment['status'] ?? 'pending';
    final isDone = status == 'done';
    
    // ✅ Check appointment date vs today
    final appointmentDateStr = appointment['date'] as String?;
    DateTime? appointmentDate;
    
    if (appointmentDateStr != null) {
      try {
        appointmentDate = DateTime.parse(appointmentDateStr);
      } catch (e) {
        print('Error parsing appointment date: $appointmentDateStr');
      }
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    bool isToday = false;
    bool isPast = false;
    bool isFuture = false;
    
    if (appointmentDate != null) {
      final apptDay = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day);
      isToday = apptDay.isAtSameMomentAs(today);
      isPast = apptDay.isBefore(today);
      isFuture = apptDay.isAfter(today);
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle : isPast ? Icons.warning : Icons.pending,
                  color: isDone ? Colors.green : isPast ? Colors.red : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment['childName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Age: ${appointment['age'] ?? 'N/A'} months',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isPast && !isDone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isFuture)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'UPCOMING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
            _buildInfoRow(Icons.vaccines, 'Vaccine', appointment['vaccination'] ?? 'N/A'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.phone, 'Phone', appointment['phone'] ?? 'N/A'),
            const SizedBox(height: 4),
            _buildInfoRow(Icons.location_on, 'Address', appointment['address'] ?? 'N/A'),
            
            // ✅ Only show action buttons if not done
            if (!isDone) ...[
              const SizedBox(height: 12),
              _buildActionButtons(isToday: isToday, isPast: isPast, isFuture: isFuture),
            ],
          ],
        ),
      ),
    );
  }

  // ✅ Updated: Build action buttons based on date status
  // ✅ Updated: Build action buttons based on date status
Widget _buildActionButtons({required bool isToday, required bool isPast, required bool isFuture}) {
  // Case 1: Today's appointment - Show Complete, Reschedule, Delete
  if (isToday) {
    if (onReschedule != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onMarkComplete,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onReschedule,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Reschedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onMarkComplete,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Complete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
  
  // Case 2 & 3: Past or Future appointments - Show only Reschedule and Delete
  if (isPast || isFuture) {
    if (onReschedule != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onReschedule,
              icon: const Icon(Icons.calendar_today, size: 18),
              label: const Text('Reschedule'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPast ? Colors.orange : Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // No reschedule callback - show only Delete (full width)
      return ElevatedButton.icon(
        onPressed: onDelete,
        icon: const Icon(Icons.delete, size: 18),
        label: const Text('Delete Appointment'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
  
  // Fallback: Show only Delete
  return ElevatedButton.icon(
    onPressed: onDelete,
    icon: const Icon(Icons.delete, size: 18),
    label: const Text('Delete'),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}


  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: $value',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
