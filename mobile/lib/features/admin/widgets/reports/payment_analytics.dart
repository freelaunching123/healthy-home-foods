import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'empty_state.dart';

class PaymentAnalytics extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const PaymentAnalytics({super.key, this.startDate, this.endDate});

  @override
  State<PaymentAnalytics> createState() => _PaymentAnalyticsState();
}

class _PaymentAnalyticsState extends State<PaymentAnalytics> {
  final _api = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant PaymentAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/reports/payments', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _data = res.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching payments: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_data == null || (_data!['status_breakdown'] as Map).isEmpty) {
      return const EmptyState(
        icon: Icons.payments,
        message: 'No payment statistics available.',
      );
    }

    final stats = _data!['status_breakdown'] as Map;
    final formatCurrency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payments by Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...stats.entries.map((e) {
              final statusStr = e.key.toString().toUpperCase();
              final count = e.value['count'] ?? 0;
              final amount = e.value['amount'] ?? 0;
              Color color = Colors.grey;
              if (statusStr == 'SUCCESS') color = AppTheme.success;
              if (statusStr == 'PENDING') color = AppTheme.warning;
              if (statusStr == 'FAILED') color = AppTheme.error;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text('$statusStr ($count)')),
                    Text(formatCurrency.format(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
