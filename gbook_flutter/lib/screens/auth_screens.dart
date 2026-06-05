// lib/screens/auth_screens.dart
// PASTE TO: gbook_flutter/lib/screens/auth_screens.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../providers/providers.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import '../models/models.dart';
import 'home_screen.dart';

// ── AuthScreen ─────────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      AppHelpers.showErrorSnackBar(
          context, 'Please enter a valid 10-digit number');
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final sent = await auth.sendOtp(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    if (sent) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)),
      );
    } else {
      AppHelpers.showErrorSnackBar(context, 'Failed to send OTP');
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Logo header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GBook',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24, thickness: 1),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trust badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      color: Colors.white, size: 20),
                                  Text(
                                    '100%\nSAFE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 6,
                                      fontWeight: FontWeight.w700,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Trusted by 5 Crore+ businesses across India',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF424242),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Phone input row
                    Row(
                      children: [
                        // Country code box
                        Container(
                          height: 54,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.primaryColor, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🇮🇳',
                                  style: TextStyle(fontSize: 20)),
                              SizedBox(width: 6),
                              Text(
                                '+91',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Color(0xFF212121),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 54,
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              autofocus: true,
                              style: const TextStyle(
                                  fontSize: 18, letterSpacing: 2),
                              decoration: InputDecoration(
                                hintText: 'Mobile Number',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 16,
                                  letterSpacing: 0,
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 16),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  borderSide: const BorderSide(
                                      color: Color(0xFFBDBDBD)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(6),
                                  borderSide: BorderSide(
                                      color: AppTheme.primaryColor,
                                      width: 2),
                                ),
                              ),
                              onSubmitted: (_) => _sendOtp(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),

            // GET OTP button + disclaimer
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _sendOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text(
                              'GET OTP',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF757575)),
                      children: [
                        TextSpan(
                            text: 'By continuing, you agree to our '),
                        TextSpan(
                          text: 'Terms and Conditions',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ', and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OtpScreen ──────────────────────────────────────────────────────────────────
class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _countdown = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
        _startCountdown();
      } else {
        setState(() => _canResend = true);
      }
    });
  }

  String get _otp => _ctls.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length != 6) {
      AppHelpers.showErrorSnackBar(context, 'Please enter the 6-digit OTP');
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.verifyOtp(widget.phone, _otp);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      if (auth.profile == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  ProfileSetupScreen(phone: widget.phone)),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } else {
      AppHelpers.showErrorSnackBar(context, 'Invalid OTP. Try again.');
    }
  }

  @override
  void dispose() {
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Verify OTP',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'OTP sent to +91 ${widget.phone}',
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF424242)),
            ),
            const SizedBox(height: 32),

            // 6 OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 46,
                  height: 54,
                  child: TextFormField(
                    controller: _ctls[i],
                    focusNode: _nodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: AppTheme.primaryColor, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                            color: Color(0xFFBDBDBD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                            color: AppTheme.primaryColor, width: 2),
                      ),
                    ),
                    onChanged: (v) {
                      if (v.isNotEmpty && i < 5) {
                        _nodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _nodes[i - 1].requestFocus();
                      }
                      setState(() {});
                      if (_otp.length == 6) _verify();
                    },
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Resend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _canResend
                      ? "Didn't receive OTP? "
                      : 'Resend OTP in ${_countdown}s',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF757575)),
                ),
                if (_canResend)
                  GestureDetector(
                    onTap: () async {
                      setState(() {
                        _canResend = false;
                        _countdown = 30;
                      });
                      _startCountdown();
                      if (!mounted) return;
                      await context
                          .read<AuthProvider>()
                          .sendOtp(widget.phone);
                    },
                    child: Text(
                      'RESEND',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Verify & Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ProfileSetupScreen ─────────────────────────────────────────────────────────
class ProfileSetupScreen extends StatefulWidget {
  final String phone;
  const ProfileSetupScreen({super.key, required this.phone});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // FIX: use a state variable instead of value= on DropdownButtonFormField
  String _category = 'Retail';
  bool _saving = false;

  static const List<String> _categories = [
    'Retail',
    'Wholesale',
    'Services',
    'Manufacturing',
    'Food & Beverages',
    'Pharmacy',
    'Electronics',
    'Clothing',
    'Agriculture',
    'Other',
  ];

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final profile = BusinessProfile(
      id: AppHelpers.generateId(),
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      phone: widget.phone,
      email: _emailCtrl.text.trim().isEmpty
          ? null
          : _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      category: _category,
      createdAt: DateTime.now(),
    );

    try {
      await context.read<AuthProvider>().saveProfile(profile);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppHelpers.showErrorSnackBar(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Setup Your Business'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            const Text(
              'Tell us about your business',
              style: TextStyle(
                  fontSize: 14, color: Color(0xFF757575)),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _businessNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Business Name *',
                prefixIcon: Icon(Icons.store_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ownerNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Owner Name *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Business Address (optional)',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 14),
            // FIX: Use DropdownButtonFormField with NO value= prop;
            // use initialValue via the state variable _category
            DropdownButtonFormField<String>(
              // FIX: removed deprecated value= and replaced with
              // managing selection purely via onChanged + _category state
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Business Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _categories
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _category = v);
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'Save & Continue',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}