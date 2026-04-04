import 'package:vnalo_mobile/config/app_config.dart';

class ApiEndpoints {
  ApiEndpoints._(); // Private constructor to prevent instantiation

  // Base URL for the API
  static String get coreBaseUrl => AppConfig.instance.coreServiceUrl;
  static String get messageBaseUrl => AppConfig.instance.messageServiceUrl;
  static String get socketUrl => AppConfig.instance.socketUrl;

  // Authentication endpoints
  static const String sendOtp = '/auth/register/send-otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  // User endponints
  static const String userMe = '/users/me';
  static String userById(String id) => '/users/$id';
  static const String userSearch = '/users/search';
  static const String userPrivacy = '/users/me/privacy';

  // ─── Friends ───
  static const String friends = '/friends';
  static const String friendRequests = '/friends/requests';
  static const String friendRequestsIncoming = '/friends/requests/incoming';
  static const String friendRequestsSent = '/friends/requests/sent';
  static String acceptRequest(String id) => '/friends/requests/$id/accept';
  static String declineRequest(String id) => '/friends/requests/$id/decline';

  // ─── Messages ───
  static const String conversations = '/conversations';
  static const String conversationDirect = '/conversations/direct';
  static const String conversationGroup = '/conversations/group';
  static const String messages = '/messages';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static const String inbox = '/inbox';

  // ─── QR ───
  static const String qrGenerate = '/qr/generate';
  static const String qrScan = '/qr/scan';
}
