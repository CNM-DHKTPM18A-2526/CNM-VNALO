/// Optional hook for [ApiService] to notify auth layer when tokens are cleared
/// after a non-recoverable refresh failure (revoked / expired refresh token).
class AuthEvents {
  static Future<void> Function()? onSessionInvalidated;
  static Future<void> Function(String reason)? onForceLogout;
}
