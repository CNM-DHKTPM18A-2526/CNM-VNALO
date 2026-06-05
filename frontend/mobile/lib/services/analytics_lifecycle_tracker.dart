import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

class AnalyticsLifecycleTracker extends StatefulWidget {
  final Widget child;

  const AnalyticsLifecycleTracker({super.key, required this.child});

  @override
  State<AnalyticsLifecycleTracker> createState() => _AnalyticsLifecycleTrackerState();
}

class _AnalyticsLifecycleTrackerState extends State<AnalyticsLifecycleTracker>
    with WidgetsBindingObserver {
  late final String _sessionId;
  DateTime? _startedAt;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _sessionId = 'mobile-${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _sendEvent('APP_SESSION_ENDED', durationMs: _durationMs());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSession();
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _sendEvent('APP_SESSION_ENDED', durationMs: _durationMs());
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  Future<void> _startSession() async {
    _startedAt ??= DateTime.now();
    await _sendEvent('APP_SESSION_STARTED', screenName: _currentRouteName());
    _heartbeatTimer ??= Timer.periodic(
      const Duration(seconds: 30),
      (_) => _sendEvent('APP_SESSION_HEARTBEAT', screenName: _currentRouteName()),
    );
  }

  String _currentRouteName() {
    final route = ModalRoute.of(context)?.settings.name;
    return (route == null || route.isEmpty) ? 'mobile:unknown' : route;
  }

  int _durationMs() {
    final started = _startedAt;
    if (started == null) return 0;
    return DateTime.now().difference(started).inMilliseconds.clamp(0, 86400000).toInt();
  }

  Future<void> _sendEvent(
    String eventType, {
    String? screenName,
    int? durationMs,
  }) async {
    if (!mounted) return;
    final storage = context.read<StorageService>();
    final apiService = context.read<ApiService>();
    final enabled = await storage.getAnalyticsConsentEnabled();
    if (!enabled || !mounted) return;
    final token = await storage.getAccessToken();
    if (token == null || token.isEmpty || !mounted) return;

    try {
      await apiService.post(
        AppConfig.instance.coreServiceUrl,
        '/analytics/events',
        body: {
          'eventType': eventType,
          'sessionId': _sessionId,
          'platform': 'ANDROID',
          'screenName': screenName ?? _currentRouteName(),
          'durationMs': durationMs,
          'occurredAt': DateTime.now().toUtc().toIso8601String(),
          'locale': WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag(),
          'timezone': DateTime.now().timeZoneName,
          'metadata': {'source': 'mobile_lifecycle'},
        },
      );
    } catch (_) {
      // Best-effort analytics: never block UX.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

