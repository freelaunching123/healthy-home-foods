import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class OverviewCards extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const OverviewCards({super.key, this.startDate, this.endDate});

  @override
  State<OverviewCards> createState() => _OverviewCardsState();
}

class _OverviewCardsState extends State<OverviewCards> {
  final _api = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant OverviewCards oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/reports/overview', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() => _data = res.data);
      }
    } catch (e) {
      debugPrint('Error fetching overview: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ));
    }

    if (_data == null) {
      return const Center(child: Text('Failed to load overview'));
    }

    final formatCurrency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildCard('Total Revenue', formatCurrency.format(_data!['total_revenue'] ?? 0), Icons.currency_rupee, Colors.green),
        _buildCard('Total Orders', '${_data!['total_orders'] ?? 0}', Icons.shopping_cart, Colors.blue),
        _buildCard('Total Customers', '${_data!['total_customers'] ?? 0}', Icons.people, Colors.purple),
        _buildCard('Avg Order Value', formatCurrency.format(_data!['avg_order_value'] ?? 0), Icons.analytics, Colors.orange),
        _buildCard('Total Deliveries', '${_data!['total_deliveries'] ?? 0}', Icons.local_shipping, Colors.teal),
        _buildCard('Pending Deliveries', '${_data!['pending_deliveries'] ?? 0}', Icons.schedule, Colors.redAccent),
        _buildCard('Cancelled Orders', '${_data!['cancelled_orders'] ?? 0}', Icons.cancel, Colors.grey),
        _buildCard('Active Subs', '${_data!['active_subscriptions'] ?? 0}', Icons.card_giftcard, AppTheme.primaryGreen),
      ],
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
