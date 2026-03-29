import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<DatabaseEvent>? _flagSubscription;

  int _lastNotifiedFlag = 0;

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidInit);

    await _notificationsPlugin.initialize(initSettings);

    // ✅ Android 13+ notification permission
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    _startListening();
  }

  void _startListening() {
    int _previousFlag = 0;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseDatabase.instance.ref(
      "users/${user.uid}/patients/dominic/commands",
    );

    _flagSubscription = ref.onValue.listen((event) {
      final data = event.snapshot.value;

      if (data is Map) {
        final flagLevel = data["flagLevel"] ?? 0;
        final slot = data["slot"] ?? "";
        final minutesLate = data["minutesLate"] ?? 0;

        print("flagLevel: $flagLevel");

        // 🔥 Trigger ONLY when 0 → 3 transition happens
        if (flagLevel == 3 && _previousFlag != 3) {
          print("🚨 TRIGGERING NOTIFICATION");

          _showNotification(slot, minutesLate);

          // Reset DB
          ref.update({"flagLevel": 0, "minutesLate": 0, "slot": ""});
        }

        _previousFlag = flagLevel;
      }
    });
  }

  Future<void> _showNotification(String slot, int minutesLate) async {
    const androidDetails = AndroidNotificationDetails(
      'missed_dose_channel',
      'Missed Dose Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      0,
      "Missed Medication Alert",
      "$slot dose missed. $minutesLate minutes overdue.",
      notificationDetails,
    );
  }

  void dispose() {
    _flagSubscription?.cancel();
  }
}
