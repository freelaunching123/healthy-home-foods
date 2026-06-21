import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _activeDeliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await _api.get(ApiConstants.partnerDashboard);
      final activeRes = await _api.get(ApiConstants.partnerActiveDeliveries);
      
      setState(() {
        _stats = statsRes.data;
        _activeDeliveries = activeRes.data is List ? activeRes.data : [];
      });
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Today\'s Performance', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Active Deliveries', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () => context.push('/delivery/active'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildActiveDeliveriesList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    if (_stats == null) return const SizedBox.shrink();
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('Assigned Today', _stats!['assigned_today']?.toString() ?? '0', Icons.assignment, Colors.blue),
        _buildStatCard('Completed', _stats!['completed_today']?.toString() ?? '0', Icons.check_circle, Colors.green),
        _buildStatCard('Pending', _stats!['pending_deliveries']?.toString() ?? '0', Icons.pending_actions, Colors.orange),
        _buildStatCard('Success Rate', '${(_stats!['success_rate'] as num?)?.toStringAsFixed(1) ?? '0'}%', Icons.trending_up, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Spacer(),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveDeliveriesList() {
    if (_activeDeliveries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No active deliveries right now', style: TextStyle(color: Colors.grey)),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeDeliveries.length > 3 ? 3 : _activeDeliveries.length, // Show up to 3
      itemBuilder: (context, index) {
        final delivery = _activeDeliveries[index];
        final orderType = delivery['order_type'] == 'fruit' ? 'Fruit Order' : 'Subscription';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text('${delivery['customer_name']} ($orderType)'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(delivery['delivery_address'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (delivery['status'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/delivery/active'),
          ),
        );
      },
    );
  }
}
