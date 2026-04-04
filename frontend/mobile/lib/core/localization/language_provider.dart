import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { vi, en }

class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';

  AppLanguage _language = AppLanguage.vi;

  AppLanguage get language => _language;

  String get label => _language == AppLanguage.vi ? 'Tiếng Việt' : 'English';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == AppLanguage.en.name) {
      _language = AppLanguage.en;
    }
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value.name);
  }
}
