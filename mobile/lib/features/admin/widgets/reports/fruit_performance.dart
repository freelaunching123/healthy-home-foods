import 'package:flutter/material.dart';

import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'empty_state.dart';

class FruitPerformance extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const FruitPerformance({super.key, this.startDate, this.endDate});

  @override
  State<FruitPerformance> createState() => _FruitPerformanceState();
}

class _FruitPerformanceState extends State<FruitPerformance> {
  final _api = ApiClient();
  bool _isLoading = true;
  List<dynamic> _topSelling = [];
  List<dynamic> _leastSelling = [];

  final List<Color> _colors = [
    Colors.orange, Colors.red, Colors.green, Colors.purple, Colors.blue
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant FruitPerformance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/reports/fruits', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _topSelling = res.data['top_selling'] ?? [];
          _leastSelling = res.data['least_selling'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching fruits: $e');
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

    if (_topSelling.isEmpty) {
      return const EmptyState(
        icon: Icons.apple,
        message: 'No fruit performance data available.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildList('Top Selling Fruits', _topSelling, true),
        const SizedBox(height: 16),
        _buildList('Least Selling Fruits', _leastSelling, false),
      ],
    );
  }
  Widget _buildList(String title, List<dynamic> items, bool isTop) {
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
            Row(
              children: [
                Icon(isTop ? Icons.trending_up : Icons.trending_down, color: isTop ? AppTheme.success : AppTheme.error),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((fruit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(fruit['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: Text('${fruit['quantity'] ?? 0} kg', style: const TextStyle(color: Colors.grey)),
                    ),
                    Expanded(
                      child: Text(formatCurrency.format(fruit['revenue'] ?? 0), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
