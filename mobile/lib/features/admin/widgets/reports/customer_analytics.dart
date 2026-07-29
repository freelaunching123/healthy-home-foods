import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'empty_state.dart';

class CustomerAnalytics extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const CustomerAnalytics({super.key, this.startDate, this.endDate});

  @override
  State<CustomerAnalytics> createState() => _CustomerAnalyticsState();
}

class _CustomerAnalyticsState extends State<CustomerAnalytics> {
  final _api = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant CustomerAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/reports/customers', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _data = res.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');
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

    if (_data == null) {
      return const EmptyState(
        icon: Icons.people,
        message: 'No customer activity found.',
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem('Total Customers', '${_data!['total'] ?? 0}', Colors.purple),
                _buildStatItem('New (Period)', '${_data!['new'] ?? 0}', AppTheme.primaryGreen),
                _buildStatItem('Active', '${_data!['active'] ?? 0}', AppTheme.primaryBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
