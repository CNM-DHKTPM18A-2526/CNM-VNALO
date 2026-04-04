class UserSettings {
  final String userId;
  final String language; // "vi", "en"
  final String theme; // "LIGHT", "DARK", "SYSTEM"
  final String fontSize; // "SMALL", "MEDIUM", "LARGE"
  final bool notificationSound;
  final bool notificationVibrate;
  final bool notificationPreview;
  final bool autoDownloadImage;
  final bool autoDownloadVideo;
  final bool autoDownloadFile;

  UserSettings({
    required this.userId,
    this.language = 'vi',
    this.theme = 'LIGHT',
    this.fontSize = 'MEDIUM',
    this.notificationSound = true,
    this.notificationVibrate = true,
    this.notificationPreview = true,
    this.autoDownloadImage = true,
    this.autoDownloadVideo = false,
    this.autoDownloadFile = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
    userId: json['userId'],
    language: json['language'] ?? 'vi',
    theme: json['theme'] ?? 'LIGHT',
    fontSize: json['fontSize'] ?? 'MEDIUM',
    notificationSound: json['notificationSound'] ?? true,
    notificationVibrate: json['notificationVibrate'] ?? true,
    notificationPreview: json['notificationPreview'] ?? true,
    autoDownloadImage: json['autoDownloadImage'] ?? true,
    autoDownloadVideo: json['autoDownloadVideo'] ?? false,
    autoDownloadFile: json['autoDownloadFile'] ?? false,
  );
}
