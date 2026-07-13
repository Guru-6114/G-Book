// lib/screens/delete_khata_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Khatabook-style "Delete Khata" confirmation screen. Deleting a khata is a
// soft delete: it moves the khata into the Recycle Bin (LocalDatabase) for
// 30 days before being permanently purged, rather than deleting it outright.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';
import '../services/local_database.dart';
import '../theme/app_theme.dart';

class DeleteKhataScreen extends StatefulWidget {
  const DeleteKhataScreen({super.key});

  @override
  State<DeleteKhataScreen> createState() => _DeleteKhataScreenState();
}

class _DeleteKhataScreenState extends State<DeleteKhataScreen> {
  final _confirmCtrl = TextEditingController();
  bool _deleting = false;
  late String _businessName;

  @override
  void initState() {
    super.initState();
    _businessName = context.read<AuthProvider>().profile?.businessName ?? '';
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _canDelete =>
      _businessName.trim().isNotEmpty &&
      _confirmCtrl.text.trim() == _businessName.trim();

  Future<void> _delete() async {
    if (!_canDelete || _deleting) return;
    setState(() => _deleting = true);

    final auth = context.read<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) {
      setState(() => _deleting = false);
      return;
    }

    try {
      // Soft-delete: move this khata (and everything in it) to the Recycle
      // Bin instead of deleting it immediately — 30-day retention, same as
      // Khatabook.
      await LocalDatabase.instance.softDeleteBusinessProfile(profile.id);

      if (!mounted) return;

      // The app doesn't yet have a book-switcher UI, so this khata was the
      // only one in scope for this session. Sign the user out — the next
      // login will either pick another surviving khata or prompt to create
      // a new one.
      await auth.logout();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$_businessName" moved to Recycle Bin')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete khata: $e')),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _businessName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delete Khata',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFFD32F2F), height: 1.4),
                children: [
                  const TextSpan(text: "You are going to delete '"),
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text:
                        "'. All the data in this book will be moved to the "
                        "Recycle Bin. It will be permanently deleted after "
                        "30 days unless you restore it before then.",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                hintText: "To delete, type '$name'",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _canDelete && !_deleting ? _delete : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _canDelete
                      ? const Color(0xFFD32F2F)
                      : Colors.grey.shade300,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
                child: _deleting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'DELETE',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: _canDelete
                              ? Colors.white
                              : Colors.grey.shade600,
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