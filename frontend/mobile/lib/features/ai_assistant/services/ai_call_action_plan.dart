import 'package:flutter/material.dart';

class AiCallActionPlan {
  final bool isVideo;

  const AiCallActionPlan({required this.isVideo});

  factory AiCallActionPlan.fromParams(Map<String, dynamic>? params) {
    final callType = params?['callType']?.toString().toLowerCase().trim();
    return AiCallActionPlan(isVideo: callType == 'video');
  }

  IconData get icon => isVideo ? Icons.videocam_rounded : Icons.call_rounded;

  String get callTypeName => isVideo ? 'video' : 'thoại';

  String get title => 'Xác nhận gọi $callTypeName';

  String get description =>
      'Trợ lý sẽ bắt đầu cuộc gọi tới liên hệ đã chọn.';

  String get confirmLabel => 'Bắt đầu gọi';

  String get cancelMessage => 'Đã hủy thao tác gọi.';

  String get unsupportedGroupMessage =>
      'Tính năng gọi điện hiện chỉ hỗ trợ hội thoại 1-1.';

  String get analyticsCallType => isVideo ? 'video' : 'voice';
}
