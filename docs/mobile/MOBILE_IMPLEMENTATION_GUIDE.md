# VNALO Mobile App - Hướng Dẫn Triển Khai Chi Tiết

> **Platform**: Flutter (iOS + Android)  
> **Dart SDK**: ^3.7.2 (Flutter 3.29+)  
> **Project path**: `frontend/mobile/`  
> **Cập nhật**: March 20, 2026
>
> Reconcile note (2026-03-20): Guide này đã được đối chiếu lại với backend runtime hiện tại (core-service 8081, message-service 3000 mặc định) và cấu trúc Flutter hiện có trong `frontend/mobile/lib`.
>
> Sync note (2026-03-22): Một số utility được nhắc trong guide (validators/date_formatter) hiện chưa có file vật lý trong repo. Các đoạn đó được giữ ở mức blueprint và cần tạo file trước khi dùng trực tiếp.

> [!WARNING]
> **Backend Mới Nhất (2026-04-23)**: Backend đã được cập nhật ĐẦY ĐỦ để khớp với `docs/sdd/layer-2/`. Các business rule mới nhất (role ADMIN/DEPUTY thay cho OWNER/ADMIN, onlyAdminCanPost, group disband cascade, system messages) ĐÃ HOÀN THIỆN trên Backend. Mobile Client cần tích hợp thêm các API và WebSocket Events mới này (tham khảo `api-reference.md`).

---

## Mục Lục Tổng Quan (4 phần)

| Phần | File | Nội dung |
|------|------|----------|
| **1** | `MOBILE_IMPLEMENTATION_GUIDE.md` | Prerequisites, Setup, Core Layer, Environment Config |
| **2** | `MOBILE_IMPLEMENTATION_GUIDE_P2.md` | Models, Services, WebSocket, Providers |
| **3** | `MOBILE_IMPLEMENTATION_GUIDE_P3.md` | Auth & Chat Screens |
| **4** | `MOBILE_IMPLEMENTATION_GUIDE_P4.md` | Contacts, Timeline, Profile, Settings, Navigation, Testing |

---

## 1. Kiến Thức Cần Nắm Vững

### 1.1 Dart Fundamentals

#### Null Safety
```dart
// Dart 3+ bắt buộc null safety
String name = 'VNALO';        // Không thể null
String? nickname;              // Có thể null
String display = nickname ?? 'Unknown'; // Null coalescing
print(nickname?.length);       // Null-aware access
```

#### Async/Await & Future
```dart
// Tất cả giao tiếp API đều trả về Future
Future<User> fetchUser() async {
  final response = await http.get(Uri.parse('$baseUrl/users/me'));
  if (response.statusCode == 200) {
    return User.fromJson(jsonDecode(response.body));
  }
  throw Exception('Failed to load user');
}

// Sử dụng FutureBuilder trong UI
FutureBuilder<User>(
  future: fetchUser(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return CircularProgressIndicator();
    }
    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
    return Text(snapshot.data!.displayName);
  },
);
```

#### Stream (quan trọng cho real-time chat)
```dart
// WebSocket trả về Stream → dùng StreamBuilder để auto-update UI
StreamBuilder<Message>(
  stream: socketService.onMessage, // Stream từ WebSocket
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return MessageBubble(message: snapshot.data!);
    }
    return SizedBox.shrink();
  },
);
```

#### JSON Serialization
```dart
class User {
  final String id;
  final String displayName;
  final String? avatarUrl;

  User({required this.id, required this.displayName, this.avatarUrl});

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'],
    displayName: json['displayName'],
    avatarUrl: json['avatarUrl'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
  };
}
```

### 1.2 Flutter Fundamentals

#### Widget Lifecycle (quan trọng nhất)
```dart
class ChatScreen extends StatefulWidget {
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Khởi tạo: load data, connect socket
  }

  @override
  void dispose() {
    // Dọn dẹp: close socket, cancel subscriptions
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(/* UI */);
  }
}
```

#### Các Widget Quan Trọng Cho Dự Án

| Widget | Dùng Cho |
|--------|----------|
| `ListView.builder` | Chat list, contact list, message list |
| `CircleAvatar` | Avatar người dùng (48dp, 72dp) |
| `TextField` / `TextFormField` | Input tin nhắn, form đăng ký |
| `BottomNavigationBar` | 5 tabs chính |
| `TabBar` + `TabBarView` | Sub-tabs (Bạn bè / Nhóm / OA) |
| `Dismissible` / `Slidable` | Swipe actions trên chat list |
| `StreamBuilder` | Real-time messages từ WebSocket |
| `Badge` | Số tin nhắn chưa đọc |

### 1.3 State Management — Provider Pattern

```dart
// Provider giúp quản lý state và tự động rebuild UI khi data thay đổi
class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners(); // → UI rebuild hiển thị loading

    try {
      _user = await _authService.login(phone, password);
    } finally {
      _isLoading = false;
      notifyListeners(); // → UI rebuild hiển thị kết quả
    }
  }
}

// 2. Lắng nghe các event mới về Group Management
socketService.onGroupEvent.listen((event) {
  if (event.type == 'group.memberAdded') {
     // Hiển thị toast, play sound, update danh sách thành viên...
  } else if (event.type == 'group.disbanded') {
     // Kick user ra khỏi màn hình chat, hiển thị popup "Nhóm đã giải tán"
  }
});
```

### 1.4 Dependencies (Phiên bản chính xác theo pubspec.yaml hiện tại)

| Package | Version | Mục đích |
|---------|---------|----------|
| `provider` | ^6.1.0 | State management |
| `http` | ^1.6.0 | REST API calls |
| `socket_io_client` | ^3.1.4 | WebSocket real-time chat |
| `shared_preferences` | ^2.5.4 | Lưu settings (theme mode, v.v.) |
| `flutter_secure_storage` | ^10.0.0 | Lưu token an toàn |
| `cached_network_image` | ^3.4.1 | Cache ảnh avatar/media |
| `flutter_slidable` | ^4.0.3 | Swipe actions (ghim, xóa chat) |
| `pin_code_fields` | ^9.1.0 | OTP input 6 ô |
| `badges` | ^3.1.2 | Badge số tin chưa đọc |
| `image_picker` | ^1.2.1 | Chọn ảnh camera/gallery |
| `qr_flutter` | ^4.1.0 | Hiển thị QR code |
| `mobile_scanner` | ^7.2.0 | Scan QR code |
| `intl` | ^0.20.2 | Format date/time |
| `permission_handler` | ^12.0.1 | Quyền camera, contacts |
| `flutter_local_notifications` | ^21.0.0 | Thông báo local |
| `google_fonts` | ^8.0.2 | Font Inter |

> **Lưu ý**: Dart SDK ^3.7.2 tương ứng Flutter 3.29+. Đây là phiên bản rất mới, đảm bảo hỗ trợ đầy đủ Material 3 và các API mới nhất.

---

## 2. Cấu Trúc Thư Mục (Đã rà soát)

```
frontend/mobile/lib/
├── main.dart                          # Entry point + App setup
├── config/                            # ✅ Environment configuration (đang dùng)
│   ├── app_config.dart                # Base URL, feature flags
│   └── env.dart                       # Environment enum + loader
│
├── core/                              # ✅ Đã có trong project
│   ├── theme/                         # ✅ Đã implement
│   │   ├── app_colors.dart            # ✅ Dark colors đã có
│   │   ├── app_colors_light.dart      # 🆕 Light mode colors
│   │   ├── app_typography.dart        # ✅ Google Fonts Inter
│   │   ├── app_theme.dart             # ✅ Có cả darkTheme + lightTheme
│   │   └── app_constants.dart         # ✅ Spacing + Sizes
│   ├── utils/
│   │   ├── validators.dart
│   │   └── date_formatter.dart
│   └── widgets/
│       ├── avatar_widget.dart
│       ├── loading_indicator.dart
│       └── empty_state_widget.dart
│
├── features/                          # ✅ Thư mục đã có (chưa có code)
│   ├── auth/
│   ├── chat/
│   ├── contacts/
│   ├── discover/
│   ├── timeline/
│   └── profile/
│
├── models/
├── services/
└── navigation/
```

---

## 3. Environment Configuration (KHÔNG Hardcode)

> ⚠️ **QUAN TRỌNG**: Không bao giờ hardcode URL, API key, hoặc cấu hình vào source code. Sử dụng pattern Environment Config để dễ dàng chuyển đổi giữa dev/staging/production.

### 3.1 env.dart — Environment Enum

```dart
// lib/config/env.dart

/// Các môi trường triển khai
enum Environment { dev, staging, production }

class EnvConfig {
  final Environment environment;
  final String coreServiceUrl;
  final String messageServiceUrl;
  final String socketUrl;
  final bool enableLogging;
  final bool enableCrashlytics;

  const EnvConfig({
    required this.environment,
    required this.coreServiceUrl,
    required this.messageServiceUrl,
    required this.socketUrl,
    this.enableLogging = false,
    this.enableCrashlytics = false,
  });

  bool get isDev => environment == Environment.dev;
  bool get isProd => environment == Environment.production;
}
```

### 3.2 app_config.dart — Configuration Loader

```dart
// lib/config/app_config.dart
import 'env.dart';

/// Singleton giữ config xuyên suốt app lifecycle
class AppConfig {
  static late EnvConfig _config;

  static EnvConfig get instance => _config;

  /// Gọi 1 lần duy nhất trong main() trước runApp()
  static void initialize(Environment env) {
    switch (env) {
      case Environment.dev:
        _config = const EnvConfig(
          environment: Environment.dev,
          // Android Emulator: 10.0.2.2, iOS Sim: localhost, Device: LAN IP
          coreServiceUrl: 'http://10.0.2.2:8081/api/v1',
          messageServiceUrl: 'http://10.0.2.2:3000/api/v1',
          socketUrl: 'http://10.0.2.2:3000',
          enableLogging: true,
        );
        break;
      case Environment.staging:
        _config = const EnvConfig(
          environment: Environment.staging,
          coreServiceUrl: 'https://staging-api.vnalo.com/api/v1',
          messageServiceUrl: 'https://staging-msg.vnalo.com/api/v1',
          socketUrl: 'https://staging-msg.vnalo.com',
          enableLogging: true,
          enableCrashlytics: true,
        );
        break;
      case Environment.production:
        _config = const EnvConfig(
          environment: Environment.production,
          coreServiceUrl: 'https://api.vnalo.com/api/v1',
          messageServiceUrl: 'https://msg.vnalo.com/api/v1',
          socketUrl: 'https://msg.vnalo.com',
          enableCrashlytics: true,
        );
        break;
    }
  }
}
```

### 3.3 Sử dụng trong main.dart

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/env.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Chọn environment — có thể dùng --dart-define để inject từ CLI
  // flutter run --dart-define=ENV=dev
  const envName = String.fromEnvironment('ENV', defaultValue: 'dev');
  final env = Environment.values.firstWhere(
    (e) => e.name == envName,
    orElse: () => Environment.dev,
  );

  AppConfig.initialize(env);
  runApp(const VnaloApp());
}

class VnaloApp extends StatelessWidget {
  const VnaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..initialize(),
      child: Consumer<ThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: 'VNALO',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          // home: const SplashScreen(),
        ),
      ),
    );
  }
}
```

```bash
# Chạy với environment cụ thể
flutter run --dart-define=ENV=dev
flutter run --dart-define=ENV=staging
flutter build apk --dart-define=ENV=production
```

### 3.4 API Endpoints (dùng config thay vì hardcode)

```dart
// lib/core/constants/api_endpoints.dart
import '../config/app_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  // URLs tự động lấy từ config, KHÔNG hardcode
  static String get coreBaseUrl => AppConfig.instance.coreServiceUrl;
  static String get messageBaseUrl => AppConfig.instance.messageServiceUrl;
  static String get socketUrl => AppConfig.instance.socketUrl;

  // ─── Auth ───
  static const String sendOtp = '/auth/register/send-otp';
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // ─── Users ───
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
```

---

## 4. Core Layer — Theme System 3 Chế Độ (Sáng / Tối / Hệ Thống)

> Tham khảo từ screenshot Zalo: Cài đặt → Giao diện và ngôn ngữ → 3 chế độ: Sáng, Tối, Hệ thống

### 4.1 Theme Mode Enum & Provider

```dart
// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider quản lý chế độ giao diện (Sáng / Tối / Hệ thống)
class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system; // Mặc định: theo hệ thống

  ThemeMode get themeMode => _themeMode;

  /// Khởi tạo: đọc setting đã lưu từ SharedPreferences
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => ThemeMode.system,
      );
    }
    notifyListeners();
  }

  /// Thay đổi theme mode và lưu
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  /// Helper cho UI hiển thị
  String get label {
    switch (_themeMode) {
      case ThemeMode.light: return 'Sáng';
      case ThemeMode.dark: return 'Tối';
      case ThemeMode.system: return 'Hệ thống';
    }
  }
}
```

### 4.2 AppColors — Tách riêng Light và Dark

```dart
// lib/core/theme/app_colors.dart
// Đã refactor: tách thành 2 bộ màu riêng biệt

import 'package:flutter/material.dart';

/// Màu chung cho cả 2 themes
class AppColors {
  AppColors._();

  // ─── Primary (giống nhau cả 2 theme) ───
  static const Color primary = Color(0xFF0068FF);
  static const Color primaryLight = Color(0xFF00A2ED);
  static const Color primaryDark = Color(0xFF0050CC);

  // ─── Semantic ───
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color online = Color(0xFF22C55E);
  static const Color unreadBadge = Color(0xFFEF4444);
  static const Color pinIcon = Color(0xFFF59E0B);
}

/// Bộ màu cho Dark Theme
class DarkColors {
  DarkColors._();
  static const Color scaffold = Color(0xFF1A1A1A);
  static const Color surface = Color(0xFF242424);
  static const Color surfaceLight = Color(0xFF2A2A2A);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);
  static const Color textHint = Color(0xFF808080);
  static const Color divider = Color(0xFF333333);
  static const Color chatBubbleSent = Color(0xFF0068FF);
  static const Color chatBubbleReceived = Color(0xFF3A3A3A);
  static const Color appBarBg = Color(0xFF1A1A1A);
}

/// Bộ màu cho Light Theme (tham khảo Zalo light mode)
class LightColors {
  LightColors._();
  static const Color scaffold = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF0F0F0);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color chatBubbleSent = Color(0xFF0068FF);
  static const Color chatBubbleReceived = Color(0xFFE8E8E8);
  static const Color appBarBg = Color(0xFF0068FF);   // AppBar xanh (Zalo style)
}
```

### 4.3 AppTheme — Cả Light + Dark (sửa lightTheme dùng đúng màu sáng)

```dart
// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════
  //  DARK THEME
  // ═══════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: DarkColors.scaffold,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: DarkColors.surface,
      error: AppColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: DarkColors.appBarBg,
      elevation: 0,
      titleTextStyle: AppTypography.titleLarge,
      iconTheme: const IconThemeData(color: DarkColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DarkColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: DarkColors.textHint,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DarkColors.surface,
      hintStyle: AppTypography.bodyMedium.copyWith(color: DarkColors.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerColor: DarkColors.divider,
  );

  // ═══════════════════════════════════════════
  //  LIGHT THEME (sửa: dùng LightColors thay vì dark)
  // ═══════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: LightColors.scaffold,
    primaryColor: AppColors.primary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: LightColors.surface,
      error: AppColors.error,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: LightColors.appBarBg,
      elevation: 0,
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: Colors.white,  // Text trắng trên nền xanh
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: LightColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: LightColors.textHint,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LightColors.surfaceLight,
      hintStyle: AppTypography.bodyMedium.copyWith(color: LightColors.textHint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    dividerColor: LightColors.divider,
  );
}
```

### 4.4 Tích hợp Theme vào App

```dart
// lib/main.dart — sử dụng ThemeProvider để chuyển đổi 3 chế độ
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

class VnaloApp extends StatelessWidget {
  const VnaloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (_, themeProvider, __) => MaterialApp(
        title: 'VNALO',
        debugShowCheckedModeBanner: false,
        // 3 themes: light, dark, và system (tự theo OS)
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode, // ← key line
        // home: const SplashScreen(),
      ),
    );
  }
}
```

### 4.5 Sử dụng theme-aware colors trong Widget

```dart
// ❌ SAI: hardcode màu → không đổi khi switch theme
Text('Hello', style: TextStyle(color: Color(0xFF1A1A1A)));

// ✅ ĐÚNG: dùng Theme.of(context) → tự đổi theo theme
Text('Hello', style: TextStyle(
  color: Theme.of(context).colorScheme.onSurface,
));

// ✅ ĐÚNG: dùng context extension cho tiện
Container(
  color: Theme.of(context).colorScheme.surface,
  child: Text('Card content',
    style: Theme.of(context).textTheme.bodyMedium),
);
```

---

## 5. Core Widgets & Utilities

### 5.1 Validators (blueprint - file chưa có trong repo hiện tại)
```dart
// lib/core/utils/validators.dart
// TODO: tạo file này trước khi triển khai form validation theo Phần 3.
```

### 5.2 Date Formatter (blueprint - file chưa có trong repo hiện tại)
```dart
// lib/core/utils/date_formatter.dart
// TODO: tạo file này trước khi triển khai format thời gian cho chat/timeline.
```

### 5.3 Avatar Widget — Theme-Aware

```dart
// lib/core/widgets/avatar_widget.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool showOnline;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.showOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    // Dùng theme để tự đổi màu background theo light/dark
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: AppColors.primary.withOpacity(0.2),
          backgroundImage: imageUrl != null
              ? CachedNetworkImageProvider(imageUrl!)
              : null,
          child: imageUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
        if (showOnline)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.surface, // Tự đổi theo theme
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

---

> **Tiếp theo**: Xem **Phần 2** (`MOBILE_IMPLEMENTATION_GUIDE_P2.md`) cho Models, Services, WebSocket, Providers.
