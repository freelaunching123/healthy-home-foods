import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class MySubscriptionDetailScreen extends StatefulWidget {
  const MySubscriptionDetailScreen({super.key});

  @override
  State<MySubscriptionDetailScreen> createState() => _MySubscriptionDetailScreenState();
}

class _MySubscriptionDetailScreenState extends State<MySubscriptionDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _subscription;
  bool _isLoading = true;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSubscription();
  }

  Future<void> _loadCurrentSubscription() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.subscriptionCurrent);
      setState(() {
        _subscription = res.data;
      });
    } catch (e) {
      debugPrint('Error loading current subscription: $e');
      setState(() {
        _subscription = null;
      });
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

  Future<void> _pauseSubscription() async {
    final id = _subscription?['id'];
    if (id == null) return;

    final confirm = await _showConfirmDialog(
      title: 'Pause Subscription',
      content: 'Are you sure you want to pause your meal subscription? You will not receive deliveries while paused.',
      confirmLabel: 'Pause',
      confirmColor: AppTheme.warning,
    );
    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/pause', data: {'reason': 'User requested'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription paused'), backgroundColor: AppTheme.success));
      _loadCurrentSubscription();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pause subscription'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _resumeSubscription() async {
    final id = _subscription?['id'];
    if (id == null) return;

    setState(() => _isActionInProgress = true);
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/resume');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription resumed'), backgroundColor: AppTheme.success));
      _loadCurrentSubscription();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to resume subscription'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final id = _subscription?['id'];
    if (id == null) return;

    final confirm = await _showConfirmDialog(
      title: 'Cancel Subscription',
      content: 'Are you sure you want to cancel your subscription? This action cannot be undone and remaining deliveries will be cancelled.',
      confirmLabel: 'Cancel Subscription',
      confirmColor: AppTheme.error,
    );
    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/cancel', data: {'reason': 'User requested'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription cancelled'), backgroundColor: AppTheme.success));
      _loadCurrentSubscription();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel subscription'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor, foregroundColor: Colors.white),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Subscription'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _subscription == null
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCurrentSubscription,
                  color: AppTheme.primaryGreen,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subscription Main Card
                        _buildMainSubscriptionCard(),
                        const SizedBox(height: 24),

                        // Stats Grid
                        const Text(
                          'Delivery Statistics',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 12),
                        _buildStatsGrid(),
                        const SizedBox(height: 32),

                        // Action Buttons
                        if (_isActionInProgress)
                          const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                        else
                          _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMainSubscriptionCard() {
    final status = _subscription?['status'] ?? 'unknown';
    final statusColor = _getStatusColor(status);
    final startDateStr = _subscription?['start_date'] != null
        ? DateFormat('MMMM dd, yyyy').format(DateTime.parse(_subscription!['start_date']))
        : 'TBD';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _subscription?['product_name'] ?? 'Meal Plan',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_subscription?['plan_name']} (${_subscription?['plan_type']?.toUpperCase()})',
              style: const TextStyle(fontSize: 15, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24, thickness: 1),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Started on: $startDateStr',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.currency_rupee, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Total Amount: ₹${_subscription?['total_amount']}',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final total = _subscription?['total_deliveries'] ?? 0;
    final completed = _subscription?['completed_deliveries'] ?? 0;
    final remaining = _subscription?['remaining_deliveries'] ?? 0;
    final paused = _subscription?['paused_days'] ?? 0;
    final missed = _subscription?['missed_deliveries'] ?? 0;
    final carryForward = _subscription?['carry_forward_deliveries'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Total Deliveries', total.toString(), Icons.shopping_basket_outlined, AppTheme.primaryGreen),
        _buildStatCard('Completed', completed.toString(), Icons.check_circle_outline, AppTheme.success),
        _buildStatCard('Remaining', remaining.toString(), Icons.hourglass_empty_outlined, Colors.blue),
        _buildStatCard('Paused Days', paused.toString(), Icons.pause_circle_outline, AppTheme.warning),
        _buildStatCard('Missed Deliveries', missed.toString(), Icons.cancel_outlined, AppTheme.error),
        _buildStatCard('Carry Forward', carryForward.toString(), Icons.forward_to_inbox_outlined, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final status = (_subscription?['status'] ?? '').toLowerCase();
    if (status != 'active' && status != 'paused') return const SizedBox.shrink();

    return Column(
      children: [
        if (status == 'active')
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pauseSubscription,
              icon: const Icon(Icons.pause, color: Colors.white),
              label: const Text('Pause Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        if (status == 'paused')
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _resumeSubscription,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text('Resume Subscription', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _cancelSubscription,
            icon: const Icon(Icons.cancel, color: AppTheme.error),
            label: const Text('Cancel Subscription', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No Active Subscription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'You do not have any active subscriptions. Explore our healthy meal plans and subscribe today!',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Browse Meal Plans', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
