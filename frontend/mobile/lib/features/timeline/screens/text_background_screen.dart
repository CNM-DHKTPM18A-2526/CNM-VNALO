import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/theme/app_colors.dart';

import 'package:vnalo_mobile/core/utils/text_background_utils.dart';

class TextBackgroundScreen extends StatefulWidget {
  final Function(String) onTextCreated;
  final String? initialTextContent;

  const TextBackgroundScreen({
    super.key, 
    required this.onTextCreated,
    this.initialTextContent,
  });

  @override
  State<TextBackgroundScreen> createState() => _TextBackgroundScreenState();
}

class _TextBackgroundScreenState extends State<TextBackgroundScreen> {
  final TextEditingController _textController = TextEditingController();
  String _selectedBgId = 'gradient_blue';
  String _selectedFontId = 'Default';
  Color _textColor = Colors.white;
  double _fontSize = 28;
  FontWeight _fontWeight = FontWeight.w500;
  bool _isItalic = false;
  int _textAlign = 1; // 0=left, 1=center, 2=right

  @override
  void initState() {
    super.initState();
    if (widget.initialTextContent != null && widget.initialTextContent!.startsWith('[TEXT_BACKGROUND:')) {
      final regex = RegExp(r'^\[TEXT_BACKGROUND:(.*?)\|(.*?)\|(\d+)\|(\d+)\|(.*?)\|(.*?)\|(\d+)\](.*)$', dotAll: true);
      final match = regex.firstMatch(widget.initialTextContent!);
      if (match != null) {
        _selectedBgId = match.group(1)!;
        _selectedFontId = match.group(2)!;
        _textColor = Color(int.tryParse(match.group(3)!) ?? Colors.white.value);
        _fontSize = double.tryParse(match.group(4)!) ?? 28.0;
        _fontWeight = match.group(5) == 'bold' ? FontWeight.bold : FontWeight.w500;
        _isItalic = match.group(6) == 'true';
        _textAlign = int.tryParse(match.group(7)!) ?? 1;
        _textController.text = match.group(8)!;
      }
    }
  }

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    const Color(0xFF333333),
    const Color(0xFFFFEB3B),
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.pink,
    Colors.purple,
    Colors.teal,
    const Color(0xFFFF6F00),
  ];

  List<Color> get _bgColors => TextBackgroundUtils.getBgColors(_selectedBgId);
  String? get _fontFamily => TextBackgroundUtils.getFontFamily(_selectedFontId);

  TextAlign get _textAlignValue {
    switch (_textAlign) {
      case 0: return TextAlign.left;
      case 2: return TextAlign.right;
      default: return TextAlign.center;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _createTextBackground() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung')),
      );
      return;
    }
    final content =
        '[TEXT_BACKGROUND:$_selectedBgId|$_selectedFontId|${_textColor.value}|${_fontSize.toInt()}|${_fontWeight == FontWeight.bold ? 'bold' : 'normal'}|$_isItalic|$_textAlign]${_textController.text}';
    Navigator.pop(context);
    widget.onTextCreated(content);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _createTextBackground,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Tạo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ====== PREVIEW AREA (text on gradient background) ======
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // Gradient background
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _bgColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Centered text input
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: IntrinsicWidth(
                      child: TextField(
                        controller: _textController,
                        maxLines: null,
                        textAlign: _textAlignValue,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        cursorColor: Colors.white,
                        style: TextStyle(
                          color: _textColor,
                          fontSize: _fontSize,
                          fontWeight: _fontWeight,
                          fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
                          fontFamily: _fontFamily,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              offset: const Offset(1, 1),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        decoration: InputDecoration(
                          hintText: 'Hôm nay bạn nghĩ gì?',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: _fontSize,
                            fontWeight: _fontWeight,
                          ),
                          border: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ),
                ),

                // Text alignment toggle (top right)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => setState(() => _textAlign = (_textAlign + 1) % 3),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _textAlign == 0
                            ? Icons.format_align_left
                            : _textAlign == 2
                                ? Icons.format_align_right
                                : Icons.format_align_center,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====== CONTROLS PANEL ======
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
            ),
            child: Column(
              children: [
                // ---- Row 1: Text formatting tools ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Bold
                        _buildFormatButton(
                          label: 'B',
                          weight: FontWeight.bold,
                          isActive: _fontWeight == FontWeight.bold,
                          onTap: () => setState(() {
                            _fontWeight = _fontWeight == FontWeight.bold ? FontWeight.normal : FontWeight.bold;
                          }),
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(width: 8),
                        // Italic
                        _buildFormatButton(
                          label: 'I',
                          weight: FontWeight.normal,
                          isActive: _isItalic,
                          isItalic: true,
                          onTap: () => setState(() => _isItalic = !_isItalic),
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(width: 16),
                        // Font size -
                        _buildSizeButton(Icons.text_decrease, () {
                          if (_fontSize > 14) setState(() => _fontSize -= 2);
                        }, isDarkMode),
                        const SizedBox(width: 8),
                        Text(
                          '${_fontSize.toInt()}',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Font size +
                        _buildSizeButton(Icons.text_increase, () {
                          if (_fontSize < 52) setState(() => _fontSize += 2);
                        }, isDarkMode),
                        const SizedBox(width: 16),
                        // Font selector chips
                        ...TextBackgroundUtils.fonts.map((f) => _buildFontChip(f, isDarkMode)),
                      ],
                    ),
                  ),
                ),

                // ---- Row 2: Background colors ----
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: TextBackgroundUtils.backgrounds.length,
                    itemBuilder: (context, i) {
                      final bg = TextBackgroundUtils.backgrounds[i];
                      final colors = bg['colors'] as List<Color>;
                      final isSelected = _selectedBgId == bg['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedBgId = bg['id'] as String),
                        child: Container(
                          width: 44,
                          height: 44,
                          margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors),
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [BoxShadow(color: colors.first.withValues(alpha: 0.5), blurRadius: 6)]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                // ---- Row 3: Text colors ----
                SizedBox(
                  height: 56,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _textColors.length,
                    itemBuilder: (context, i) {
                      final color = _textColors[i];
                      final isSelected = _textColor.value == color.value;
                      return GestureDetector(
                        onTap: () => setState(() => _textColor = color),
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(right: 10, top: 11, bottom: 11),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : (color.value == Colors.white.value
                                      ? Colors.grey.shade400
                                      : Colors.transparent),
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)]
                                : null,
                          ),
                          child: isSelected
                              ? Icon(
                                  Icons.check,
                                  size: 16,
                                  color: color.value == Colors.white.value ? Colors.black : Colors.white,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton({
    required String label,
    required FontWeight weight,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDarkMode,
    bool isItalic = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : (isDarkMode ? Colors.white10 : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? AppColors.primary : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: weight,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              color: isActive ? AppColors.primary : (isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSizeButton(IconData icon, VoidCallback onTap, bool isDarkMode) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDarkMode ? Colors.white24 : Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16, color: isDarkMode ? Colors.white60 : Colors.black54),
      ),
    );
  }

  Widget _buildFontChip(Map<String, dynamic> font, bool isDarkMode) {
    final isSelected = _selectedFontId == font['id'];
    if (font['id'] == 'Default') return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _selectedFontId = font['id'] as String),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDarkMode ? Colors.white24 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          font['name'] as String,
          style: TextStyle(
            fontSize: 12,
            fontFamily: font['family'] as String?,
            color: isSelected ? AppColors.primary : (isDarkMode ? Colors.white60 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
