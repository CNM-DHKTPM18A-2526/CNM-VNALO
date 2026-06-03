import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/main.dart';
import 'package:vnalo_mobile/features/chat/providers/chat_provider.dart';
import 'package:vnalo_mobile/features/chat/screens/chat_detail_screen.dart';
import 'package:vnalo_mobile/services/storage_service.dart';
import 'package:vnalo_mobile/core/utils/device_info_util.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/notification_formatter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _disabled = false;

  static const String _mainChannelId = 'vnalo_main_channel';
  static const String _mainChannelName = 'Main Notifications';
  static const String _otpChannelId = 'otp_channel';
  static const String _otpChannelName = 'OTP Notifications';

  bool _shouldDisableFirebaseMessaging(Object error) {
    final normalized = error.toString().toLowerCase();
    return normalized.contains('fis_auth_error') ||
        normalized.contains('firebase installations can not communicate') ||
        normalized.contains('invalid configuration') ||
        normalized.contains('permission_denied') ||
        normalized.contains('the caller does not have permission');
  }

  void _handleFirebaseMessagingFailure(
    String stage,
    Object error, {
    StackTrace? stackTrace,
  }) {
    developer.log(
      '[NotificationService] $stage failed: $error',
      error: error,
      stackTrace: stackTrace,
    );

    if (_shouldDisableFirebaseMessaging(error)) {
      _disabled = true;
      developer.log(
        '[NotificationService] Firebase Messaging disabled for this session due to invalid/unavailable Firebase Installations configuration.',
      );
    }
  }

  Future<void> initialize() async {
    if (_initialized || _disabled) return;

    try {
      _fcm ??= FirebaseMessaging.instance;
    } catch (e) {
      developer.log(
        'NotificationService disabled: Firebase is not initialized. Error: $e',
      );
      _disabled = true;
      return;
    }

    // 1. Request permissions
    try {
      final settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        developer.log('User granted notification permission');
      }
    } catch (e, st) {
      _handleFirebaseMessagingFailure('requestPermission', e, stackTrace: st);
      if (_disabled) return;
    }

    // 2. Local Notifications Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/app_icon');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
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
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(mainChannel);

    const AndroidNotificationChannel otpChannel = AndroidNotificationChannel(
      _otpChannelId,
      _otpChannelName,
      description: 'High-priority OTP authentication notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(otpChannel);

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log(
        'Received foreground message: ${message.notification?.title}',
      );
      _showLocalNotification(message);
    });

    // 4. Handle Background/Terminated Messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('App opened from notification: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      developer.log('[NotificationService] FCM Token refreshed');
      final storage = StorageService();
      final token = await storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final info = await DeviceInfoUtil.getDeviceInfo();
        await registerTokenToBackend(
          accessToken: token,
          deviceId: info.deviceId,
          platform: info.platform,
          coreServiceUrl: AppConfig.instance.coreServiceUrl,
        );
      }
    });

    // 5. Setup CallKit Listeners
    FlutterCallkitIncoming.onEvent.listen(_onCallKitEvent);

    _initialized = true;
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final type = data['type']?.toString();
      final conversationId = data['conversationId']?.toString();
      
      if (type == 'chat_message' && conversationId != null && conversationId.isNotEmpty) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          final chatProvider = Provider.of<ChatProvider>(context, listen: false);
          final idx = chatProvider.conversations.indexWhere((c) => c.id == conversationId);
          if (idx != -1) {
            final conv = chatProvider.conversations[idx];
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => ChatDetailScreen(conversation: conv))
            );
          } else {
            developer.log('[NotificationService] Conversation $conversationId not found locally.');
          }
        }
      }
    } catch (e) {
      developer.log('[NotificationService] _handleNotificationTap error: $e');
    }
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
      
      final formatted = NotificationFormatter.formatNotification(data: data);
      final senderName = formatted.title != 'VNALO' ? formatted.title : (isGroup ? 'Cuộc gọi nhóm' : 'VNALO Call');

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

  Future<void> ensureInitialized() async {
    await initialize();
    await _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    if (_disabled || _fcm == null) return;
    try {
      final initialMessage = await _fcm!.getInitialMessage();
      if (initialMessage != null) {
        developer.log('[NotificationService] Opened from terminated state: ${initialMessage.data}');
        // Delay slightly to let the router and UI initialize
        Future.delayed(const Duration(milliseconds: 1000), () {
          _handleNotificationTap(initialMessage.data);
        });
      }
    } catch (e) {
      developer.log('[NotificationService] checkInitialMessage error: $e');
    }
  }

  Future<String?> getToken() async {
    await ensureInitialized();
    if (_disabled || _fcm == null) return null;

    try {
      return await _fcm!.getToken();
    } catch (e, st) {
      _handleFirebaseMessagingFailure('getToken', e, stackTrace: st);
      return null;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

    final displayContent = NotificationFormatter.formatNotification(
      data: message.data,
      remoteTitle: message.notification?.title,
      remoteBody: message.notification?.body,
    );

    await _localNotifications.show(
      id: message.hashCode,
      title: displayContent.title,
      body: displayContent.body,
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

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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

  /// Registers the FCM device token with the backend notification service.
  /// Returns true on success, false on failure (non-fatal).
  Future<bool> registerTokenToBackend({
    required String accessToken,
    required String deviceId,
    required String platform,
    required String coreServiceUrl,
  }) async {
    if (_disabled || _fcm == null) return false;

    final String? fcmToken = await getToken();
    if (fcmToken == null || fcmToken.isEmpty) {
      developer.log('[NotificationService] No FCM token available to register');
      return false;
    }

    try {
      final uri = Uri.parse(
        '$coreServiceUrl/notifications/devices'.replaceAll(
          '/api/v1',
          '/api/v1',
        ),
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'deviceId': deviceId,
              'platform': platform,
              'fcmToken': fcmToken,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        developer.log(
          '[NotificationService] FCM token registered successfully',
        );
        return true;
      } else {
        developer.log(
          '[NotificationService] FCM token registration failed: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      developer.log('[NotificationService] FCM token registration error: $e');
      return false;
    }
  }
}
