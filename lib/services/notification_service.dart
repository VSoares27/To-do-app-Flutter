import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart';

/// Wraps flutter_local_notifications. Every method is defensive: if the
/// platform refuses permission or scheduling fails, we log and continue so the
/// app never crashes because of notifications.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _permissionGranted = false;

  bool get permissionGranted => _permissionGranted;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('Timezone init failed, falling back to UTC: $e');
    }

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notification init failed: $e');
    }
  }

  /// Requests permission on Android 13+ / iOS. Returns false when denied.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        _permissionGranted =
            await android.requestNotificationsPermission() ?? false;
        return _permissionGranted;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        _permissionGranted = await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
        return _permissionGranted;
      }
      _permissionGranted = true;
      return true;
    } catch (e) {
      debugPrint('Permission request failed: $e');
      _permissionGranted = false;
      return false;
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Task reminders',
      channelDescription: 'Reminders for tasks with a due date',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Cancels any existing reminder for [task] and schedules a new one when the
  /// task is pending and its due date is in the future.
  Future<void> sync(Task task) async {
    final id = task.notificationId ?? task.id;
    if (id == null) return;
    await cancel(id);

    final due = task.dueDateTime;
    if (task.completed || due == null) return;
    if (!due.isAfter(DateTime.now())) return;
    if (!_ready) return;

    try {
      await _plugin.zonedSchedule(
        id,
        'Task reminder',
        task.title,
        tz.TZDateTime.from(due, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: '${task.id}',
      );
    } catch (e) {
      debugPrint('Scheduling notification $id failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('Cancel notification $id failed: $e');
    }
  }
}
