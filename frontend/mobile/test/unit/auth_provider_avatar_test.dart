import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/config/env.dart';
import 'package:vnalo_mobile/models/user_model.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/auth_service.dart';
import 'package:vnalo_mobile/services/storage_service.dart';

// ─────────────────────────────── Stubs ───────────────────────────────

class _StubStorage extends StorageService {
  final Map<String, String> _map = {};

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _map['accessToken'] = accessToken;
    _map['refreshToken'] = refreshToken;
  }

  @override
  Future<String?> getAccessToken() async => _map['accessToken'];

  @override
  Future<String?> getRefreshToken() async => _map['refreshToken'];

  @override
  Future<void> saveUserId(String id) async => _map['userId'] = id;

  @override
  Future<String?> getUserId() async => _map['userId'];

  @override
  Future<void> clearAll() async => _map.clear();
}

/// ApiService stub where [post], [get], [patch] and [postMultipart] delegate
/// to injectable callbacks.
class _StubApi extends ApiService {
  _StubApi() : super(_StubStorage());

  Map<String, dynamic> Function(String, String,
      {Map<String, dynamic>? body})? onPost;
  Map<String, dynamic> Function(String, String,
      {Map<String, String>? queryParams})? onGet;
  Map<String, dynamic> Function(String, String,
      {Map<String, dynamic>? body})? onPatch;
  Map<String, dynamic> Function(
      String baseUrl, String endpoint, {required File file, String fileField, Map<String, String>? fields, bool allowRefresh})? onMultipart;

  @override
  Future<Map<String, dynamic>> post(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return onPost?.call(baseUrl, endpoint, body: body) ?? {};
  }

  @override
  Future<Map<String, dynamic>> get(
    String baseUrl,
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    return onGet?.call(baseUrl, endpoint, queryParams: queryParams) ?? {};
  }

  @override
  Future<Map<String, dynamic>> patch(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    return onPatch?.call(baseUrl, endpoint, body: body) ?? {};
  }

  @override
  Future<Map<String, dynamic>> postMultipart(
    String baseUrl,
    String endpoint, {
    required File file,
    String fileField = 'file',
    Map<String, String>? fields,
    bool allowRefresh = true,
  }) async {
    return onMultipart?.call(baseUrl, endpoint, file: file, fileField: fileField, fields: fields, allowRefresh: allowRefresh) ??
        {};
  }
}

void main() {
  setUpAll(() {
    AppConfig.initialize(
      Environment.dev,
      coreServiceUrl: 'http://10.0.2.2:8081/api/v1',
      mediaServiceUrl: 'http://10.0.2.2:8083/api/v1',
    );
  });

  group('User.copyWith', () {
    test('copies avatarUrl while preserving other fields', () {
      final original = User(
        id: 'u1',
        phone: '+84123456789',
        displayName: 'Test User',
        avatarUrl: 'https://old.png',
        bio: 'hello',
        isVerified: true,
      );

      final updated = original.copyWith(avatarUrl: 'https://new.png');

      expect(updated.id, equals('u1'));
      expect(updated.phone, equals('+84123456789'));
      expect(updated.displayName, equals('Test User'));
      expect(updated.avatarUrl, equals('https://new.png'));
      expect(updated.bio, equals('hello'));
      expect(updated.isVerified, isTrue);
    });

    test('copyWith with no arguments returns identical values', () {
      final original = User(
        id: 'u2',
        displayName: 'Same',
        avatarUrl: 'https://avatar.png',
      );

      final copy = original.copyWith();

      expect(copy.id, equals(original.id));
      expect(copy.displayName, equals(original.displayName));
      expect(copy.avatarUrl, equals(original.avatarUrl));
    });
  });

  group('AuthService.parseUploadedMediaUrl', () {
    test('extracts url from wrapped data', () {
      final url = AuthService.parseUploadedMediaUrl({
        'data': {'url': 'https://cdn.example.com/avatar.jpg'},
      });
      expect(url, equals('https://cdn.example.com/avatar.jpg'));
    });

    test('returns null when data wrapper is missing', () {
      final url = AuthService.parseUploadedMediaUrl({'url': 'x'});
      expect(url, isNull);
    });

    test('falls back to fileUrl key', () {
      final url = AuthService.parseUploadedMediaUrl({
        'data': {'fileUrl': 'https://cdn.example.com/f.png'},
      });
      expect(url, equals('https://cdn.example.com/f.png'));
    });
  });
}
