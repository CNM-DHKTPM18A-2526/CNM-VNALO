import 'package:vnalo_mobile/services/api_service.dart';

/// Global Error Mapper to translate server technical error codes 
/// into user-friendly Vietnamese messages.
class ApiErrorMapper {
  static String map(dynamic error) {
    if (error is ApiException) {
      return _mapApiException(error);
    }
    if (error is StateError) {
      return error.message;
    }
    return 'Đã xảy ra lỗi không xác định. Vui lòng thử lại sau.';
  }

  static String _mapApiException(ApiException e) {
    if (e.code == null || e.code!.isEmpty) {
      // Fallback for unhandled server messages or basic network errors
      return _mapRawMessage(e.message, e.statusCode);
    }

    switch (e.code) {
      // Auth Errors
      case 'AUTH_001': return 'Tài khoản không tồn tại';
      case 'AUTH_002': return 'Sai mật khẩu';
      case 'AUTH_006': 
      case 'AUTH_007': return 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại';
      case 'AUTH_008': return 'Số điện thoại này đã được đăng ký';
      case 'AUTH_018': return 'Email này đã được đăng ký';
      case 'AUTH_009': return 'Mã OTP đã hết hạn, vui lòng gửi lại';
      case 'AUTH_010': return 'Mã OTP không đúng';
      case 'AUTH_011': return 'Thao tác quá thường xuyên. Vui lòng thử lại sau';
      case 'AUTH_016': return 'Mật khẩu mới chưa đạt yêu cầu (cần ít nhất 8 ký tự, 1 hoa, 1 thường, 1 số)';
      case 'AUTH_019': return 'Email hoặc Số điện thoại chưa được đăng ký trong hệ thống';
      case 'AUTH_020': return 'Hệ thống chưa cấu hình gửi OTP';
      case 'AUTH_OTP_RATE_LIMITED': return 'Vượt quá số lần nhận OTP trong ngày. Cảm phiền bạn quay lại sau.';
      case 'AUTH_OTP_COOLDOWN': return 'Bạn vừa yêu cầu mã OTP nội trong vòng 60 giây. Hãy đợi một xíu nữa nhé.';

      // Social / Friend Errors
      case 'SOCIAL_001': return 'Không thể kết bạn với chính mình';
      case 'SOCIAL_002': return 'Đã gửi lời mời trước đó rồi';
      case 'SOCIAL_003': return 'Hai bạn đã là bạn bè';
      case 'SOCIAL_004': return 'Không tìm thấy lời mời kết bạn này';
      case 'SOCIAL_005': return 'Người dùng này đang chặn bạn (hoặc bạn đang chặn họ)';
      case 'SOCIAL_006': return 'Người dùng này đã cấu hình quyền riêng tư không nhận lời mời kết bạn theo cách này';
      case 'SOCIAL_NOT_FRIENDS': return 'Hai người chưa phải là bạn bè';

      // User Profile Errors
      case 'USER_001': 
      case 'USER_NOT_FOUND': return 'Người dùng không tồn tại hoặc đã bị khóa';

      // Validation & File Errors
      case 'FILE_001': return 'Dung lượng file quá lớn (tối đa 25MB)';
      case 'FILE_002': return 'Định dạng file không được hỗ trợ';
      case 'VAL_001': return 'Dữ liệu đầu vào không hợp lệ';

      // Base cases
      default:
        return _mapRawMessage(e.message, e.statusCode);
    }
  }

  static String _mapRawMessage(String originalMsg, int statusCode) {
    final msgLowerCase = originalMsg.toLowerCase();
    
    if (msgLowerCase.contains('no internet') || msgLowerCase.contains('socketexception')) {
      return 'Không có kết nối mạng. Bạn hãy kiểm tra lại Wifi/4G nhé.';
    }
    if (msgLowerCase.contains('timeout')) {
      return 'Kết nối mạng yếu. Bạn hãy thử lại xem sao.';
    }
    if (originalMsg.isNotEmpty && originalMsg != 'Unknown error') {
      // If none of the translations apply, pass the raw text. Wait, we should try not to pass english to users.
      // But we can format it nicely.
      return 'Lỗi: $originalMsg';
    }
    return 'Yêu cầu thất bại (Mã lỗi: $statusCode)';
  }
}
