// lib/widgets/widgets.dart
// ─────────────────────────────────────────────────────────────────────────────
// Shared reusable widgets for GBook app
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';

// ── EmptyState ────────────────────────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle = '',
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 36, color: AppTheme.primaryColor.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── SummaryCard ───────────────────────────────────────────────────────────────
class SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  const SummaryCard({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  AppHelpers.formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
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

// ── TransactionTile ───────────────────────────────────────────────────────────
class TransactionTile extends StatelessWidget {
  final String id;
  final double amount;
  final bool isGiven; // true = given (debit/red), false = received (credit/green)
  final String? note;
  final DateTime date;
  final String paymentMode;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.id,
    required this.amount,
    required this.isGiven,
    this.note,
    required this.date,
    this.paymentMode = 'cash',
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isGiven ? AppTheme.debitColor : AppTheme.creditColor;
    final label = isGiven ? 'Given' : 'Received';
    final icon = isGiven ? Icons.arrow_upward : Icons.arrow_downward;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        note?.isNotEmpty == true ? note! : label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${AppHelpers.formatDate(date)}  •  ${paymentMode.toUpperCase()}',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isGiven ? '-' : '+'} ${AppHelpers.formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _confirmDelete(context),
              child: const Icon(Icons.delete_outline,
                  size: 18, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) onDelete?.call();
  }
}

// ── PaymentModeSelector ───────────────────────────────────────────────────────
class PaymentModeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const PaymentModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _modes = [
    ('cash', Icons.money, 'Cash'),
    ('upi', Icons.qr_code, 'UPI'),
    ('cheque', Icons.receipt_long, 'Cheque'),
    ('bank', Icons.account_balance, 'Bank'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _modes.map((m) {
        final isSelected = selected == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(m.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.$2,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    m.$3,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── AmountBadge ───────────────────────────────────────────────────────────────
class AmountBadge extends StatelessWidget {
  final double amount;
  final bool positive;

  const AmountBadge(
      {super.key, required this.amount, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppTheme.creditColor : AppTheme.debitColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AppHelpers.formatCurrency(amount.abs()),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ── LoadingOverlay ────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay(
      {super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const ColoredBox(
            color: Colors.black26,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}