import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vnalo_mobile/core/localization/language_provider.dart';

class CommonTexts {
  final AppLanguage language;

  const CommonTexts(this.language);

  static CommonTexts of(BuildContext context, {bool listen = true}) {
    final language =
        Provider.of<LanguageProvider>(context, listen: listen).language;
    return CommonTexts(language);
  }

  bool get _isVi => language == AppLanguage.vi;

  // Generic Actions
  String get confirm => _isVi ? 'Xác nhận' : 'Confirm';
  String get cancel => _isVi ? 'Hủy' : 'Cancel';
  String get close => _isVi ? 'Đóng' : 'Close';
  String get save => _isVi ? 'Lưu' : 'Save';
  String get edit => _isVi ? 'Chỉnh sửa' : 'Edit';
  String get delete => _isVi ? 'Xóa' : 'Delete';
  String get search => _isVi ? 'Tìm kiếm' : 'Search';
  String get searchHint => _isVi ? 'Tìm kiếm' : 'Search';
  String get loading => _isVi ? 'Đang tải...' : 'Loading...';
  String get retry => _isVi ? 'Thử lại' : 'Retry';
  String get skip => _isVi ? 'Bỏ qua' : 'Skip';
  String get next => _isVi ? 'Tiếp theo' : 'Next';
  String get back => _isVi ? 'Quay lại' : 'Back';
  String get update => _isVi ? 'Cập nhật' : 'Update';
  String get sort => _isVi ? 'Sắp xếp' : 'Sort';
  String get recallAction => _isVi ? 'Thu hồi' : 'Recall';
  String get deleteForMeAction => _isVi ? 'Xóa ở phía tôi' : 'Delete for me';
  String get confirmRecallMessage => _isVi ? 'Tin nhắn này sẽ được thu hồi với tất cả mọi người.' : 'This message will be recalled for everyone.';
  String get confirmDeleteForMe => _isVi ? 'Tin nhắn này sẽ bị xóa khỏi lịch sử trò chuyện của bạn.' : 'This message will be deleted from your chat history.';
  String get filterAll => _isVi ? 'Tất cả' : 'All';
  String get recentlyActive => _isVi ? 'Mới truy cập' : 'Recently active';
  String get today => _isVi ? 'Hôm nay' : 'Today';
  String get yesterday => _isVi ? 'Hôm qua' : 'Yesterday';

  // Common UI Elements
  String get noData => _isVi ? 'Không có dữ liệu' : 'No data available';
  String get errorOccurred => _isVi ? 'Đã xảy ra lỗi' : 'An error occurred';
  String get success => _isVi ? 'Thành công' : 'Success';

  // Navigation / Tabs
  String get friends => _isVi ? 'Bạn bè' : 'Friends';
  String get groups => _isVi ? 'Nhóm' : 'Groups';
  String get discover => _isVi ? 'Khám phá' : 'Discover';
  String get timeline => _isVi ? 'Nhật ký' : 'Timeline';
  String get profile => _isVi ? 'Cá nhân' : 'Profile';
  String get messages => _isVi ? 'Tin nhắn' : 'Messages';
  String get contacts => _isVi ? 'Danh bạ' : 'Contacts';
  String get friendRequests => _isVi ? 'Lời mời kết bạn' : 'Friend requests';
  String get birthday => _isVi ? 'Sinh nhật' : 'Birthday';
  String get createNewGroup => _isVi ? 'Tạo nhóm mới' : 'Create new group';
  String joinedGroups(int count) =>
      _isVi ? 'Nhóm đang tham gia ($count)' : 'Joined groups ($count)';
  String get noGroupsJoined =>
      _isVi ? 'Bạn chưa tham gia nhóm nào' : 'No groups joined yet';
  String get officialAccount => 'OA';
  String get findMoreOA =>
      _isVi ? 'Tìm thêm Official Account' : 'Find more Official Accounts';
  String followedOA(int count) =>
      _isVi
          ? 'Official Account đã quan tâm ($count)'
          : 'Followed Official Accounts ($count)';
  String get noOAFollowed =>
      _isVi
          ? 'Bạn chưa quan tâm Official Account nào'
          : 'No Official Accounts followed yet';
  String get cannotOpenChat =>
      _isVi ? 'Không thể mở cuộc trò chuyện' : 'Cannot open chat';
  String get diaryTab => _isVi ? 'Nhật ký' : 'Diary';
  String get newBadge => _isVi ? 'Mới' : 'New';
  String get searchHintTimeline => _isVi ? 'Tìm kiếm' : 'Search';
  String get postInputPlaceholder =>
      _isVi ? 'Hôm nay bạn thế nào?' : 'How are you today?';
  String get photoAction => _isVi ? 'Ảnh' : 'Photo';
  String get videoAction => _isVi ? 'Video' : 'Video';
  String get albumAction => _isVi ? 'Album' : 'Album';
  String get backgroundTextAction => _isVi ? 'Nền chữ' : 'Text BG';
  String get createNewStory => _isVi ? 'Tạo mới' : 'Create new';
  String get noPostsYet =>
      _isVi ? 'Chưa có kỷ niệm nào được chia sẻ.' : 'No memories shared yet.';
  String get anonymousUser => _isVi ? 'Người dùng' : 'User';
  String get addFriendAction => _isVi ? 'Thêm bạn' : 'Add friend';
  String get createGroupAction => _isVi ? 'Tạo nhóm' : 'Create group';
  String get joinGroupAction => _isVi ? 'Tham gia nhóm' : 'Join group';
  String get groupFlowPlaceholder =>
      _isVi
          ? 'Luồng tạo nhóm sẽ được nối ở bước message/group tiếp theo.'
          : 'Group creation flow will be integrated in the next message/group step.';
  String get vnaloCalendar => _isVi ? 'Lịch Vnalo' : 'Vnalo Calendar';
  String get calendarFlowPlaceholder =>
      _isVi
          ? 'Lịch Vnalo sẽ được tích hợp ở bước lịch/message tiếp theo.'
          : 'Vnalo Calendar will be integrated in the next calendar/message step.';
  String get createGroupCallAction =>
      _isVi ? 'Tạo cuộc gọi nhóm' : 'Create group call';
  String get callFlowPlaceholder =>
      _isVi
          ? 'Tạo cuộc gọi nhóm sẽ được triển khai ở module call.'
          : 'Group call creation will be implemented in the call module.';
  String get callAgainAction => _isVi ? 'GỌI LẠI' : 'CALL AGAIN';
  String get loggedInDevices =>
      _isVi ? 'Thiết bị đăng nhập' : 'Logged in devices';
  String get messagesTab => _isVi ? 'Tin nhắn' : 'Messages';
  String get contactsTab => _isVi ? 'Danh bạ' : 'Contacts';
  String get discoverTab => _isVi ? 'Khám phá' : 'Discover';
  String get wallTab => _isVi ? 'Nhật ký' : 'Timeline';
  String get profileTab => _isVi ? 'Cá nhân' : 'Me';
  String get shoppingService =>
      _isVi ? 'Mua sắm trực tuyến' : 'Online shopping';
  String get gamesService => _isVi ? 'Trò chơi' : 'Games';
  String get gamesSubtitle => _isVi ? 'Chơi cùng bạn bè' : 'Play with friends';
  String get newsService => _isVi ? 'Tin tức' : 'News';
  String get newsSubtitle => _isVi ? 'Cập nhật mới nhất' : 'Latest updates';
  String get qrScannerTitle => _isVi ? 'Quét QR' : 'QR Scanner';
  String get qrScannerSubtitle =>
      _isVi
          ? 'Đăng nhập web, thanh toán, kết bạn'
          : 'Web login, payment, add friends';
  String get updateAvatarSuccess =>
      _isVi
          ? 'Cập nhật ảnh đại diện thành công'
          : 'Avatar updated successfully';
  String get updateAvatarFail =>
      _isVi ? 'Cập nhật ảnh đại diện thất bại' : 'Failed to update avatar';
  String get vnCloudTitle => 'vnCloud';
  String get vnCloudSubtitle =>
      _isVi ? 'Không gian lưu trữ dữ liệu trên đám mây' : 'Cloud storage space';
  String get vnStyleTitle =>
      _isVi ? 'vnStyle - Nổi bật trên Vnalo' : 'vnStyle - Stand out on Vnalo';
  String get vnStyleSubtitle =>
      _isVi
          ? 'Hình nền và nhạc cho cuộc gọi Vnalo'
          : 'Wallpapers and ringtones for Vnalo calls';
  String get myDocumentsSubtitle =>
      _isVi ? 'Lưu trữ các tin nhắn quan trọng' : 'Store important messages';
  String get deviceDataTitle => _isVi ? 'Dữ liệu trên máy' : 'Data on device';
  String get deviceDataSubtitle =>
      _isVi ? 'Quản lý dữ liệu VNALO của bạn' : 'Manage your VNALO data';
  String get qrWalletTitle => _isVi ? 'Ví QR' : 'QR Wallet';
  String get qrWalletSubtitle =>
      _isVi
          ? 'Lưu trữ và xuất trình các mã QR quan trọng'
          : 'Store and present important QR codes';
  String get vnaloPayTitle =>
      _isVi ? 'Vnalo Pay (Sắp ra mắt)' : 'Vnalo Pay (Coming soon)';
  String get vnaloPaySubtitle =>
      _isVi ? 'Thanh toán tiện lợi, bảo mật' : 'Convenient, secure payments';
  String get accountAndSecurity =>
      _isVi ? 'Tài khoản và bảo mật' : 'Account and security';
  String get privacyRights => _isVi ? 'Quyền riêng tư' : 'Privacy';

  // Additional Common Strings
  String get comingSoon => _isVi ? 'Sắp ra mắt' : 'Coming soon';
  String get options => _isVi ? 'Tùy chọn' : 'Options';
  String get featureUnderDevelopment =>
      _isVi ? 'Tính năng đang được phát triển' : 'Feature under development';
  String get unknownUser => _isVi ? 'Người dùng ẩn danh' : 'Unknown user';

  // Chat List / Actions
  String get pinAction => _isVi ? 'Ghim' : 'Pin';
  String get muteAction => _isVi ? 'Tắt' : 'Mute';
  String sayHelloTo(String name) =>
      _isVi ? 'Gửi lời chào $name' : 'Say hello to $name';

  // Friend Requests
  String get receivedTab => _isVi ? 'Đã nhận' : 'Received';
  String get sentTab => _isVi ? 'Đã gửi' : 'Sent';
  String get noFriendRequests =>
      _isVi ? 'Không có lời mời kết bạn' : 'No friend requests';
  String get noSentRequests =>
      _isVi ? 'Chưa gửi lời mời nào' : 'No sent requests';
  String get rejectAction => _isVi ? 'TỪ CHỐI' : 'REJECT';
  String get acceptAction => _isVi ? 'ĐỒNG Ý' : 'ACCEPT';
  String get cancelAction => _isVi ? 'Thu hồi' : 'Cancel';
  String get olderHeader => _isVi ? 'Cũ hơn' : 'Older';
  String get waitingResponse =>
      _isVi ? 'Đang chờ phản hồi' : 'Waiting for response';
  String get friendRequestSubtitle =>
      _isVi ? 'Muốn kết bạn' : 'Wants to be friends';
  String get requestRejected =>
      _isVi ? 'Đã từ chối lời mời kết bạn.' : 'Friend request rejected.';
  String get requestCancelled =>
      _isVi ? 'Đã thu hồi lời mời.' : 'Request cancelled.';

  // Chat Detail
  String get clickForInfo => _isVi ? 'Bấm để xem thông tin' : 'Tap for info';
  String membersCountAtChat(int count) =>
      _isVi ? '$count thành viên' : '$count members';
  String get startConversationNote =>
      _isVi
          ? 'Bắt đầu chia sẻ những câu chuyện thú vị\ncùng nhau'
          : 'Start sharing interesting stories\ntogether';
  String get helloAction => _isVi ? 'Xin chào!' : 'Hello!';
  String get niceToMeetAction => _isVi ? 'Rất vui!' : 'Nice to meet!';
  String get hiAction => _isVi ? 'Chào bạn!' : 'Hi there!';

  // Wallpaper
  String get doneAction => _isVi ? 'XONG' : 'DONE';
  String get changeWallpaperAction =>
      _isVi ? 'Đổi hình nền' : 'Change wallpaper';
  String get applyToBothSides =>
      _isVi ? 'Đổi hình nền cho cả hai bên' : 'Change wallpaper for both';

  // Add Friend
  String get addFriendHeader => _isVi ? 'Thêm bạn' : 'Add Friend';
  String get scanMyQrToAdd =>
      _isVi ? 'Quét mã để thêm bạn Vnalo với tôi' : 'Scan to add me on Vnalo';
  String get peopleNearby =>
      _isVi ? 'Bạn bè có thể quen' : 'People you may know';
  String get reloadQr => _isVi ? 'Tải lại mã QR' : 'Reload QR Code';
  String get viewSentRequestsNote =>
      _isVi
          ? 'Xem lời mời kết bạn đã gửi tại trang Danh bạ Vnalo'
          : 'View sent requests in Contacts page';
  String get cannotLoadQr =>
      _isVi ? 'Không tải được mã QR của bạn.' : 'Cannot load your QR code.';
  String get userNotFound =>
      _isVi
          ? 'Không tìm thấy người dùng với số điện thoại này.'
          : 'User not found with this phone number.';
  String get userSearchError =>
      _isVi
          ? 'Không tìm thấy người dùng hoặc bị giới hạn quyền riêng tư.'
          : 'User not found or privacy restricted.';
  String get phoneNumberHint =>
      _isVi ? 'Nhập số điện thoại' : 'Enter phone number';
  String get scanQR => _isVi ? 'Quét mã QR' : 'Scan QR Code';

  // Send Request
  String get addFriendTitle => _isVi ? 'Kết bạn' : 'Add Friend';
  String helloIam(String name) =>
      _isVi
          ? 'Xin chào, mình là $name. Kết bạn với mình nhé!'
          : 'Hello, I am $name. Let\'s be friends!';
  String requestSentTo(String name) =>
      _isVi ? 'Đã gửi lời mời đến $name' : 'Request sent to $name';
  String requestCancelledTo(String name) =>
      _isVi ? 'Đã hủy lời mời đến $name' : 'Request cancelled for $name';
  String get cannotCancelRequest =>
      _isVi ? 'Không thể hủy lời mời' : 'Cannot cancel request';
  String get requestAlreadySent =>
      _isVi
          ? 'Bạn đã gửi lời mời kết bạn cho người này rồi.'
          : 'You have already sent a request to this person.';
  String get alreadyFriends =>
      _isVi ? 'Hai bạn đã là bạn bè rồi.' : 'You are already friends.';
  String get cannotAddSelf =>
      _isVi
          ? 'Không thể tự kết bạn với chính mình.'
          : 'Cannot add yourself as a friend.';
  String get userBlocked =>
      _isVi ? 'Bạn đã chặn người dùng này.' : 'You have blocked this person.';
  String get userBlockedYou =>
      _isVi ? 'Người dùng này đã chặn bạn.' : 'This person has blocked you.';
  String get messageLabel => _isVi ? 'Lời nhắn' : 'Message';
  String get enterMessageHint =>
      _isVi ? 'Nhập lời nhắn...' : 'Enter message...';
  String get messageHint => _isVi ? 'Nhập tin nhắn...' : 'Type a message...';
  String get sendAction => _isVi ? 'GỬI' : 'SEND';
  String get cancelRequestAction => _isVi ? 'Hủy lời mời' : 'Cancel Request';
  String get sendRequestAction => _isVi ? 'Gửi lời mời' : 'Send Request';

  // QR Scanner
  String get qrNotSupported =>
      _isVi
          ? 'Mã QR chưa được hỗ trợ trong luồng này.'
          : 'QR code not supported in this flow.';
  String get processedFriendQr =>
      _isVi ? 'Đã xử lý mã QR kết bạn.' : 'Friend QR code processed.';
  String get cannotProcessFriendQr =>
      _isVi ? 'Không thể xử lý mã QR kết bạn' : 'Cannot process friend QR code';
  String groupJoinStatus(String status) =>
      _isVi ? 'Nhóm: $status' : 'Group: $status';
  String get cannotJoinGroup =>
      _isVi ? 'Không thể tham gia nhóm' : 'Cannot join group';
  String get myQrCode => _isVi ? 'Mã QR của tôi' : 'My QR Code';
  String get scanAnyQr => _isVi ? 'Quét mọi mã QR' : 'Scan any QR code';
  String get availablePhotos => _isVi ? 'Ảnh có sẵn' : 'Available photos';
  String get transferQr => _isVi ? 'QR chuyển khoản' : 'Transfer QR';
  String get recent => _isVi ? 'Gần đây' : 'Recent';

  // QR Login Approval
  String get qrLoginHeader => _isVi ? 'Quét QR đăng nhập web' : 'Web Login QR';
  String get qrExpired =>
      _isVi
          ? 'Mã QR đã hết hạn. Vui lòng quét mã mới.'
          : 'QR code expired. Please scan a new one.';
  String get cannotReadQrSession =>
      _isVi
          ? 'Không thể đọc phiên đăng nhập QR'
          : 'Cannot read QR login session';
  String get invalidLoginQr =>
      _isVi
          ? 'Mã QR không hợp lệ cho đăng nhập web.'
          : 'Invalid QR code for web login.';
  String get loginConfirmationFailed =>
      _isVi ? 'Xác nhận đăng nhập thất bại' : 'Login confirmation failed';
  String get loginConfirmedSuccess =>
      _isVi
          ? 'Đã xác nhận đăng nhập web thành công.'
          : 'Web login confirmed successfully.';
  String get confirmLoginOnDevice =>
      _isVi ? 'Xác nhận đăng nhập trên thiết bị' : 'Confirm login on device';
  String get deviceLabel => _isVi ? 'Thiết bị' : 'Device';
  String get locationLabel => _isVi ? 'Địa điểm' : 'Location';
  String get platformLabel => _isVi ? 'Nền tảng' : 'Platform';
  String get unknownValue => _isVi ? 'Không rõ' : 'Unknown';
  String waitToApprove(int seconds) =>
      _isVi
          ? 'Vui lòng chờ $seconds giây trước khi đồng ý.'
          : 'Please wait $seconds seconds before approving.';
  String get canApproveNow =>
      _isVi
          ? 'Bạn có thể nhấn Đồng ý để đăng nhập web.'
          : 'You can now tap Agree to log in.';
  String get scanAgainAction => _isVi ? 'Quét lại' : 'Scan Again';
  String get agreeAction => _isVi ? 'Đồng ý' : 'Agree';

  // Group Options
  String get groupOptionsHeader => _isVi ? 'Tùy chọn nhóm' : 'Group Options';
  String get detailedGroupSettings =>
      _isVi ? 'Cài đặt nhóm chi tiết' : 'Detailed Group Settings';
  String get addMemberAction => _isVi ? 'Thêm thành viên' : 'Add Member';
  String get leaveGroupAction => _isVi ? 'Rời nhóm' : 'Leave Group';

  // Group Settings Detail
  String get groupSettingsHeader => _isVi ? 'Cài đặt nhóm' : 'Group Settings';
  String get changeGroupNameAction =>
      _isVi ? 'Đổi tên nhóm' : 'Change Group Name';
  String get changeGroupPhotoAction =>
      _isVi ? 'Đổi ảnh nhóm' : 'Change Group Photo';
  String get joinModeLabel => _isVi ? 'Chế độ tham gia' : 'Join Mode';
  String get memberLimitLabel => _isVi ? 'Giới hạn thành viên' : 'Member Limit';

  // My Documents
  List<String> get docTabs =>
      _isVi
          ? ['Tất cả', 'Văn bản', 'Ảnh', 'File', 'Link']
          : ['All', 'Text', 'Image', 'File', 'Link'];
  String formatDocDate(DateTime dt) =>
      _isVi
          ? '${dt.day} tháng ${dt.month}, ${dt.year}'
          : '${dt.month} ${dt.day}, ${dt.year}';
  String get myDocumentsHeader => _isVi ? 'My Documents' : 'My Documents';
  String get noContentYet => _isVi ? 'Chưa có nội dung nào' : 'No content yet';
  String get saveContentNote =>
      _isVi
          ? 'Hãy gửi tin nhắn, ảnh hoặc file để lưu trữ'
          : 'Send messages, photos or files to store';
  String get msgDeliveredStatus => _isVi ? 'Đã nhận' : 'Delivered';
  String get msgCopied => _isVi ? 'Đã sao chép tin nhắn' : 'Message copied';

  // Direct Chat Options
  String get chatOptionsHeader =>
      _isVi ? 'Tùy chọn trò chuyện' : 'Chat Options';
  String get viewProfileAction => _isVi ? 'Xem trang cá nhân' : 'View Profile';
  String get muteNotificationsAction =>
      _isVi ? 'Tắt thông báo' : 'Mute Notifications';
  String get blockUserAction => _isVi ? 'Chặn người dùng' : 'Block User';
  String get deleteChatAction => _isVi ? 'Xóa cuộc trò chuyện' : 'Delete Chat';

  // Sticker Picker & GIFs
  String get recentEmojiLabel => _isVi ? 'GẦN ĐÂY' : 'RECENT';
  String get commonEmojiLabel => _isVi ? 'BIỂU CẢM' : 'EMOJI';
  String get stickerStoreTitle => _isVi ? 'Kho Sticker' : 'Sticker Store';
  String get downloadStickerAction => _isVi ? 'Tải về' : 'Download';
  String get searchGifsHint =>
      _isVi ? 'Tìm kiếm GIF trên VNALO' : 'Search GIFs on VNALO';
  String get noRecentStickersLabel =>
      _isVi ? 'Chưa có sticker gần đây' : 'No recent stickers';
  String get stickerPackEmptyNote =>
      _isVi ? 'Bộ sticker này đang trống' : 'Sticker pack is empty';

  // Attachments & Media
  String get imageMediaLabel => _isVi ? 'Hình ảnh/Phương tiện' : 'Image/Media';
  String get imageLabel => _isVi ? 'Hình ảnh' : 'Image';
  String get documentLabel => _isVi ? 'Tài liệu' : 'Document';
  String get fileLimitNote => _isVi ? 'Dưới 5MB' : 'Under 5MB';

  // Appearance & Language
  String get appearanceAndLanguageHeader =>
      _isVi ? 'Giao diện và ngôn ngữ' : 'Appearance and Language';
  String get appearanceHeader => _isVi ? 'Giao diện' : 'Appearance';
  String get lightThemeLabel => _isVi ? 'Sáng' : 'Light';
  String get darkThemeLabel => _isVi ? 'Tối' : 'Dark';
  String get systemThemeLabel => _isVi ? 'Hệ thống' : 'System';
  String get changeFontAction => _isVi ? 'Đổi phông chữ' : 'Change Font';
  String get vnaloFontLabel => _isVi ? 'Phông chữ Vnalo' : 'Vnalo Font';
  String get changeFontSizeAction => _isVi ? 'Đổi cỡ chữ' : 'Change Font Size';
  String get languageHeader => _isVi ? 'Ngôn ngữ' : 'Language';
  String get changeLanguageAction => _isVi ? 'Đổi ngôn ngữ' : 'Change Language';

  // Friend Options
  String get friendOptionsHeader =>
      _isVi ? 'Tùy chọn bạn bè' : 'Friend Options';
  String get nicknameUpdatedLocal =>
      _isVi ? 'Đã cập nhật tên gợi nhớ (Local)' : 'Nickname updated (Local)';
  String get recentlyFriended => _isVi ? 'Vừa kết bạn' : 'Recently friended';
  String get blockActivityFromMe =>
      _isVi
          ? 'Chặn người này xem hoạt động của tôi'
          : 'Block this person from seeing my activity';
  String get doneLabel => _isVi ? 'XONG' : 'DONE';
  String get cancelActionLabel => _isVi ? 'HỦY' : 'CANCEL';
  String get saveActionLabel => _isVi ? 'LƯU' : 'SAVE';

  // Chat Options Detailed
  String featureUnderDev(String feature) =>
      _isVi
          ? 'Tính năng $feature đang được phát triển'
          : 'Feature $feature is under development';
  String get editNicknameAction => _isVi ? 'Đổi tên gợi nhớ' : 'Edit nickname';
  String get nicknamePlaceholder =>
      _isVi ? 'Nhập tên gợi nhớ' : 'Enter nickname';
  String get autoDeleteMessages =>
      _isVi ? 'Tin nhắn tự xóa' : 'Auto-delete messages';
  String get autoDeleteNote =>
      _isVi
          ? 'Tin nhắn sẽ tự động biến mất sau khoảng thời gian được chọn.'
          : 'Messages will automatically disappear after the selected duration.';
  String get off => _isVi ? 'Không tự xóa' : 'Off';
  String get deleteHistoryTitleMsg =>
      _isVi ? 'Xóa lịch sử trò chuyện?' : 'Delete chat history?';
  String get deleteHistoryWarning =>
      _isVi
          ? 'Toàn bộ tin nhắn sẽ bị ẩn đi. Bạn không thể hoàn tác thao tác này.'
          : 'All messages will be hidden. You cannot undo this action.';
  String get searchMessagesAction =>
      _isVi ? 'Tìm\ntin nhắn' : 'Search\nmessages';
  String get viewProfileQuickAction =>
      _isVi ? 'Trang\ncá nhân' : 'View\nprofile';
  String get changeWallpaperQuickAction =>
      _isVi ? 'Đổi\nhình nền' : 'Change\nwallpaper';
  String get muteNotifsQuickAction => _isVi ? 'Tắt\nthông báo' : 'Mute\nnotifs';
  String get markAsFavoriteAction =>
      _isVi ? 'Đánh dấu bạn thân' : 'Mark as favorite';
  String get deleteHistoryAction =>
      _isVi ? 'Xóa lịch sử trò chuyện' : 'Delete chat history';
  String get sharedTimelineAction =>
      _isVi ? 'Nhật ký chung' : 'Shared timeline';
  String get mediaDocsLinksAction =>
      _isVi ? 'Ảnh, file, link' : 'Photos, files, links';
  String get noSharedMediaNote =>
      _isVi ? 'Chưa có phương tiện nào được chia sẻ' : 'No shared media yet';
  String createGroupWithLabel(String name) =>
      _isVi ? 'Tạo nhóm với $name' : 'Create group with $name';
  String addToGroupLabel(String name) =>
      _isVi ? 'Thêm $name vào nhóm' : 'Add $name to group';
  String get viewSharedGroupsAction =>
      _isVi ? 'Xem nhóm chung' : 'View shared groups';
  String get pinConversationAction =>
      _isVi ? 'Ghim trò chuyện' : 'Pin conversation';
  String get hideConversationAction =>
      _isVi ? 'Ẩn trò chuyện' : 'Hide conversation';
  String get notifyCallsAction => _isVi ? 'Báo cuộc gọi đến' : 'Notify calls';
  String get personalSettingsAction =>
      _isVi ? 'Cài đặt cá nhân' : 'Personal settings';
  String get reportUserAction => _isVi ? 'Báo xấu' : 'Report';
  String get blockMgmtAction => _isVi ? 'Quản lý chặn' : 'Block management';
  String get chatStorageAction =>
      _isVi ? 'Dung lượng trò chuyện' : 'Chat storage';

  // Message Action Menu
  String get replyAction => _isVi ? 'Trả lời' : 'Reply';
  String get forwardAction => _isVi ? 'Chuyển tiếp' : 'Forward';
  String get saveToDocsAction => _isVi ? 'Lưu My Documents' : 'Save Msg';
  String get copyAction => _isVi ? 'Sao chép' : 'Copy';
  String get pinActionTag => _isVi ? 'Ghim' : 'Pin';
  String get reminderAction => _isVi ? 'Nhắc hẹn' : 'Reminder';
  String get selectMultiAction => _isVi ? 'Chọn nhiều' : 'Select multi';
  String get quickReplyAction => _isVi ? 'Tin nhắn nhanh' : 'Quick reply';
  String get translateAction => _isVi ? 'Dịch' : 'Translate';
  String get speakAction => _isVi ? 'Đọc văn bản' : 'Speak';
  String get detailsAction => _isVi ? 'Chi tiết' : 'Info';
  String get newTagLabel => _isVi ? 'MỚI' : 'NEW';

  // Message Bubble Status / Dialog
  String get msgSending => _isVi ? 'Đang gửi...' : 'Sending...';
  String get msgSendFailed => _isVi ? 'Gửi thất bại' : 'Send failed';
  String get msgSent => _isVi ? 'Đã gửi' : 'Sent';
  String get msgDelivered => _isVi ? 'Đã nhận' : 'Delivered';
  String get msgSeen => _isVi ? 'Đã xem' : 'Seen';
  String get msgRecalled => _isVi ? 'Tin nhắn đã thu hồi' : 'Message recalled';
  String get msgCopiedToast =>
      _isVi ? 'Đã sao chép tin nhắn' : 'Message copied';
  String get recallMessageTitle =>
      _isVi ? 'Thu hồi tin nhắn' : 'Recall message';
  String get recallMessagePrompt =>
      _isVi
          ? 'Tin nhắn này sẽ bị thu hồi với mọi người. Tiếp tục?'
          : 'This message will be removed for everyone. Continue?';
  String get deleteMessageTitle => _isVi ? 'Xóa tin nhắn' : 'Delete message';
  String get deleteMessagePrompt =>
      _isVi
          ? 'Tin nhắn này chỉ bị xóa ở phía bạn.'
          : 'This removes the message only for you.';

  // Durations
  String get minute => _isVi ? 'phút' : 'min';
  String get hour => _isVi ? 'giờ' : 'hour';
  String get day => _isVi ? 'ngày' : 'day';
  String get week => _isVi ? 'tuần' : 'week';
}
