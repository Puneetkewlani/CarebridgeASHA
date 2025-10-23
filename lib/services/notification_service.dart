import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    }

    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
      },
    );

    // Create notification channel for Android
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Get and save FCM token
    String? token = await _fcm.getToken();
    if (token != null) {
      await _saveFCMToken(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveFCMToken);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _saveFCMToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Try to update in users collection (ASHA)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token});
      } catch (e) {
        // If not in users, try phc_staff collection
        try {
          await FirebaseFirestore.instance
              .collection('phc_staff')
              .doc(user.uid)
              .update({'fcmToken': token});
        } catch (e) {
          print('Error saving FCM token: $e');
        }
      }
      print('✅ FCM Token saved: $token');
    }
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Notification',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // ✅ Send notification for inventory request approval
  static Future<void> sendRequestApprovedNotification({
    required String ashaId,
    required String vaccineName,
    required int quantity,
  }) async {
    try {
      final ashaDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ashaId)
          .get();

      final fcmToken = ashaDoc.data()?['fcmToken'];
      
      if (fcmToken != null) {
        // In production, you'd call your backend to send FCM message
        // For now, we'll create a local notification record
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': ashaId,
          'title': 'Request Approved ✅',
          'body': 'Your request for $quantity units of $vaccineName has been approved.',
          'type': 'request_approved',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Notification sent for approved request');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // ✅ Send notification for inventory request rejection
  static Future<void> sendRequestRejectedNotification({
    required String ashaId,
    required String vaccineName,
  }) async {
    try {
      final ashaDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ashaId)
          .get();

      final fcmToken = ashaDoc.data()?['fcmToken'];
      
      if (fcmToken != null) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': ashaId,
          'title': 'Request Rejected ❌',
          'body': 'Your request for $vaccineName has been rejected.',
          'type': 'request_rejected',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        
        print('✅ Notification sent for rejected request');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // ✅ Send custom notification to specific user
  static Future<void> sendCustomNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'custom',
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': message,
        'type': type,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Custom notification sent to user: $userId');
    } catch (e) {
      print('Error sending custom notification: $e');
    }
  }

  // ✅ Send notification to all ASHA workers in a location
  static Future<void> sendBroadcastNotification({
    required String location,
    required String title,
    required String message,
  }) async {
    try {
      // Get all ASHA workers in this location
      final workers = await FirebaseFirestore.instance
          .collection('users')
          .where('location', isEqualTo: location)
          .get();

      // Send notification to each worker
      for (var worker in workers.docs) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': worker.id,
          'title': title,
          'body': message,
          'type': 'broadcast',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Broadcast sent to ${workers.docs.length} workers in $location');
    } catch (e) {
      print('Error sending broadcast notification: $e');
    }
  }
}

// Top-level function for background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message: ${message.notification?.title}');
}
