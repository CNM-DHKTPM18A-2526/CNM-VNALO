import 'dart:io';
import 'package:vnalo_mobile/config/app_config.dart';
import 'package:vnalo_mobile/services/api_service.dart';

enum MediaCategory {
  AVATAR,
  COVER,
  CHAT_IMAGE,
  CHAT_VIDEO,
  CHAT_FILE,
  CHAT_VOICE,
  STORY,
  TIMELINE,
  STICKER
}

class MediaService {
  final ApiService _apiService;

  MediaService(this._apiService);

  String get _base => AppConfig.instance.mediaServiceUrl;

  String getPublicUrl(String mediaId) {
    if (mediaId.isEmpty) return '';
    if (mediaId.startsWith('http')) return mediaId;
    return '$_base/media/public/$mediaId';
  }

  Future<String> uploadFile(File file, MediaCategory category) async {
    final response = await _apiService.postMultipart(
      _base,
      '/media/upload',
      file: file,
      fields: {'category': category.name},
    );

    final data = response['data'] ?? response;
    return data['mediaId']?.toString() ?? data['id']?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> getStickerPacks() async {
    final response = await _apiService.get(_base, '/stickers/packs');
    final data = response['data'] ?? response;
    if (data is Map && data['content'] is List) {
       return List<Map<String, dynamic>>.from(data['content']);
    }
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getStickersInPack(String packId) async {
    final response = await _apiService.get(_base, '/stickers/packs/$packId');
    final data = response['data'] ?? response;
    if (data is Map && data['stickers'] is List) {
      return List<Map<String, dynamic>>.from(data['stickers']);
    }
    return [];
  }
}
