import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final _api = ApiClient();
  List<dynamic> _subscriptions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.subscriptions);
      setState(() {
        _subscriptions = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppTheme.success;
      case 'paused': return AppTheme.warning;
      case 'cancelled': return AppTheme.error;
      case 'completed': return AppTheme.info;
      default: return AppTheme.textSecondary;
    }
  }

  Future<void> _pauseSubscription(String id) async {
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/pause', data: {'reason': 'User requested'});
      _loadSubscriptions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription paused')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pause'), backgroundColor: AppTheme.error));
      }
    }
  }

  Future<void> _resumeSubscription(String id) async {
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/resume');
      _loadSubscriptions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription resumed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resume'), backgroundColor: AppTheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {}, // Show past subscriptions
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _subscriptions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadSubscriptions,
                  color: AppTheme.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _subscriptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final sub = _subscriptions[index];
                      final status = sub['status'] ?? 'unknown';
                      final color = _getStatusColor(status);
                      
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      sub['product']?['name'] ?? 'Healthy Meal Plan',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.date_range, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Start: ${sub['start_date'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(sub['start_date'])) : 'TBD'}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.local_shipping_outlined, size: 16, color: AppTheme.textSecondary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Deliveries: ${sub['deliveries_completed'] ?? 0} / ${sub['total_deliveries'] ?? 0}',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => context.push('/delivery-calendar/${sub['id']}'),
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 40),
                                      ),
                                      child: const Text('Calendar'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: status == 'active' 
                                          ? () => _pauseSubscription(sub['id'])
                                          : status == 'paused'
                                              ? () => _resumeSubscription(sub['id'])
                                              : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: status == 'active' ? AppTheme.warning : AppTheme.primaryGreen,
                                        minimumSize: const Size(0, 40),
                                      ),
                                      child: Text(status == 'active' ? 'Pause' : 'Resume'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('No active plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Subscribe to a healthy meal plan today!', style: TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Explore Plans'),
          ),
        ],
      ),
    );
  }
}
