// lib/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  String _languageCode = 'en';
  Locale _locale = const Locale('en');

  String get languageCode => _languageCode;
  Locale get locale => _locale;
  AppLocalizations get t => AppLocalizations(_languageCode);

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'label': 'English', 'abbr': 'E', 'native': 'English'},
    {'code': 'hi', 'label': 'हिंदी', 'abbr': 'हि', 'native': 'हिन्दी'},
    {'code': 'hin', 'label': 'Hinglish', 'abbr': 'H', 'native': 'Hinglish'},
    {'code': 'mr', 'label': 'मराठी', 'abbr': 'म', 'native': 'मराठी'},
    {'code': 'gu', 'label': 'ગુજરાતી', 'abbr': 'ગુ', 'native': 'ગુજરાતી'},
    {'code': 'pa', 'label': 'ਪੰਜਾਬੀ', 'abbr': 'ਪੰ', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'ta', 'label': 'தமிழ்', 'abbr': 'த', 'native': 'தமிழ்'},
    {'code': 'te', 'label': 'తెలుగు', 'abbr': 'తె', 'native': 'తెలుగు'},
    {'code': 'kn', 'label': 'ಕನ್ನಡ', 'abbr': 'ಕ', 'native': 'ಕನ್ನಡ'},
    {'code': 'bn', 'label': 'বাংলা', 'abbr': 'বা', 'native': 'বাংলা'},
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? 'en';
    _setLanguage(saved);
  }

  void _setLanguage(String code) {
    _languageCode = code;
    // Map our codes to proper locale codes
    final localeMap = {
      'en': 'en',
      'hi': 'hi',
      'hin': 'hi', // Hinglish uses Hindi locale
      'mr': 'mr',
      'gu': 'gu',
      'pa': 'pa',
      'ta': 'ta',
      'te': 'te',
      'kn': 'kn',
      'bn': 'bn',
    };
    _locale = Locale(localeMap[code] ?? 'en');
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
    _setLanguage(code);
  }

  String tr(String key) => AppLocalizations(_languageCode).get(key);

  String get currentLanguageName {
    final lang = supportedLanguages.firstWhere(
      (l) => l['code'] == _languageCode,
      orElse: () => supportedLanguages.first,
    );
    return lang['label'] ?? 'English';
  }
}