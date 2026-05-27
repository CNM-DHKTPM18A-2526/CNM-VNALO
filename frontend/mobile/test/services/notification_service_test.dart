import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/services/notification_service.dart';

const MethodChannel _firebaseChannel = MethodChannel(
  'plugins.flutter.io/firebase_messaging',
);
const MethodChannel _localNotificationsChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() {
    messenger.setMockMethodCallHandler(_firebaseChannel, (call) async {
      switch (call.method) {
        case 'Messaging#requestPermission':
          return <String, int>{'authorizationStatus': 1};
        case 'Messaging#getToken':
          throw PlatformException(
            code: 'unknown',
            message: 'java.io.IOException: FIS_AUTH_ERROR',
          );
        default:
          return null;
      }
    });

    messenger.setMockMethodCallHandler(_localNotificationsChannel, (
      call,
    ) async {
      switch (call.method) {
        case 'initialize':
          return true;
        case 'createNotificationChannel':
          return null;
        default:
          return null;
      }
    });
  });

  tearDownAll(() {
    messenger.setMockMethodCallHandler(_firebaseChannel, null);
    messenger.setMockMethodCallHandler(_localNotificationsChannel, null);
  });

  test(
    'NotificationService.getToken handles FIS auth failure without throwing',
    () async {
      final service = NotificationService();
      final token = await service.getToken();
      expect(token, isNull);
    },
  );
}
