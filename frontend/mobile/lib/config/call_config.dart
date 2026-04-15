import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for WebRTC ICE Servers (STUN/TURN).
/// For production, it's recommended to use a managed service like Metered.ca or XirSys.
class CallConfig {
  /// Toggle to use specialized STUN/TURN servers instead of just Google STUN.
  static bool get useManagedIceServers => (dotenv.env['USE_MANAGED_ICE_SERVERS'] ?? 'true').toLowerCase() == 'true';

  /// Metered.ca Free Tier credentials fetched from .env
  static String get turnUsername => dotenv.env['TURN_USERNAME'] ?? '';
  static String get turnCredential => dotenv.env['TURN_PASSWORD'] ?? '';

  static List<Map<String, dynamic>> getIceServers() {
    if (!useManagedIceServers) {
      return [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }

    return [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      // Managed TURN servers (Metered.ca Example)
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443',
          'turn:openrelay.metered.ca:443?transport=tcp'
        ],
        'username': turnUsername,
        'credential': turnCredential,
      },
      // Note: Metered.ca also provides STUN servers usually included in the same group.
    ];
  }

  static void logConfig() {
    debugPrint('[CallConfig] useManagedIceServers=$useManagedIceServers');
  }
}
