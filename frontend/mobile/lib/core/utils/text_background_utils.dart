import 'package:flutter/material.dart';

class TextBackgroundUtils {
  static final List<Map<String, dynamic>> backgrounds = [
    {'id': 'gradient_blue',    'name': 'Xanh dương', 'colors': [const Color(0xFF667eea), const Color(0xFF764ba2)]},
    {'id': 'gradient_pink',    'name': 'Hồng',        'colors': [const Color(0xFFf093fb), const Color(0xFFf5576c)]},
    {'id': 'gradient_green',   'name': 'Xanh lá',     'colors': [const Color(0xFF11998e), const Color(0xFF38ef7d)]},
    {'id': 'gradient_orange',  'name': 'Cam',          'colors': [const Color(0xFFff9a9e), const Color(0xFFfecfef)]},
    {'id': 'gradient_sunset',  'name': 'Hoàng hôn',   'colors': [const Color(0xFFffecd2), const Color(0xFFfcb69f)]},
    {'id': 'gradient_purple',  'name': 'Tím',          'colors': [const Color(0xFFa18cd1), const Color(0xFFfbc2eb)]},
    {'id': 'gradient_love',    'name': 'Yêu thương',  'colors': [const Color(0xFFff9a9e), const Color(0xFFfad0c4)]},
    {'id': 'gradient_galaxy',  'name': 'Vũ trụ',      'colors': [const Color(0xFF0f0c29), const Color(0xFF302b63), const Color(0xFF24243e)]},
    {'id': 'gradient_ocean',   'name': 'Biển',         'colors': [const Color(0xFF2c3e50), const Color(0xFF4ca1af)]},
    {'id': 'gradient_fire',    'name': 'Lửa',          'colors': [const Color(0xFFff416c), const Color(0xFFff4b2b)]},
    {'id': 'gradient_gold',    'name': 'Vàng',         'colors': [const Color(0xFFf7971e), const Color(0xFFffd200)]},
    {'id': 'gradient_night',   'name': 'Đêm',          'colors': [const Color(0xFF232526), const Color(0xFF414345)]},
  ];

  static final List<Map<String, dynamic>> fonts = [
    {'id': 'Default',   'name': 'Mặc định', 'family': null},
    {'id': 'Serif',     'name': 'Serif',    'family': 'serif'},
    {'id': 'Monospace', 'name': 'Mono',     'family': 'monospace'},
    {'id': 'Cursive',   'name': 'Nghiêng',  'family': 'cursive'},
  ];

  static List<Color> getBgColors(String bgId) {
    final bg = backgrounds.firstWhere((b) => b['id'] == bgId, orElse: () => {'colors': [Colors.blue]});
    return (bg['colors'] as List<Color>?) ?? [Colors.blue];
  }

  static String? getFontFamily(String fontId) {
    final font = fonts.firstWhere((f) => f['id'] == fontId, orElse: () => {'family': null});
    return font['family'] as String?;
  }
}
