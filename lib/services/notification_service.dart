import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'rpg_session_notifications',
    'RPG Session Notifications',
    description: 'Notifications for upcoming RPG sessions',
    importance: Importance.high,
  );

  NotificationService() {
    if (!kIsWeb) {
      tz.initializeTimeZones();
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    final AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launcher_icon');
    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log("Foreground message received: ${message.notification?.title}");
      _showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log("App opened from background via notification");
    });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    if (kIsWeb) return;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.max,
      priority: Priority.high,
    );
    final DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails();
    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      platformChannelSpecifics,
    );
  }

  Future<void> scheduleSessionNotification(Session session) async {
    if (kIsWeb) return;

    final notificationsEnabled = await getNotificationsEnabled();
    if (!notificationsEnabled) return;

    // 30분 전 알림
    await _scheduleNotification(session, Duration(minutes: 30), '30 minutes');

    // 하루 전 알림
    await _scheduleNotification(session, Duration(days: 1), 'tomorrow');
  }

  Future<void> _scheduleNotification(Session session, Duration beforeStart, String timeDescription) async {
    final scheduledDate = tz.TZDateTime.from(
      session.startTime.subtract(beforeStart),
      tz.local,
    );

    developer.log('Scheduling notification for session: ${session.id}', name: 'NotificationService');
    developer.log('Scheduled notification time: $scheduledDate', name: 'NotificationService');

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      session.id.hashCode + beforeStart.inMinutes, // Unique ID for each notification
      'RPG Session Reminder',
      '${session.title} starts $timeDescription',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    developer.log('Notification scheduled for session: ${session.title} at ${scheduledDate.toString()}', name: 'NotificationService');
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (kIsWeb) {
      developer.log('Web platform detected, skipping notification cancellation', name: 'NotificationService');
      return;
    }

    developer.log('Cancelling all notifications', name: 'NotificationService');
    await _flutterLocalNotificationsPlugin.cancelAll();
    developer.log('All notifications cancelled', name: 'NotificationService');
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', enabled);

    if (enabled) {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        // TODO: 토큰을 서버에 보내 저장하는 로직 구현
        developer.log('FCM Token: $token', name: 'NotificationService');
      }
    } else {
      await _firebaseMessaging.deleteToken();
      await cancelAllNotifications();
    }
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notificationsEnabled') ?? false;
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    if (Platform.isAndroid) {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    }
    return true;
  }

  Future<void> requestDisableBatteryOptimization() async {
    if (Platform.isAndroid) {
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }
}