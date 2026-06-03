import 'package:flutter/foundation.dart';
import 'package:vnalo_mobile/services/media_service.dart';

class GifService {
  final MediaService _mediaService;

  GifService(this._mediaService);

  // Chuyển đổi dữ liệu từ Media Service sang định dạng mà UI Chat đang mong đợi
  List<Map<String, dynamic>> _normalizeResults(List<Map<String, dynamic>> mediaList) {
    debugPrint('[GifService] _normalizeResults: received ${mediaList.length} items');
    if (mediaList.isEmpty) {
      debugPrint('[GifService] _normalizeResults: received empty list from API');
    }
    
    return mediaList.map((media) {
      debugPrint('[GifService] _normalizeResults: processing media item keys=${media.keys.toList()}');
      
      // Try multiple field names that backend might use
      final id = media['id']?.toString() ?? 
                 media['mediaId']?.toString() ?? 
                 media['fileId']?.toString() ?? '';
      
      // Try multiple URL field names - these are common patterns
      String? url;
      
      // Direct URL fields
      if (media['url'] != null) {
        url = media['url']?.toString();
      } else if (media['mediaUrl'] != null) {
        url = media['mediaUrl']?.toString();
      } else if (media['fileUrl'] != null) {
        url = media['fileUrl']?.toString();
      } else if (media['publicUrl'] != null) {
        url = media['publicUrl']?.toString();
      } else if (media['cdnUrl'] != null) {
        url = media['cdnUrl']?.toString();
      } else if (media['downloadUrl'] != null) {
        url = media['downloadUrl']?.toString();
      } else if (media['s3Url'] != null) {
        url = media['s3Url']?.toString();
      } else if (media['path'] != null) {
        // If only path is provided, prepend media base
        url = media['path']?.toString();
      }
      
      if (id.isEmpty && (url == null || url.isEmpty)) {
        debugPrint('[GifService] WARNING: media item has no id or url: $media');
      }
      
      debugPrint('[GifService] _normalizeResults: id=$id, url=$url');
      
      return {
        'id': id,
        'url': url ?? '',
        'media_formats': {
          'tinygif': {'url': url ?? ''},
          'gif': {'url': url ?? ''}
        }
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTrendingGifs({int limit = 50}) async {
    debugPrint('[GifService] getTrendingGifs: fetching with limit=$limit');
    
    // First try the standard media category endpoint
    try {
      final results = await _mediaService.getMediaByCategory(MediaCategory.GIF, size: limit);
      debugPrint('[GifService] getTrendingGifs: received ${results.length} items from standard endpoint');
      
      if (results.isNotEmpty) {
        debugPrint('[GifService] getTrendingGifs: first item keys=${results.first.keys.toList()}');
        debugPrint('[GifService] getTrendingGifs: first item=${results.first}');
        return _normalizeResults(results);
      }
      
      // If standard endpoint returns empty, try alternative endpoints
      debugPrint('[GifService] getTrendingGifs: standard endpoint returned empty, trying alternative');
      final altResults = await _mediaService.getGifsAlternative(size: limit);
      
      if (altResults.isNotEmpty) {
        debugPrint('[GifService] getTrendingGifs: alternative endpoint returned ${altResults.length} items');
        return _normalizeResults(altResults);
      }
      
      debugPrint('[GifService] getTrendingGifs: all endpoints returned empty');
      return [];
    } catch (e) {
      debugPrint('[GifService] Error fetching GIFs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchGifs(String query, {int limit = 50}) async {
    debugPrint('[GifService] searchGifs: query=$query');
    if (query.isEmpty) {
      return getTrendingGifs(limit: limit);
    }
    // Search in trending GIFs by name (client-side filtering)
    final trending = await getTrendingGifs(limit: limit);
    return trending.where((gif) {
      final name = gif['id']?.toString().toLowerCase() ?? '';
      return name.contains(query.toLowerCase());
    }).toList();
  }
}
