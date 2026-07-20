// lib/screens/sms_settings_screen.dart
//
// Matches the two reference screenshots:
//  - "My Number" tab: SIM picker, benefits list, sample SMS preview
//  - "GBook SMS" tab: free SMS limit card, bullet list, sample SMS preview
// All strings now go through context.l10n so this screen re-renders in
// whatever language is active app-wide.
//
// FIX: the SIM picker now reads the phone's real SIM cards (via
// SimInfoService) and shows their actual carrier names — e.g.
// "SIM 1 (Airtel)" — instead of a hardcoded 'SIM 1' / 'SIM 2' placeholder,
// matching Khatabook's behaviour.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/locale_provider.dart';
import '../services/sim_info_service.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../l10n/app_localizations.dart';

class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  String _smsMode = 'my_number'; // 'my_number' or 'gbook_sms'
  String _simCard = 'Default';
  List<SimCardInfo> _simCards = [];
  bool _simLoading = true;
  int _smsSentThisMonth = 0;
  final int _monthlyLimit = 100;
  bool _saving = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSimCards();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _smsMode = prefs.getString('sms_mode') ?? 'my_number';
      _simCard = prefs.getString('sim_card') ?? 'Default';
      _smsSentThisMonth = prefs.getInt('sms_sent_month') ?? 0;
      _loading = false;
    });
  }

  Future<void> _loadSimCards() async {
    final cards = await SimInfoService.instance.getSimCards();
    if (!mounted) return;
    setState(() {
      _simCards = cards;
      _simLoading = false;
      // If the previously saved selection no longer matches a real SIM on
      // this device (e.g. SIM was removed, or this is the first read),
      // fall back to Default instead of showing a stale/invalid value.
      final validLabels = ['Default', ..._simCards.map((c) => c.label)];
      if (!validLabels.contains(_simCard)) {
        _simCard = 'Default';
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_mode', _smsMode);
    await prefs.setString('sim_card', _simCard);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _saving = false);
    AppHelpers.showSuccessSnackBar(
        context, context.l10n.get('save') == 'Save' ? 'SMS Settings saved' : '${context.l10n.get('sms_settings')} ${context.l10n.get('save')}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          title: Text(t.get('sms_settings')),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: Text(t.get('sms_settings'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      t.get('send_sms_from'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF212121)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _smsMode = 'my_number'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: _smsMode == 'my_number'
                                      ? Colors.white
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(7),
                                    bottomLeft: Radius.circular(7),
                                  ),
                                  border: _smsMode == 'my_number'
                                      ? Border.all(
                                          color: AppTheme.primaryColor,
                                          width: 2)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.smartphone,
                                        size: 18,
                                        color: _smsMode == 'my_number'
                                            ? AppTheme.primaryColor
                                            : Colors.grey),
                                    const SizedBox(width: 6),
                                    Text(
                                      t.get('my_number'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _smsMode == 'my_number'
                                            ? AppTheme.primaryColor
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _smsMode = 'gbook_sms'),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  color: _smsMode == 'gbook_sms'
                                      ? const Color(0xFFFFF3F3)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(7),
                                    bottomRight: Radius.circular(7),
                                  ),
                                  border: _smsMode == 'gbook_sms'
                                      ? Border.all(
                                          color: const Color(0xFFB71C1C),
                                          width: 2)
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      color: const Color(0xFFB71C1C),
                                      child: const Center(
                                        child: Text('G',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      t.get('gbook_sms'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _smsMode == 'gbook_sms'
                                            ? const Color(0xFFB71C1C)
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_smsMode == 'my_number') ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sim_card_outlined,
                                color: Color(0xFF616161), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(t.get('select_sim'),
                                  style: const TextStyle(fontSize: 14)),
                            ),
                            if (_simLoading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            else
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _simCard,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'Default',
                                      child: Text(t.get('default_text'),
                                          style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    ..._simCards.map((c) => DropdownMenuItem(
                                          value: c.label,
                                          child: Text(c.label,
                                              style: TextStyle(
                                                  color:
                                                      AppTheme.primaryColor,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _simCard = v!),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(t.get('benefits'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    _BenefitRow(t.get('sms_auto_sent')),
                    _BenefitRow(t.get('customer_receives_sms')),
                    _BenefitRow(t.get('complete_details_sms')),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.arrow_back, size: 16),
                                      SizedBox(width: 6),
                                      Text('Shopping',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Sample',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: Text(
                                'Monday, ${AppHelpers.formatDate(DateTime.now())}, ${TimeOfDay.now().format(context)}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9E9E9E)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFE0E0E0)),
                              ),
                              child: const Text(
                                'Hi, Entry added for Rs -200 on 03 Apr.\nTotal dues : Rs +200.\nCheck history: https://gbook.com/t/XXX\nThank you',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF424242)),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF424242)),
                                  children: [
                                    TextSpan(
                                        text: '${t.get('max_sms_limit')} ',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    TextSpan(text: t.get('as_per_mobile_plan')),
                                    const WidgetSpan(
                                      child: Padding(
                                        padding:
                                            EdgeInsets.only(left: 4),
                                        child: Icon(Icons.info_outline,
                                            size: 14,
                                            color: Color(0xFF9E9E9E)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline,
                                      color: Color(0xFFB71C1C), size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t.get('free_sms_limit'),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15)),
                                      Text(
                                        t.get('use_coins'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF757575)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE0E0E0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('$_smsSentThisMonth',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18)),
                                        Text(t.get('sms_sent_month'),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 40,
                                      color: const Color(0xFFE0E0E0)),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('$_monthlyLimit',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18)),
                                        Text(t.get('monthly_sms_limit'),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9E9E9E))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(t.get('send_sms_via_gbook'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    _BulletRow(t.get('sms_from_gbook_number'),
                        color: const Color(0xFFB71C1C)),
                    _BulletRow(t.get('limited_details'),
                        color: const Color(0xFFB71C1C)),
                    _BulletRow(t.get('marked_spam'),
                        color: const Color(0xFFB71C1C)),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFB71C1C)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.arrow_back, size: 16),
                                      SizedBox(width: 6),
                                      Text('JM-GBKTBK',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFB71C1C),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Text('Sample',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              child: Text(
                                'Monday, ${AppHelpers.formatDate(DateTime.now())}, ${TimeOfDay.now().format(context)}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF9E9E9E)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCECEC),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You gave: ₹ 400\n\nBalance: +(₹ 200)\nhttps://gbook.com/t/XXX',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF424242)),
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text('${t.get('max_sms_limit')} $_monthlyLimit per month',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.info_outline,
                                      size: 14, color: Color(0xFF9E9E9E)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _smsMode == 'gbook_sms'
                      ? const Color(0xFFB71C1C)
                      : AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(t.get('save').toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletRow(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}