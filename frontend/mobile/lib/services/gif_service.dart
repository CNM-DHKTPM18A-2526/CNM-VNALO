import 'package:vnalo_mobile/services/media_service.dart';

class GifService {
  final MediaService _mediaService;

  GifService(this._mediaService);

  // Chuyển đổi dữ liệu từ Media Service sang định dạng mà UI Chat đang mong đợi
  List<Map<String, dynamic>> _normalizeResults(List<Map<String, dynamic>> mediaList) {
    return mediaList.map((media) {
      final url = media['url'] ?? '';
      return {
        'id': media['id'],
        'media_formats': {
          'tinygif': {'url': url},
          'gif': {'url': url}
        }
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getTrendingGifs({int limit = 50}) async {
    try {
      final results = await _mediaService.getMediaByCategory(MediaCategory.GIF, size: limit);
      return _normalizeResults(results);
    } catch (e) {
      print('Error fetching S3 GIFs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchGifs(String query, {int limit = 50}) async {
    // Hiện tại backend chưa hỗ trợ search GIF theo text cụ thể trong metadata, 
    // chúng ta sẽ trả về trending (toàn bộ GIF trên S3) hoặc lọc theo tên file nếu cần.
    return getTrendingGifs(limit: limit);
  }
}
