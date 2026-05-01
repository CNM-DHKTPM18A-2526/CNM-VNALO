import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vnalo_mobile/core/localization/common_texts.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';
import 'package:vnalo_mobile/features/auth/screens/qr_scanner_screen.dart';
import 'package:vnalo_mobile/features/auth/providers/auth_provider.dart';
import 'package:vnalo_mobile/features/auth/widgets/phone_input.dart';
import 'package:vnalo_mobile/features/contacts/screens/send_request_screen.dart';
import 'package:vnalo_mobile/services/api_service.dart';
import 'package:vnalo_mobile/services/friend_service.dart';
import 'package:vnalo_mobile/services/qr_service.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key});

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = '+84';
  bool _isValid = false;
  bool _isSearching = false;
  String? _qrPayload;
  bool _isLoadingQr = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _loadMyQr();
  }

  void _onPhoneChanged() {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Simple validation: 9-11 digits
    final isValid = digits.length >= 9 && digits.length <= 11;
    if (isValid != _isValid) {
      setState(() => _isValid = isValid);
    }
  }

  String _buildFullPhone() {
    var digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0') && digits.length > 1) {
      digits = digits.substring(1);
    }
    return '$_countryCode$digits';
  }

  Future<void> _loadMyQr() async {
    if (_isLoadingQr) {
      return;
    }
    setState(() => _isLoadingQr = true);
    try {
      final payload = await QrService(
        context.read<ApiService>(),
      ).generateFriendQrRawPayload();
      if (!mounted) {
        return;
      }
      setState(() => _qrPayload = payload);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CommonTexts.of(context, listen: false).cannotLoadQr)),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingQr = false);
      }
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _searchByPhone() async {
    if (!_isValid || _isSearching) return;

    final phone = _buildFullPhone();
    final friendService = context.read<FriendService>();

    setState(() {
      _isSearching = true;
    });

    try {
      final user = await friendService.searchUserByPhone(phone);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SendRequestScreen(targetUser: user)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final common = CommonTexts.of(context, listen: false);
      final msg = switch (e.code) {
        'USER_001' => common.userNotFound,
        _ => common.userSearchError,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      final common = CommonTexts.of(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${common.errorOccurred}: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final displayName = auth.user?.displayName ?? 'VNALO';
    final scaffoldBg = isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground;
    final sectionBg = isDarkMode ? DarkColors.surface : Colors.white;
    final common = CommonTexts.of(context);

    return Scaffold(
      backgroundColor: isDarkMode ? DarkColors.scaffold : AppColors.sectionBackground,
      appBar: AppBar(
        forceMaterialTransparency: !isDarkMode,
        backgroundColor: isDarkMode ? DarkColors.appBarBg : Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: isDarkMode 
          ? null 
          : Container(decoration: const BoxDecoration(gradient: AppColors.appBarGradient)),
        title: Text(
          common.addFriendHeader, 
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18, 
            fontWeight: FontWeight.w600
          )
        ),
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              color: isDarkMode ? DarkColors.surface : const Color(0xFF3F5F85),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 188,
                  height: 188,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child:
                      _isLoadingQr
                           ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                           : (_qrPayload == null || _qrPayload!.isEmpty)
                           ? Icon(Icons.qr_code_2_rounded, size: 146, color: Colors.grey.shade300)
                           : Padding(
                             padding: const EdgeInsets.all(10),
                             child: QrImageView(
                               data: _qrPayload!,
                               version: QrVersions.auto,
                               eyeStyle: const QrEyeStyle(
                                 eyeShape: QrEyeShape.square,
                                 color: Colors.black,
                               ),
                               dataModuleStyle: const QrDataModuleStyle(
                                 dataModuleShape: QrDataModuleShape.square,
                                 color: Colors.black,
                               ),
                             ),
                           ),
                ),
                const SizedBox(height: 10),
                Text(
                  common.scanMyQrToAdd,
                  style: const TextStyle(color: Color(0xFFD7E4F7), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PhoneInput(
                    controller: _phoneController,
                    selectedCountryCode: _countryCode,
                    onCountryCodeChanged: (val) => setState(() => _countryCode = val),
                    hintText: common.phoneNumberHint,
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor:
                        _isSearching
                        ? Colors.transparent
                        : (_isValid
                             ? (isDarkMode ? DarkColors.primary : AppColors.primary)
                             : (isDarkMode ? DarkColors.surface : AppColors.itemDivider)),
                    child: IconButton(
                      onPressed: (_isValid && !_isSearching) ? _searchByPhone : null,
                      icon: _isSearching
                           ? const SizedBox(
                               width: 20,
                               height: 20,
                               child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                             )
                           : Icon(
                               Icons.arrow_forward,
                               color: _isValid ? Colors.white : (isDarkMode ? Colors.white24 : LightColors.textHint),
                               size: 26,
                             ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: sectionBg,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.qr_code_scanner, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.scanQR, style: const TextStyle(fontSize: 18)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 70, color: AppColors.itemDivider),
                ListTile(
                  leading: Icon(Icons.contact_page_outlined, color: isDarkMode ? DarkColors.primary : AppColors.primary),
                  title: Text(common.peopleNearby, style: const TextStyle(fontSize: 18)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(common.featureUnderDevelopment)),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_qrPayload == null && !_isLoadingQr)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _loadMyQr,
                icon: const Icon(Icons.refresh),
                label: Text(common.reloadQr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? DarkColors.surface : const Color(0xFFE5E7EB),
                  foregroundColor: isDarkMode ? DarkColors.textPrimary : LightColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              common.viewSentRequestsNote,
              style: const TextStyle(color: LightColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
