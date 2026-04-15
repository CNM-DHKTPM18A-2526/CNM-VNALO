import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  @override
  String toString() => 'DeviceInfo(id: $deviceId, name: $deviceName, platform: $platform)';
}

class DeviceInfoUtil {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  static Future<DeviceInfo> getDeviceInfo() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfoPlugin.webBrowserInfo;
        return DeviceInfo(
          deviceId: webInfo.userAgent ?? 'WEB_UNKNOWN',
          deviceName: webInfo.browserName.name,
          platform: 'WEB',
        );
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return DeviceInfo(
          deviceId: androidInfo.id, // Android ID
          deviceName: '${androidInfo.manufacturer} ${androidInfo.model}',
          platform: 'ANDROID',
        );
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return DeviceInfo(
          deviceId: iosInfo.identifierForVendor ?? 'IOS_UNKNOWN',
          deviceName: iosInfo.name,
          platform: 'IOS',
        );
      } else if (Platform.isWindows) {
        final winInfo = await _deviceInfoPlugin.windowsInfo;
        return DeviceInfo(
          deviceId: winInfo.deviceId,
          deviceName: winInfo.computerName,
          platform: 'WINDOWS',
        );
      }
    } catch (e) {
      debugPrint('[DeviceInfoUtil] Error fetching device info: $e');
    }

    return DeviceInfo(
      deviceId: 'UNKNOWN_ID',
      deviceName: 'Unknown Device',
      platform: Platform.isAndroid ? 'ANDROID' : (Platform.isIOS ? 'IOS' : 'OTHER'),
    );
  }
}
