// lib/screens/app_lock_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Khatabook-style App Lock: setup screen, create/confirm PIN keypad flow,
// and the unlock screen shown after splash when logged in + lock enabled.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_lock_service.dart';

// ══════════════════════════════════════════════════════════════════════════
// APP LOCK SETTINGS SCREEN  (More → Settings → "App Lock")
// ══════════════════════════════════════════════════════════════════════════
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _loading = true;
  bool _hasPin = false;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasPin = await AppLockService.instance.hasPin();
    final enabled = await AppLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _startSetup() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePinScreen()),
    );
    if (success == true) {
      await _showSuccessDialog();
      await _load();
    }
  }

  Future<void> _changePin() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const _VerifyPinScreen(
          title: 'Enter current PIN',
          subtitle: 'Confirm your current PIN to continue',
        ),
      ),
    );
    if (verified != true || !mounted) return;
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePinScreen()),
    );
    if (success == true) {
      await _showSuccessDialog(changed: true);
      await _load();
    }
  }

  Future<void> _showSuccessDialog({bool changed = false}) {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xFF2E7D32), size: 40),
            ),
            const SizedBox(height: 18),
            Text(
              changed ? 'PIN changed successfully' : 'App lock successfully set',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              changed
                  ? 'Your GBook PIN has been updated'
                  : 'You have successfully secured your GBook app with the 4-digit PIN',
              style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OKAY',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleOff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn off App Lock'),
        content: const Text(
            'Are you sure you want to remove PIN protection from GBook?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Turn Off', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await AppLockService.instance.disable();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('App Lock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.menu_book_outlined,
                            color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Use a 4-digit GBook PIN',
                              style:
                                  TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Create a PIN for your GBook app that only you know',
                              style:
                                  TextStyle(fontSize: 12, color: Color(0xFF757575)),
                            ),
                            if (_hasPin) ...[
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _changePin,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Change PIN',
                                        style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    Icon(Icons.chevron_right,
                                        color: AppTheme.primaryColor, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Radio<bool>(
                        value: true,
                        groupValue: true,
                        onChanged: (_) {},
                        activeColor: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!_hasPin)
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _startSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('CONTINUE',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('App Lock',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(
                                _enabled ? 'Enabled' : 'Disabled',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: _enabled
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enabled,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (v) async {
                            if (v) {
                              await AppLockService.instance.enable();
                              await _load();
                            } else {
                              await _toggleOff();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SHARED PIN KEYPAD UI
// ══════════════════════════════════════════════════════════════════════════
class _PinDots extends StatelessWidget {
  final int length;
  final int filled;
  const _PinDots({required this.length, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.transparent,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      }),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  final VoidCallback onBackspace;

  const _PinKeypad({required this.onKeyTap, required this.onBackspace});

  Widget _key({String? label, VoidCallback? onTap, Widget? child}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Center(
            child: child ??
                Text(
                  label ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(children: row.map((d) => _key(label: d, onTap: () => onKeyTap(d))).toList()),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            _key(label: '0', onTap: () => onKeyTap('0')),
            _key(
              onTap: onBackspace,
              child: const Icon(Icons.backspace_outlined, color: Colors.white, size: 26),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CREATE PIN (create → confirm)
// ══════════════════════════════════════════════════════════════════════════
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _firstPin = '';
  String _entered = '';
  bool _confirming = false;
  String? _error;

  void _onKeyTap(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _handleComplete);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _handleComplete() async {
    if (!_confirming) {
      setState(() {
        _firstPin = _entered;
        _entered = '';
        _confirming = true;
      });
      return;
    }

    if (_entered == _firstPin) {
      await AppLockService.instance.setPin(_firstPin);
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'PINs did not match. Try again.';
        _entered = '';
        _firstPin = '';
        _confirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text(
              _confirming ? 'Confirm your 4-digit PIN' : 'Create a new 4-digit PIN',
              style:
                  const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _confirming
                    ? 'Re-enter the PIN to secure your GBook app'
                    : 'Set a PIN to secure your GBook app',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            _PinDots(length: 4, filled: _entered.length),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13)),
            ],
            const Spacer(),
            _PinKeypad(onKeyTap: _onKeyTap, onBackspace: _onBackspace),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// VERIFY PIN (used before "Change PIN")
// ══════════════════════════════════════════════════════════════════════════
class _VerifyPinScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  const _VerifyPinScreen({required this.title, required this.subtitle});

  @override
  State<_VerifyPinScreen> createState() => _VerifyPinScreenState();
}

class _VerifyPinScreenState extends State<_VerifyPinScreen> {
  String _entered = '';
  String? _error;

  void _onKeyTap(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _verify);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final ok = await AppLockService.instance.verifyPin(_entered);
    if (ok) {
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      appBar: AppBar(backgroundColor: AppTheme.primaryColor, elevation: 0),
      body: SafeArea(
        child: Column(
          children: [
            Text(widget.title,
                style:
                    const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(widget.subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: 30),
            _PinDots(length: 4, filled: _entered.length),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13)),
            ],
            const Spacer(),
            _PinKeypad(onKeyTap: _onKeyTap, onBackspace: _onBackspace),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// UNLOCK SCREEN — shown right after splash when logged in + lock enabled
// ══════════════════════════════════════════════════════════════════════════
class UnlockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const UnlockScreen({super.key, required this.onUnlocked});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  String _entered = '';
  String? _error;

  void _onKeyTap(String digit) {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = null;
    });
    if (_entered.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _verify);
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _verify() async {
    final ok = await AppLockService.instance.verifyPin(_entered);
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _error = 'Incorrect PIN. Try again.';
        _entered = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              const Text(
                'Unlock GBook',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Enter your 4-digit PIN to continue',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 36),
              _PinDots(length: 4, filled: _entered.length),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13)),
              ],
              const Spacer(),
              _PinKeypad(onKeyTap: _onKeyTap, onBackspace: _onBackspace),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}