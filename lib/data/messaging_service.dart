import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Registers this device for push notifications (sent by Cloud Functions).
class MessagingService {
  static bool _started = false;

  static Future<void> init(String uid) async {
    if (_started) return;
    _started = true;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      final token = await messaging.getToken();
      if (token != null) {
        await userRef.update({'fcmTokens': FieldValue.arrayUnion([token])});
      }
      messaging.onTokenRefresh.listen((t) {
        userRef.update({'fcmTokens': FieldValue.arrayUnion([t])});
      });
    } catch (_) {
      // Notifications are optional (e.g. web without a VAPID key).
    }
  }
}
