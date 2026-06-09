// lib/utils/helpers.dart
// FIXED: formatCurrencyCompact embeds ₹ — callers must NOT add ₹ prefix.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppHelpers {
  AppHelpers._();

  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTimeFmt =
      DateFormat('dd MMM yyyy, hh:mm a');

  /// Full currency with paise: ₹1,23,456.00
  static String formatCurrency(double amount) =>
      _currencyFmt.format(amount);

  /// Compact currency — symbol is INSIDE the return value.
  /// Never call this as '₹ ${formatCurrencyCompact(x)}' — that doubles the symbol.
  /// Just call: formatCurrencyCompact(x)
  static String formatCurrencyCompact(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  static String formatDate(DateTime date) => _dateFmt.format(date);

  static String formatDateTime(DateTime date) =>
      _dateTimeFmt.format(date);

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}y ago';
    }
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}mo ago';
    }
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String getInitials(String name) => initials(name);

  static Color getAvatarColor(String name) {
    const colors = [
      Color(0xFF1A6B3C),
      Color(0xFF1565C0),
      Color(0xFFAD1457),
      Color(0xFF6A1B9A),
      Color(0xFFE65100),
      Color(0xFF00695C),
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.hashCode.abs() % colors.length];
  }

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static void showSuccessSnackBar(
      BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: const Color(0xFF00875A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void showErrorSnackBar(
      BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ]),
        backgroundColor: const Color(0xFFDE3618),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}