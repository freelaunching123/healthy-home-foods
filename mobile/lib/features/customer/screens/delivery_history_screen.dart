import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class CustomerDeliveryHistoryScreen extends StatefulWidget {
  const CustomerDeliveryHistoryScreen({super.key});

  @override
  State<CustomerDeliveryHistoryScreen> createState() => _CustomerDeliveryHistoryScreenState();
}

class _CustomerDeliveryHistoryScreenState extends State<CustomerDeliveryHistoryScreen> {
  final _api = ApiClient();
  List<dynamic> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveryHistory();
  }

  Future<void> _loadDeliveryHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.deliveryHistory);
      setState(() {
        _deliveries = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading delivery history: $e');
      setState(() {
        _deliveries = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return AppTheme.success;
      case 'pending':
      case 'assigned':
      case 'out_for_delivery': return Colors.blue;
      case 'missed': return AppTheme.error;
      case 'skipped': return AppTheme.warning;
      case 'carry_forward': return Colors.purple;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered': return Icons.check_circle_outline;
      case 'pending':
      case 'assigned':
      case 'out_for_delivery': return Icons.local_shipping_outlined;
      case 'missed': return Icons.cancel_outlined;
      case 'skipped': return Icons.pause_circle_outline;
      case 'carry_forward': return Icons.next_plan_outlined;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _deliveries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDeliveryHistory,
                  color: AppTheme.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _deliveries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _deliveries[index];
                      final status = item['status'] ?? 'pending';
                      final color = _getStatusColor(status);
                      final icon = _getStatusIcon(status);
                      
                      final scheduledDate = item['delivery_date'] != null
                          ? DateFormat('EEEE, MMM dd, yyyy').format(DateTime.parse(item['delivery_date']))
                          : 'TBD';

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.1),
                            child: Icon(icon, color: color, size: 24),
                          ),
                          title: Text(
                            item['product_name'] ?? 'Healthy Meal Plan',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              scheduledDate,
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No Deliveries Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your delivery logs will appear here once your subscription starts delivering.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
