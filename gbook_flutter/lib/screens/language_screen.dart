// lib/screens/language_screen.dart
// PASTE TO: gbook_flutter/lib/screens/language_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'permissions_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selected = 'en';

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English', 'abbr': 'E'},
    {'code': 'hi', 'label': 'हिंदी', 'abbr': 'हि'},
    {'code': 'hin', 'label': 'Hinglish', 'abbr': 'H'},
    {'code': 'mr', 'label': 'मराठी', 'abbr': 'म'},
    {'code': 'gu', 'label': 'ગુજરાતી', 'abbr': 'ગુ'},
    {'code': 'pa', 'label': 'ਪੰਜਾਬੀ', 'abbr': 'ਪੰ'},
    {'code': 'ta', 'label': 'தமிழ்', 'abbr': 'த'},
    {'code': 'te', 'label': 'తెలుగు', 'abbr': 'తె'},
    {'code': 'kn', 'label': 'ಕನ್ನಡ', 'abbr': 'ಕ'},
    {'code': 'bn', 'label': 'বাংলা', 'abbr': 'বা'},
  ];

  Future<void> _proceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selected);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PermissionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with logo
            Container(
              width: double.infinity,
              color: AppTheme.primaryColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'GBook',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  // Language display (top right)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _languages.firstWhere(
                            (l) => l['code'] == _selected,
                            orElse: () => _languages.first,
                          )['label']!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                        ),
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'Select your language',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Language grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                        children: _languages.map((lang) {
                          final isSelected = _selected == lang['code'];
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _selected = lang['code']!),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                        .withValues(alpha: 0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : const Color(0xFFE0E0E0),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        lang['abbr']!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      lang['label']!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : const Color(0xFF212121),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      'By continuing, you agree to our Privacy Policy and T&C',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    'START USING GBOOK',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}