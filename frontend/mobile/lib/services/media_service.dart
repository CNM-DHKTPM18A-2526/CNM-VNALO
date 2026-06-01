import 'dart:io';
import 'package:flutter/foundation.dart';
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
  STICKER,
  EMOJI,
  GIF
}

class MediaService {
  final ApiService _apiService;

  MediaService(this._apiService);

  String get _base => AppConfig.instance.mediaServiceUrl;

  String getPublicUrl(String mediaId) {
    if (mediaId.isEmpty) return '';
    if (mediaId.startsWith('http')) return mediaId;

    if (mediaId.startsWith('/')) {
      final baseUri = Uri.parse(_base);
      return '${baseUri.scheme}://${baseUri.authority}$mediaId';
    }

    // We must append /media/public/ because _base is strictly /api/v1 due to normalization
    return '$_base/media/public/$mediaId';
  }

  Future<List<Map<String, dynamic>>> getMediaByCategory(MediaCategory category, {int page = 0, int size = 50}) async {
    try {
      final endpoint = '/media?category=${category.name}&page=$page&size=$size';
      debugPrint('[MediaService] getMediaByCategory: calling $endpoint');
      final response = await _apiService.get(_base, endpoint);
      debugPrint('[MediaService] getMediaByCategory(${category.name}): full response=${response.toString()}');
      debugPrint('[MediaService] getMediaByCategory(${category.name}): response keys=${response.keys.toList()}');
      
      // Try to find data in response
      Map<String, dynamic>? data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        data = response;
      }
      
      debugPrint('[MediaService] data type=${data.runtimeType}, keys=${data.keys.toList()}');
      
      // Backend usually returns paged items in `content`.
      if (data != null && data['content'] is List) {
        final items = List<Map<String, dynamic>>.from(data['content']);
        debugPrint('[MediaService] getMediaByCategory(${category.name}): found ${items.length} items in content');
        return items;
      }

      // Keep `items` as a fallback for older responses.
      if (data != null && data['items'] is List) {
        final items = List<Map<String, dynamic>>.from(data['items']);
        debugPrint('[MediaService] getMediaByCategory(${category.name}): found ${items.length} items in items');
        return items;
      }
      
      // Try data.data for nested response
      if (data != null && data['data'] is List) {
        final items = List<Map<String, dynamic>>.from(data['data']);
        debugPrint('[MediaService] getMediaByCategory(${category.name}): found ${items.length} items in data.data');
        return items;
      }
      
      // Try direct list in response (cast to dynamic to bypass type narrowing)
      if ((response as dynamic) is List) {
        final items = List<Map<String, dynamic>>.from(response as List);
        debugPrint('[MediaService] getMediaByCategory(${category.name}): found ${items.length} items in response');
        return items;
      }
      
      // Try response as direct list
      for (var key in response.keys) {
        final value = response[key];
        debugPrint('[MediaService] Key: $key = ${value.runtimeType}');
        if (value is List && value.isNotEmpty) {
          debugPrint('[MediaService] Found list in key: $key with ${value.length} items');
          return List<Map<String, dynamic>>.from(value);
        }
      }

      debugPrint('[MediaService] getMediaByCategory(${category.name}): no items found, returning empty list. response=$response');
      return [];
    } catch (e) {
      debugPrint('[MediaService] getMediaByCategory(${category.name}) error: $e');
      return [];
    }
  }
  
  /// Try alternative endpoint for GIFs if the standard one returns empty
  Future<List<Map<String, dynamic>>> getGifsAlternative({int size = 50}) async {
    debugPrint('[MediaService] getGifsAlternative: trying alternative GIF endpoint');
    try {
      // Try common alternative endpoints for GIFs
      final endpoints = [
        '/gifs?size=$size',
        '/media/gifs?size=$size',
        '/gifs/trending?limit=$size',
        '/stickers/gifs?size=$size',
        '/media?category=GIF&size=$size',
      ];
      
      for (final endpoint in endpoints) {
        try {
          debugPrint('[MediaService] getGifsAlternative: trying $endpoint');
          final response = await _apiService.get(_base, endpoint);
          debugPrint('[MediaService] getGifsAlternative: endpoint $endpoint response keys=${response.keys.toList()}');
          final data = response['data'] ?? response;
          
          List<Map<String, dynamic>> items = [];
          if (data is List) {
            items = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['items'] is List) {
            items = List<Map<String, dynamic>>.from(data['items']);
          } else if (data is Map && data['gifs'] is List) {
            items = List<Map<String, dynamic>>.from(data['gifs']);
          } else if (data is Map && data['data'] is List) {
            items = List<Map<String, dynamic>>.from(data['data']);
          } else if (data is Map && data['content'] is List) {
            items = List<Map<String, dynamic>>.from(data['content']);
          }
          
          if (items.isNotEmpty) {
            debugPrint('[MediaService] getGifsAlternative: found ${items.length} items at $endpoint');
            return items;
          }
        } catch (e) {
          debugPrint('[MediaService] getGifsAlternative: endpoint $endpoint failed: $e');
          continue;
        }
      }
      
      debugPrint('[MediaService] getGifsAlternative: no alternative endpoints returned items');
      return [];
    } catch (e) {
      debugPrint('[MediaService] getGifsAlternative error: $e');
      return [];
    }
  }

  Future<String> uploadFile(File file, MediaCategory category) async {
    final response = await _apiService.postMultipart(
      _base,
      '/media/upload',
      file: file,
      fields: {'category': category.name},
    );

    final data = response['data'] ?? response;
    final url = data['url']?.toString();
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return data['mediaId']?.toString() ?? data['id']?.toString() ?? '';
  }

  Future<List<Map<String, dynamic>>> getStickerPacks() async {
    try {
      final response = await _apiService.get(_base, '/media/stickers/packs');
      final data = response['data'] ?? response;
      if (data is Map && data['content'] is List) {
        return List<Map<String, dynamic>>.from(data['content']);
      }
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[MediaService] getStickerPacks error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getStickersInPack(String packId) async {
    try {
      final response = await _apiService.get(_base, '/media/stickers/packs/$packId');
      final data = response['data'] ?? response;
      if (data is Map && data['stickers'] is List) {
        return List<Map<String, dynamic>>.from(data['stickers']);
      }
    } catch (e) {
      debugPrint('[MediaService] getStickersInPack error: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMyPacks() async {
    try {
      final response = await _apiService.get(_base, '/media/stickers/my-packs');
      final data = response['data'] ?? response;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[MediaService] getMyPacks error: $e');
    }
    return [];
  }

  Future<void> installPack(String packId) async {
    try {
      await _apiService.post(_base, '/media/stickers/packs/$packId/download', body: {});
    } catch (e) {
      debugPrint('[MediaService] installPack error: $e');
    }
  }

  Future<void> recordStickerUsage(String stickerId) async {
    try {
      await _apiService.post(_base, '/media/stickers/$stickerId/use', body: {});
    } catch (e) {
      debugPrint('[MediaService] recordStickerUsage error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentStickers({int limit = 20}) async {
    try {
      final response = await _apiService.get(_base, '/media/stickers/recent?limit=$limit');
      final data = response['data'] ?? response;
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('[MediaService] getRecentStickers error: $e');
    }
    return [];
  }
}
