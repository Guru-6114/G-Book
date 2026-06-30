// lib/screens/language_screen.dart
//
// FIX: The previous version only updated a local `_selected` String inside
// this screen's own State — it never told the rest of the app anything
// changed, so the whole "tap a language → app changes" flow was broken by
// design even before you got to SharedPreferences. This version writes
// through LocaleProvider, which is registered above MaterialApp in
// main.dart — so every screen that reads context.l10n / AppLocalizations
// rebuilds immediately app-wide, with no restart needed.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme/app_theme.dart';

class LanguageScreen extends StatefulWidget {
  /// When true, this is shown as part of first-run onboarding (from
  /// SplashScreen flow) and "Start Using GBook" continues to permissions.
  /// When false (the normal case — opened from Settings > Language), it
  /// behaves as a simple picker: tap a language, it applies instantly, and
  /// you can just go back.
  final bool isOnboarding;
  final VoidCallback? onComplete;

  const LanguageScreen({
    super.key,
    this.isOnboarding = false,
    this.onComplete,
  });

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = context.read<LocaleProvider>().languageCode;
  }

  Future<void> _selectLanguage(String code) async {
    setState(() => _selected = code);
    // FIX: This is the line that actually makes the whole app switch
    // language. LocaleProvider persists it to SharedPreferences AND calls
    // notifyListeners(), which the Consumer<LocaleProvider> wrapping
    // MaterialApp in main.dart picks up instantly.
    await context.read<LocaleProvider>().setLanguage(code);

    if (!widget.isOnboarding) {
      // Settings flow: apply and pop straight back — like Khatabook does.
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _proceed() async {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languages = LocaleProvider.supportedLanguages;
    final t = context.watch<LocaleProvider>().t;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.isOnboarding
          ? null
          : AppBar(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              title: Text(t.get('language'),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.isOnboarding)
              Container(
                width: double.infinity,
                color: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
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
                            languages.firstWhere(
                              (l) => l['code'] == _selected,
                              orElse: () => languages.first,
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
                    Text(
                      t.get('select_language'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.8,
                        children: languages.map((lang) {
                          final isSelected = _selected == lang['code'];
                          return GestureDetector(
                            onTap: () => _selectLanguage(lang['code']!),
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
                                  if (isSelected) ...[
                                    const Spacer(),
                                    Icon(Icons.check_circle,
                                        color: AppTheme.primaryColor,
                                        size: 18),
                                    const SizedBox(width: 10),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.isOnboarding
                          ? 'By continuing, you agree to our Privacy Policy and T&C'
                          : '',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            if (widget.isOnboarding)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
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
                    child: Text(
                      t.get('start_using'),
                      style: const TextStyle(
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