import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer' as developer;
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _disabled = false;

  static const String _mainChannelId = 'vnalo_main_channel';
  static const String _mainChannelName = 'Main Notifications';

  Future<void> initialize() async {
    if (_initialized || _disabled) return;

    try {
      _fcm ??= FirebaseMessaging.instance;
    } catch (e) {
      developer.log('NotificationService disabled: Firebase is not initialized. Error: $e');
      _disabled = true;
      return;
    }

    // 1. Request permissions
    NotificationSettings settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      developer.log('User granted notification permission');
    }

    // 2. Local Notifications Setup
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click here
      },
    );

    const AndroidNotificationChannel mainChannel = AndroidNotificationChannel(
      _mainChannelId,
      _mainChannelName,
      description: 'General VNALO notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(mainChannel);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('Received foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // 4. Handle Background/Terminated Messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('App opened from notification: ${message.data}');
    });

    _initialized = true;
  }

  Future<void> ensureInitialized() => initialize();

  Future<String?> getToken() async {
    await ensureInitialized();
    if (_disabled || _fcm == null) return null;
    return await _fcm!.getToken();
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _mainChannelId,
      _mainChannelName,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }

  Future<void> showChatNotification({
    required String conversationId,
    required String title,
    required String body,
    String? senderId,
  }) async {
    await ensureInitialized();
    if (_disabled) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _mainChannelId,
      _mainChannelName,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'type': 'chat_message',
      'conversationId': conversationId,
      if (senderId != null) 'senderId': senderId,
    });

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
