import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
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

    // 5. Setup CallKit Listeners
    FlutterCallkitIncoming.onEvent.listen(_onCallKitEvent);

    _initialized = true;
  }

  static void _onCallKitEvent(CallEvent? event) {
    if (event == null) return;
    developer.log('[NotificationService] CallKit Event: ${event.event}');
    
    switch (event.event) {
      case Event.actionCallAccept:
        // Handle acceptance - redirection is typically handled by IncomingCallCoordinator
        // but we can log it here.
        break;
      case Event.actionCallDecline:
        // Handle decline
        break;
      default:
        break;
    }
  }

  /// Static handler for background messages, called from main.dart
  static Future<void> handleBackgroundCallSignal(RemoteMessage message) async {
    final data = message.data;
    final type = data['type']?.toString();
    
    if (type == 'call_offer' || type == 'group_call_started') {
      final isGroup = type == 'group_call_started';
      final callId = data['callId']?.toString() ?? const Uuid().v4();
      final conversationId = data['conversationId']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? (isGroup ? 'Cuộc gọi nhóm' : 'VNALO Call');
      final senderAvatar = data['senderAvatar']?.toString();
      final audioOnly = data['audioOnly']?.toString() == 'true';

      final params = CallKitParams(
        id: callId,
        nameCaller: senderName,
        appName: 'VNALO',
        avatar: senderAvatar,
        handle: isGroup ? 'Cuộc gọi nhóm' : 'VNALO',
        type: audioOnly ? 0 : 1, // 0: Audio, 1: Video
        duration: 30000,
        textAccept: 'Trả lời',
        textDecline: 'Từ chối',
        missedCallNotification: const NotificationParams(
          showNotification: true,
          isShowCallback: true,
          subtitle: 'Cuộc gọi nhỡ',
          callbackText: 'Gọi lại',
        ),
        extra: <String, dynamic>{
          'conversationId': conversationId,
          'callId': callId,
          'senderId': data['senderUserId']?.toString(),
          'initialSdp': data['sdp'],
          'isGroup': isGroup,
        },
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0068FF',
          backgroundUrl: 'assets/images/call_bg.png',
          actionColor: '#4CAF50',
          incomingCallNotificationChannelName: 'VNALO Incoming Call',
        ),
        ios: const IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: true,
          maximumCallGroups: 1,
          supportsGrouping: false,
          supportsUngrouping: false,
          supportsHolding: false,
          audioSessionMode: 'default',
          audioSessionActive: true,
          maximumCallsPerCallGroup: 1,
          supportsDTMF: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(params);
    }
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
