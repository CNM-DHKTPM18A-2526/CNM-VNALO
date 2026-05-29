import 'package:flutter/material.dart';
import 'package:vnalo_mobile/core/utils/text_background_utils.dart';

class TextBackgroundPostWidget extends StatelessWidget {
  final String rawContent;

  const TextBackgroundPostWidget({super.key, required this.rawContent});

  @override
  Widget build(BuildContext context) {
    // Regex matches [TEXT_BACKGROUND:bgId|fontId|colorValue|fontSize|fontWeight|isItalic|textAlign]text content
    final regex = RegExp(r'^\[TEXT_BACKGROUND:(.*?)\|(.*?)\|(\d+)\|(\d+)\|(.*?)\|(.*?)\|(\d+)\](.*)$', dotAll: true);
    final match = regex.firstMatch(rawContent);

    if (match == null) {
      // Fallback if not valid format
      return Text(rawContent);
    }

    final bgId = match.group(1)!;
    final fontId = match.group(2)!;
    final colorValue = int.tryParse(match.group(3)!) ?? Colors.white.value;
    final fontSize = double.tryParse(match.group(4)!) ?? 28.0;
    final isBold = match.group(5) == 'bold';
    final isItalic = match.group(6) == 'true';
    final textAlignInt = int.tryParse(match.group(7)!) ?? 1;
    final content = match.group(8)!;

    final bgColors = TextBackgroundUtils.getBgColors(bgId);
    final fontFamily = TextBackgroundUtils.getFontFamily(fontId);
    final textColor = Color(colorValue);
    
    TextAlign textAlign;
    switch (textAlignInt) {
      case 0: textAlign = TextAlign.left; break;
      case 2: textAlign = TextAlign.right; break;
      default: textAlign = TextAlign.center; break;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: bgColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      alignment: Alignment.center,
      child: Text(
        content,
        textAlign: textAlign,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
          fontFamily: fontFamily,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.4),
              offset: const Offset(1, 1),
              blurRadius: 3,
            ),
          ],
        ),
      ),
    );
  }
}
