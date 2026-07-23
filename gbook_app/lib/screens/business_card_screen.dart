// lib/screens/business_card_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Business Card templates screen (Khatabook-style): swipeable card designs,
// editable business details, and a Download (share as PNG) action.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

class _CardTemplate {
  final String name;
  final List<Color> gradient;
  final Color textColor;
  final bool ornate;
  const _CardTemplate({
    required this.name,
    required this.gradient,
    required this.textColor,
    this.ornate = false,
  });
}

const List<_CardTemplate> _kCardTemplates = [
  _CardTemplate(
    name: 'Classic White',
    gradient: [Colors.white, Color(0xFFF5F5F5)],
    textColor: Color(0xFF1565C0),
  ),
  _CardTemplate(
    name: 'Royal Blue',
    gradient: [Color(0xFF1565C0), Color(0xFF0D47A1)],
    textColor: Colors.white,
    ornate: true,
  ),
  _CardTemplate(
    name: 'Emerald',
    gradient: [Color(0xFF1A6B3C), Color(0xFF0F4024)],
    textColor: Colors.white,
    ornate: true,
  ),
  _CardTemplate(
    name: 'Sunset',
    gradient: [Color(0xFFE65100), Color(0xFFBF360C)],
    textColor: Colors.white,
  ),
  _CardTemplate(
    name: 'Berry',
    gradient: [Color(0xFFAD1457), Color(0xFF6A1B9A)],
    textColor: Colors.white,
    ornate: true,
  ),
  _CardTemplate(
    name: 'Slate',
    gradient: [Color(0xFF37474F), Color(0xFF212121)],
    textColor: Colors.white,
  ),
];

const List<String> _kBusinessTypes = [
  'Retailer / Shop',
  'Wholesaler',
  'Distributor',
  'Services',
  'Manufacturer',
  'Other',
];

class BusinessCardScreen extends StatefulWidget {
  const BusinessCardScreen({super.key});

  @override
  State<BusinessCardScreen> createState() => _BusinessCardScreenState();
}

class _BusinessCardScreenState extends State<BusinessCardScreen> {
  final _pageController = PageController(viewportFraction: 0.86);
  final GlobalKey _cardKey = GlobalKey();
  int _templateIndex = 0;
  String? _businessType;
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    _nameCtrl = TextEditingController(text: profile?.businessName ?? '');
    _phoneCtrl = TextEditingController(text: profile?.phone ?? '');
    _addressCtrl = TextEditingController(text: profile?.address ?? '');
    _businessType =
        (profile?.category != null && profile!.category!.isNotEmpty)
            ? profile.category
            : null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadCard() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Could not generate card');
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/business_card_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'My Business Card',
      );
    } catch (e) {
      if (mounted) {
        AppHelpers.showErrorSnackBar(context, 'Failed to generate card');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveDetails() async {
    final auth = context.read<AuthProvider>();
    await auth.updateBusiness({
      'name': _nameCtrl.text.trim(),
      'category': _businessType ?? '',
    });
    await auth.updateProfile({
      'address': _addressCtrl.text.trim(),
    });
    if (!mounted) return;
    AppHelpers.showSuccessSnackBar(context, 'Business card details saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Business Card',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _kCardTemplates.length,
              onPageChanged: (i) => setState(() => _templateIndex = i),
              itemBuilder: (context, i) {
                final template = _kCardTemplates[i];
                final selected = i == _templateIndex;
                final preview = _BusinessCardPreview(
                  template: template,
                  businessName: _nameCtrl.text.trim().isEmpty
                      ? 'Your Business Name'
                      : _nameCtrl.text.trim(),
                  businessType:
                      _businessType ?? 'Select Business Category',
                  phone: _phoneCtrl.text.trim(),
                  address: _addressCtrl.text.trim(),
                );
                return AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                      horizontal: 8, vertical: selected ? 4 : 16),
                  child: selected
                      ? RepaintBoundary(key: _cardKey, child: preview)
                      : preview,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kCardTemplates.length, (i) {
              final active = i == _templateIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 10 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      active ? AppTheme.primaryColor : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Business Name',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Business Name',
                    prefixIcon: Icon(Icons.store_outlined, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                const Text('Select business type',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kBusinessTypes.map((type) {
                    final selected = _businessType == type;
                    return ChoiceChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _businessType = type),
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected
                            ? AppTheme.primaryColor
                            : const Color(0xFF424242),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('Phone Number',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                const Text('Business Address',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Add Business Address',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveDetails,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('SAVE DETAILS',
                        style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _downloadCard,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(_saving ? 'Please wait' : 'DOWNLOAD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessCardPreview extends StatelessWidget {
  final _CardTemplate template;
  final String businessName;
  final String businessType;
  final String phone;
  final String address;

  const _BusinessCardPreview({
    required this.template,
    required this.businessName,
    required this.businessType,
    required this.phone,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: template.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          if (template.ornate)
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.spa_outlined,
                  size: 100,
                  color: template.textColor.withValues(alpha: 0.12)),
            ),
          if (template.ornate)
            Positioned(
              left: -24,
              bottom: -24,
              child: Icon(Icons.spa_outlined,
                  size: 100,
                  color: template.textColor.withValues(alpha: 0.12)),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                businessName,
                style: TextStyle(
                  color: template.textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                businessType,
                style: TextStyle(
                  color: template.textColor.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: template.textColor),
                    const SizedBox(width: 6),
                    Text(phone,
                        style: TextStyle(
                            color: template.textColor, fontSize: 13)),
                  ],
                ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: template.textColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(address,
                          style: TextStyle(
                              color: template.textColor, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}