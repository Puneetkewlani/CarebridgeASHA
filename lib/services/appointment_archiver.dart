import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppointmentArchiver {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if we need to archive yesterday's completed appointments
  static Future<void> checkAndArchive(String ashaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastArchiveDate = prefs.getString('lastArchiveDate');
      
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      
      // If we haven't archived today, do it now
      if (lastArchiveDate != todayStr) {
        print('🗄️ Archiving completed appointments from previous days...');
        await _archiveCompletedAppointments(ashaId, todayStr);
        await prefs.setString('lastArchiveDate', todayStr);
        print('✅ Archive complete for $ashaId');
      }
    } catch (e) {
      print('❌ Archive error: $e');
    }
  }

  /// Move all completed appointments from before today to visits collection
  static Future<void> _archiveCompletedAppointments(String ashaId, String todayStr) async {
    try {
      // Get all appointments marked as done that are NOT from today
      final snapshot = await _firestore
          .collection('appointments')
          .where('ashaId', isEqualTo: ashaId)
          .where('status', isEqualTo: 'done')
          .get();

      int archivedCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final appointmentDate = data['date'] as String?;
        
        // Only archive if appointment date is before today
        if (appointmentDate != null && appointmentDate != todayStr) {
          // Create visit record
          await _firestore.collection('visits').add({
            'ashaId': ashaId,
            'childName': data['childName'] ?? '',
            'vaccination': data['vaccination'] ?? '',
            'age': data['age'] ?? '',
            'address': data['address'] ?? '',
            'phone': data['phone'] ?? '',
            'date': appointmentDate,
            'appointmentId': doc.id,
            'createdAt': data['completedAt'] ?? FieldValue.serverTimestamp(),
            'completedAt': data['completedAt'] ?? FieldValue.serverTimestamp(),
            'archivedAt': FieldValue.serverTimestamp(),
          });

          // Delete the appointment from appointments collection
          await _firestore.collection('appointments').doc(doc.id).delete();
          
          archivedCount++;
        }
      }

      print('📦 Archived $archivedCount completed appointments');
    } catch (e) {
      print('Error archiving appointments: $e');
    }
  }

  /// Manually trigger archive (for testing or manual refresh)
  static Future<void> forceArchive(String ashaId) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await _archiveCompletedAppointments(ashaId, todayStr);
  }
}
