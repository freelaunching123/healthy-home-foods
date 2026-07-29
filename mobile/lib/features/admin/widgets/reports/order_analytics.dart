import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'empty_state.dart';

class OrderAnalytics extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const OrderAnalytics({super.key, this.startDate, this.endDate});

  @override
  State<OrderAnalytics> createState() => _OrderAnalyticsState();
}

class _OrderAnalyticsState extends State<OrderAnalytics> {
  final _api = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant OrderAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/reports/orders', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _data = res.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
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
        height: 200,
        child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_data == null) {
      return const EmptyState(
        icon: Icons.receipt_long,
        message: 'No order statistics available.',
      );
    }

    final subStats = _data!['subscription_status'] as Map;
    final fruitStats = _data!['fruit_order_status'] as Map;

    return Column(
      children: [
        _buildStatCard('Subscriptions', subStats, Icons.card_giftcard),
        const SizedBox(height: 16),
        _buildStatCard('Fruit Orders', fruitStats, Icons.apple),
      ],
    );
  }

  Widget _buildStatCard(String title, Map stats, IconData icon) {
    if (stats.isEmpty) return const SizedBox.shrink();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...stats.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.toString().replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
                    Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
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
