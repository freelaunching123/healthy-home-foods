import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ProductAnalyticsScreen extends StatefulWidget {
  const ProductAnalyticsScreen({super.key});

  @override
  State<ProductAnalyticsScreen> createState() => _ProductAnalyticsScreenState();
}

class _ProductAnalyticsScreenState extends State<ProductAnalyticsScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/api/v1/products/analytics/dashboard');
      setState(() => _analytics = res.data);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Product Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              color: AppTheme.primaryGreen,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatRow(),
                  const SizedBox(height: 24),
                  // Placeholders for Most/Least Ordered since complex joins are planned for a later phase
                  const Text('Most Ordered Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Data collection in progress...', style: TextStyle(color: AppTheme.textSecondary))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Least Ordered Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Data collection in progress...', style: TextStyle(color: AppTheme.textSecondary))),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total',
            value: _analytics?['total_products']?.toString() ?? '0',
            icon: Icons.inventory_2_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Active',
            value: _analytics?['active_products']?.toString() ?? '0',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Inactive',
            value: _analytics?['inactive_products']?.toString() ?? '0',
            icon: Icons.hide_source_outlined,
            color: Colors.red,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
