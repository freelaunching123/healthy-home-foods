import 'package:flutter/material.dart';
import '../../../../core/services/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import 'empty_state.dart';

class DeliveryAnalytics extends StatefulWidget {
  final String? startDate;
  final String? endDate;

  const DeliveryAnalytics({super.key, this.startDate, this.endDate});

  @override
  State<DeliveryAnalytics> createState() => _DeliveryAnalyticsState();
}

class _DeliveryAnalyticsState extends State<DeliveryAnalytics> {
  final _api = ApiClient();
  bool _isLoading = true;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didUpdateWidget(covariant DeliveryAnalytics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startDate != widget.startDate || oldWidget.endDate != widget.endDate) {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/reports/deliveries', queryParameters: {
        if (widget.startDate != null) 'start_date': widget.startDate,
        if (widget.endDate != null) 'end_date': widget.endDate,
      });
      if (mounted) {
        setState(() {
          _data = res.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching deliveries: $e');
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
        icon: Icons.local_shipping,
        message: 'No delivery statistics available.',
      );
    }

    final stats = _data!['status_breakdown'] as Map;
    final delivered = stats['delivered'] ?? 0;
    final pending = stats['pending'] ?? 0;
    final failed = (stats['failed'] ?? 0) + (stats['missed'] ?? 0);
    final assigned = stats['assigned'] ?? 0;
    final out = stats['out_for_delivery'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildChip('Completed', delivered, AppTheme.success),
                _buildChip('Pending', pending, AppTheme.warning),
                _buildChip('Assigned', assigned, AppTheme.primaryGreen),
                _buildChip('Out for Delivery', out, AppTheme.primaryBlue),
                _buildChip('Failed', failed, AppTheme.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
