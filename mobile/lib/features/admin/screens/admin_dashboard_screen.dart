import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _loadOverview();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(ApiConstants.adminOverview);
      setState(() => _data = res.data as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = e.toString());
      debugPrint('Error loading admin overview: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOverview,
          color: AppTheme.primaryGreen,
          strokeWidth: 2.5,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(today),
              ),

              if (_isLoading) ...[
                SliverToBoxAdapter(child: _buildShimmer()),
              ] else if (_error != null) ...[
                SliverFillRemaining(
                  child: _buildError(),
                ),
              ] else ...[
                // ── Summary Cards ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionLabel('Summary'),
                ),
                SliverToBoxAdapter(
                  child: _buildSummaryCards(),
                ),

                // ── Quick Insights ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionLabel('Quick Insights'),
                ),
                SliverToBoxAdapter(
                  child: _buildQuickInsights(),
                ),

                // ── Revenue Chart ────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionLabel('Revenue — Last 7 Days'),
                ),
                SliverToBoxAdapter(
                  child: _buildRevenueChart(),
                ),

                // ── Recent Activity ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: _buildSectionLabel('Recent Activity'),
                ),
                SliverToBoxAdapter(
                  child: _buildRecentActivity(),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String today) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  today,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            color: AppTheme.textSecondary,
            onPressed: () => context.push('/admin/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── Summary Cards ──────────────────────────────────────────────────────────

  Widget _buildSummaryCards() {
    final summary = (_data?['summary'] as Map<String, dynamic>?) ?? {};
    final todaysRevenue = (summary['todays_revenue'] as num?)?.toDouble() ?? 0.0;
    final ordersToday = (summary['orders_today'] as num?)?.toInt() ?? 0;
    final activeSubscribers = (summary['active_subscribers'] as num?)?.toInt() ?? 0;
    final pendingDeliveries = (summary['pending_deliveries'] as num?)?.toInt() ?? 0;

    final cards = [
      _SummaryCardData(
        title: "Today's Revenue",
        value: '₹${_formatRevenue(todaysRevenue)}',
        icon: Icons.currency_rupee_rounded,
        color: AppTheme.primaryGreen,
        bgColor: const Color(0xFFE8F5E9),
      ),
      _SummaryCardData(
        title: 'Orders Today',
        value: '$ordersToday',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.info,
        bgColor: const Color(0xFFE3F2FD),
      ),
      _SummaryCardData(
        title: 'Active Subscribers',
        value: '$activeSubscribers',
        icon: Icons.card_membership_rounded,
        color: AppTheme.success,
        bgColor: const Color(0xFFE8F5E9),
      ),
      _SummaryCardData(
        title: 'Pending Deliveries',
        value: '$pendingDeliveries',
        icon: Icons.local_shipping_rounded,
        color: AppTheme.warning,
        bgColor: const Color(0xFFFFF8E1),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards.map((c) => _SummaryCard(data: c)).toList(),
      ),
    );
  }

  // ── Quick Insights ─────────────────────────────────────────────────────────

  Widget _buildQuickInsights() {
    final insights = (_data?['quick_insights'] as Map<String, dynamic>?) ?? {};
    final topPackage = insights['top_selling_package'] as Map<String, dynamic>?;
    final topFruit = insights['most_ordered_fruit'] as Map<String, dynamic>?;
    final lowStockList = (insights['low_stock_alerts'] as List<dynamic>?) ?? [];
    
    final firstLowStock = lowStockList.isNotEmpty ? lowStockList.first as Map<String, dynamic> : null;
    String? lowStockSubtitle;
    if (firstLowStock != null) {
      final status = firstLowStock['status'] as String? ?? '';
      lowStockSubtitle = status == 'out_of_stock' ? 'Out of stock' : 'Low stock';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _InsightCard(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFF59E0B),
              iconBg: const Color(0xFFFFF8E1),
              title: 'Top Package',
              name: topPackage != null ? (topPackage['name'] as String?) ?? '—' : null,
              subtitle: topPackage != null
                  ? '${topPackage['count']} Orders'
                  : null,
              emptyText: 'No package sales yet',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InsightCard(
              icon: Icons.local_grocery_store_rounded,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFE8F5E9),
              title: 'Top Fruit',
              name: topFruit != null ? (topFruit['name'] as String?) ?? '—' : null,
              subtitle: topFruit != null
                  ? '${topFruit['count']} Orders'
                  : null,
              emptyText: 'No fruit orders yet',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _InsightCard(
              icon: Icons.warning_amber_rounded,
              iconColor: AppTheme.error,
              iconBg: const Color(0xFFFEE2E2),
              title: 'Low Stock',
              name: firstLowStock != null ? (firstLowStock['name'] as String?) ?? '—' : null,
              subtitle: lowStockSubtitle,
              emptyText: 'No low stock alerts',
            ),
          ),
        ],
      ),
    );
  }

  // ── Revenue Chart ──────────────────────────────────────────────────────────

  Widget _buildRevenueChart() {
    final chartData = (_data?['revenue_chart'] as List<dynamic>?) ?? [];
    final revenues = chartData
        .map((e) => ((e as Map<String, dynamic>)['revenue'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final dates = chartData
        .map((e) => (e as Map<String, dynamic>)['date'] as String? ?? '')
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Revenue Trend',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '7 Days',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: _RevenueBarChart(revenues: revenues, dates: dates),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Activity ────────────────────────────────────────────────────────

  Widget _buildRecentActivity() {
    final activities = (_data?['recent_activity'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: activities.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, size: 36, color: AppTheme.textLight),
                    SizedBox(height: 8),
                    Text(
                      'No recent activity.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey.shade100,
                indent: 60,
              ),
              itemBuilder: (context, i) {
                final a = activities[i] as Map<String, dynamic>;
                return _ActivityTile(activity: a);
              },
            ),
    );
  }

  // ── Shimmer Skeleton ───────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerColor = ColorTween(
          begin: Colors.grey.shade200,
          end: Colors.grey.shade100,
        ).animate(CurvedAnimation(
          parent: _shimmerController,
          curve: Curves.easeInOut,
        ));
        final color = shimmerColor.value ?? Colors.grey.shade200;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Summary grid skeleton
              _shimmerBox(color, double.infinity, 14, radius: 6),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: List.generate(4, (_) => _shimmerBox(color, double.infinity, double.infinity)),
              ),
              const SizedBox(height: 20),
              // Insights skeleton
              _shimmerBox(color, double.infinity, 14, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                      child: _shimmerBox(color, double.infinity, 100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Chart skeleton
              _shimmerBox(color, double.infinity, 14, radius: 6),
              const SizedBox(height: 12),
              _shimmerBox(color, double.infinity, 180),
              const SizedBox(height: 20),
              // Actions skeleton
              _shimmerBox(color, double.infinity, 14, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
                      child: _shimmerBox(color, double.infinity, 68),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _shimmerBox(color, double.infinity, 14, radius: 6),
              const SizedBox(height: 12),
              _shimmerBox(color, double.infinity, 220),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(Color color, double width, double height, {double radius = 12}) {
    return Container(
      width: width == double.infinity ? null : width,
      height: height == double.infinity ? null : height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Error State ────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppTheme.error, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pull down to refresh',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadOverview,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 44),
                backgroundColor: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _formatRevenue(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final _SummaryCardData data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(data.icon, color: data.color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: data.color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight Card
// ─────────────────────────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? name;
  final String? subtitle;
  final String emptyText;

  const _InsightCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.name,
    required this.subtitle,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = name != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasData)
            Text(
              emptyText,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textLight,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            Text(
              name!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Revenue Bar Chart
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final List<double> revenues;
  final List<String> dates;

  const _RevenueBarChart({required this.revenues, required this.dates});

  @override
  Widget build(BuildContext context) {
    if (revenues.isEmpty) {
      return const Center(
        child: Text(
          'No revenue data',
          style: TextStyle(color: AppTheme.textLight, fontSize: 13),
        ),
      );
    }

    final maxVal = revenues.reduce(math.max);
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(revenues.length, (i) {
        final rev = revenues[i];
        final ratio = rev / effectiveMax;
        final dayLabel = dates.length > i
            ? DateFormat('E').format(DateTime.parse(dates[i]))
            : '—';
        final isToday = i == revenues.length - 1;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (rev > 0)
                  Text(
                    _shortRev(rev),
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: isToday ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    ),
                  ),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  height: math.max(ratio * 100, rev > 0 ? 4.0 : 2.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isToday
                          ? [AppTheme.primaryGreen, AppTheme.primaryLight]
                          : [
                              AppTheme.primaryGreen.withValues(alpha: 0.4),
                              AppTheme.primaryGreen.withValues(alpha: 0.2),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _shortRev(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity Tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    final type = activity['type'] as String? ?? '';
    final description = activity['description'] as String? ?? '';
    final timestampStr = activity['timestamp'] as String?;

    DateTime? ts;
    if (timestampStr != null) {
      try {
        ts = DateTime.parse(timestampStr).toLocal();
      } catch (_) {}
    }

    final config = _activityConfig(type);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: config.bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(config.icon, color: config.color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (ts != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _relativeTime(ts),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ActivityIconConfig _activityConfig(String type) {
    switch (type) {
      case 'new_customer':
        return _ActivityIconConfig(
          icon: Icons.person_add_rounded,
          color: AppTheme.info,
          bg: const Color(0xFFE3F2FD),
        );
      case 'new_subscription':
        return _ActivityIconConfig(
          icon: Icons.card_membership_rounded,
          color: AppTheme.primaryGreen,
          bg: const Color(0xFFE8F5E9),
        );
      case 'delivery_completed':
        return _ActivityIconConfig(
          icon: Icons.check_circle_rounded,
          color: AppTheme.success,
          bg: const Color(0xFFD1FAE5),
        );
      case 'product_added':
        return _ActivityIconConfig(
          icon: Icons.inventory_2_rounded,
          color: const Color(0xFF8B5CF6),
          bg: const Color(0xFFF3E8FF),
        );
      case 'payment_received':
        return _ActivityIconConfig(
          icon: Icons.currency_rupee_rounded,
          color: AppTheme.warning,
          bg: const Color(0xFFFFF8E1),
        );
      default:
        return _ActivityIconConfig(
          icon: Icons.circle_notifications_rounded,
          color: AppTheme.textSecondary,
          bg: Colors.grey.shade100,
        );
    }
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _ActivityIconConfig {
  final IconData icon;
  final Color color;
  final Color bg;
  const _ActivityIconConfig({required this.icon, required this.color, required this.bg});
}
