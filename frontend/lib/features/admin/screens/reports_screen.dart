import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_drawer.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _api = ApiClient();
  
  String _selectedFilter = 'This Month';
  String? _startDate;
  String? _endDate;

  bool _isLoading = true;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;
  String? _error;

  Map<String, dynamic>? _overviewData;
  Map<String, dynamic>? _salesData;
  Map<String, dynamic>? _packagesData;
  Map<String, dynamic>? _fruitsData;
  Map<String, dynamic>? _ordersData;
  Map<String, dynamic>? _deliveriesData;

  @override
  void initState() {
    super.initState();
    _applyFilter('This Month');
  }

  void _applyFilter(String filter) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (filter) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        end = now;
        break;
      case 'Last 7 Days':
        start = now.subtract(const Duration(days: 7));
        end = now;
        break;
      case 'This Month':
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case 'All Time':
        start = DateTime(2020, 1, 1);
        end = now;
        break;
      case 'Custom':
        _showDateRangePicker();
        return;
    }

    setState(() {
      _selectedFilter = filter;
      _startDate = start != null ? DateFormat('yyyy-MM-dd').format(start) : null;
      _endDate = end != null ? DateFormat('yyyy-MM-dd').format(end) : null;
    });
    _loadData();
  }

  Future<void> _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryGreen,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedFilter = 'Custom';
        _startDate = DateFormat('yyyy-MM-dd').format(picked.start);
        _endDate = DateFormat('yyyy-MM-dd').format(picked.end);
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final queryParams = <String, dynamic>{};
      if (_startDate != null) queryParams['start_date'] = _startDate;
      if (_endDate != null) queryParams['end_date'] = _endDate;

      final results = await Future.wait([
        _api.get('${ApiConstants.reports}/overview', queryParameters: queryParams),
        _api.get('${ApiConstants.reports}/sales', queryParameters: queryParams),
        _api.get('${ApiConstants.reports}/packages', queryParameters: queryParams),
        _api.get('${ApiConstants.reports}/fruits', queryParameters: queryParams),
        _api.get('${ApiConstants.reports}/orders', queryParameters: queryParams),
        _api.get('${ApiConstants.reports}/deliveries', queryParameters: queryParams),
      ]);

      if (mounted) {
        setState(() {
          _overviewData = results[0].data as Map<String, dynamic>;
          _salesData = results[1].data as Map<String, dynamic>;
          _packagesData = results[2].data as Map<String, dynamic>;
          _fruitsData = results[3].data as Map<String, dynamic>;
          _ordersData = results[4].data as Map<String, dynamic>;
          _deliveriesData = results[5].data as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(2)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Analytics & Reports',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: PopupMenuButton<String>(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.primaryGreen, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    _selectedFilter,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen, size: 18),
                ],
              ),
              tooltip: 'Change Timeframe',
              onSelected: _applyFilter,
              itemBuilder: (context) => [
                'Today',
                'Last 7 Days',
                'This Month',
                'All Time',
                'Custom',
              ].map((e) => PopupMenuItem(
                value: e,
                child: Row(
                  children: [
                    Icon(
                      _selectedFilter == e ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 16,
                      color: _selectedFilter == e ? AppTheme.primaryGreen : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Text(e, style: GoogleFonts.inter(fontWeight: _selectedFilter == e ? FontWeight.w700 : FontWeight.w500)),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(height: 16),
            Text('Generating comprehensive reports...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load report data',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'There was an issue fetching report metrics. Please check your connection and retry.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final totalRevenue = (_overviewData?['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (_overviewData?['total_orders'] as num?)?.toInt() ?? 0;

    if (totalRevenue == 0 && totalOrders == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics_outlined, size: 54, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              'No report data for "$_selectedFilter"',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing the date filter to "All Time" or "This Month".',
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _applyFilter('All Time'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('View All Time Data', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroHeader(),
          const SizedBox(height: 16),
          _buildBusinessSummaryGrid(),
          const SizedBox(height: 16),
          _buildSalesDistribution(),
          const SizedBox(height: 16),
          _buildTopItems('Top 5 Groceries', _fruitsData?['top_selling'] as List?, isFruit: true),
          const SizedBox(height: 16),
          _buildTopItems('Top 5 Packages', _packagesData?['top_selling'] as List?, isFruit: false),
          const SizedBox(height: 16),
          _buildOrderStatusSummary(),
          const SizedBox(height: 16),
          _buildBusinessHighlights(),
          const SizedBox(height: 24),
          _buildExportCard(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final totalRev = (_overviewData?['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = (_overviewData?['total_orders'] as num?)?.toInt() ?? 0;
    final avgOrder = (_overviewData?['avg_order_value'] as num?)?.toDouble() ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5C3A), Color(0xFF1E8E5A), Color(0xFF2CB67D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E8E5A).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insights_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _selectedFilter.toUpperCase(),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              Text(
                'Healthy Home Foods',
                style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total Revenue',
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${totalRev.toStringAsFixed(2)}',
            style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeroStat('Total Orders', totalOrders.toString(), Icons.shopping_bag_outlined),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                _buildHeroStat('Avg Value', _formatCurrency(avgOrder), Icons.receipt_long_outlined),
                Container(height: 24, width: 1, color: Colors.white.withValues(alpha: 0.2)),
                _buildHeroStat('Deliveries', '${_overviewData?['total_deliveries'] ?? 0}', Icons.local_shipping_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(label, style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildBusinessSummaryGrid() {
    final fruitRev = (_overviewData?['fruit_revenue'] as num?)?.toDouble() ?? 0.0;
    final pkgRev = (_overviewData?['package_revenue'] as num?)?.toDouble() ?? 0.0;
    final fruitOrd = (_overviewData?['fruit_orders_count'] as num?)?.toInt() ?? 0;
    final pkgOrd = (_overviewData?['package_orders_count'] as num?)?.toInt() ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _buildVibrantCard(
          title: 'Grocery Revenue',
          value: '₹${fruitRev.toStringAsFixed(0)}',
          subtitle: '$fruitOrd orders placed',
          icon: Icons.shopping_basket_rounded,
          gradient: const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          accentColor: const Color(0xFFEA580C),
          borderColor: const Color(0xFFFED7AA),
        ),
        _buildVibrantCard(
          title: 'Package Revenue',
          value: '₹${pkgRev.toStringAsFixed(0)}',
          subtitle: '$pkgOrd subscriptions',
          icon: Icons.inventory_2_rounded,
          gradient: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
          accentColor: const Color(0xFF9333EA),
          borderColor: const Color(0xFFE9D5FF),
        ),
        _buildVibrantCard(
          title: 'Active Subscribers',
          value: '${_overviewData?['active_subscriptions'] ?? 0}',
          subtitle: 'Ongoing plans',
          icon: Icons.card_membership_rounded,
          gradient: const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          accentColor: const Color(0xFF2563EB),
          borderColor: const Color(0xFFBFDBFE),
        ),
        _buildVibrantCard(
          title: 'Pending Deliveries',
          value: '${_overviewData?['pending_deliveries'] ?? 0}',
          subtitle: 'Scheduled ahead',
          icon: Icons.schedule_rounded,
          gradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
          accentColor: const Color(0xFF059669),
          borderColor: const Color(0xFFA7F3D0),
        ),
      ],
    );
  }

  Widget _buildVibrantCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Color accentColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: accentColor.withValues(alpha: 0.15), blurRadius: 4),
                  ],
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: accentColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSalesDistribution() {
    final fruitRev = (_overviewData?['fruit_revenue'] as num?)?.toDouble() ?? 0.0;
    final pkgRev = (_overviewData?['package_revenue'] as num?)?.toDouble() ?? 0.0;
    final total = fruitRev + pkgRev;
    if (total == 0) return const SizedBox.shrink();

    final fruitPct = (fruitRev / total * 100);
    final pkgPct = (pkgRev / total * 100);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Revenue Breakdown',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Text('By Stream', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                height: 110,
                width: 110,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 28,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFFEA580C),
                        value: fruitPct,
                        title: fruitPct >= 10 ? '${fruitPct.toStringAsFixed(0)}%' : '',
                        radius: 26,
                        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF9333EA),
                        value: pkgPct,
                        title: pkgPct >= 10 ? '${pkgPct.toStringAsFixed(0)}%' : '',
                        radius: 26,
                        titleStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStreamLegendItem(
                      color: const Color(0xFFEA580C),
                      title: 'Groceries',
                      amount: '₹${fruitRev.toStringAsFixed(0)}',
                      percent: '${fruitPct.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 12),
                    _buildStreamLegendItem(
                      color: const Color(0xFF9333EA),
                      title: 'Packages',
                      amount: '₹${pkgRev.toStringAsFixed(0)}',
                      percent: '${pkgPct.toStringAsFixed(1)}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreamLegendItem({
    required Color color,
    required String title,
    required String amount,
    required String percent,
  }) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
              Text(amount, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(percent, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      ],
    );
  }

  Widget _buildTopItems(String title, List<dynamic>? items, {required bool isFruit}) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    final rankColors = [
      const Color(0xFFF59E0B), // Gold
      const Color(0xFF64748B), // Silver
      const Color(0xFFB45309), // Bronze
      const Color(0xFF94A3B8),
      const Color(0xFF94A3B8),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(isFruit ? Icons.eco_rounded : Icons.card_giftcard_rounded, color: AppTheme.primaryGreen, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                ],
              ),
              Text(
                'Top Sellers',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.take(5).toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final map = entry.value as Map<String, dynamic>;
            final name = map['name'] as String;
            final count = map['quantity'] ?? map['orders'] ?? 0;
            final rev = (map['revenue'] as num?)?.toDouble() ?? 0.0;
            final rankColor = rankColors[idx];

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: idx < 3 ? rankColor.withValues(alpha: 0.15) : Colors.grey.shade200,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${idx + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: idx < 3 ? rankColor : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$count ${isFruit ? 'sold' : 'orders'}',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${rev.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOrderStatusSummary() {
    final pkgOrders = (_ordersData?['package_orders'] as Map?) ?? {};
    final frtOrders = (_ordersData?['fruit_orders'] as Map?) ?? {};
    
    int getCount(String status) {
      final p = (pkgOrders[status] as num?)?.toInt() ?? 0;
      final f = (frtOrders[status] as num?)?.toInt() ?? 0;
      return p + f;
    }

    final pending = getCount('pending');
    final outForDelivery = getCount('out_for_delivery');
    final delivered = getCount('delivered');
    final cancelled = getCount('cancelled');
    
    final delBreakdown = (_deliveriesData?['status_breakdown'] as Map?) ?? {};
    final assigned = (delBreakdown['assigned'] as num?)?.toInt() ?? 0;
    final failed = (delBreakdown['failed'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order & Delivery Status',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const Icon(Icons.sync_alt_rounded, size: 18, color: Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _buildModernStatusPill('Pending', pending, Icons.schedule_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),
              _buildModernStatusPill('Assigned', assigned, Icons.assignment_ind_rounded, const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),
              _buildModernStatusPill('Out for Delivery', outForDelivery, Icons.directions_bike_rounded, const Color(0xFF8B5CF6), const Color(0xFFF5F3FF)),
              _buildModernStatusPill('Delivered', delivered, Icons.check_circle_rounded, const Color(0xFF10B981), const Color(0xFFECFDF5)),
              _buildModernStatusPill('Failed', failed, Icons.error_rounded, const Color(0xFFEF4444), const Color(0xFFFEF2F2)),
              _buildModernStatusPill('Cancelled', cancelled, Icons.cancel_rounded, const Color(0xFF64748B), const Color(0xFFF8FAFC)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatusPill(String label, int count, IconData icon, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  count.toString(),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHighlights() {
    final topPackages = _packagesData?['top_selling'] as List?;
    final bestPkg = topPackages != null && topPackages.isNotEmpty ? topPackages.first['name'] : 'N/A';
    
    final topFruits = _fruitsData?['top_selling'] as List?;
    final bestFruit = topFruits != null && topFruits.isNotEmpty ? topFruits.first['name'] : 'N/A';
    
    final avgOrder = (_overviewData?['avg_order_value'] as num?)?.toDouble() ?? 0.0;
    final totalCust = (_overviewData?['total_customers'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text(
                'Key Business Highlights',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildHighlightTile(Icons.shopping_basket_rounded, 'Best Selling Grocery', bestFruit, const Color(0xFFEA580C)),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildHighlightTile(Icons.inventory_2_rounded, 'Best Selling Package', bestPkg, const Color(0xFF9333EA)),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildHighlightTile(Icons.payments_rounded, 'Average Order Value', _formatCurrency(avgOrder), const Color(0xFF10B981)),
          const Divider(height: 20, color: Color(0xFFF1F5F9)),
          _buildHighlightTile(Icons.people_alt_rounded, 'Total Registered Customers', totalCust.toString(), const Color(0xFF2563EB)),
        ],
      ),
    );
  }

  Widget _buildHighlightTile(IconData icon, String title, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
        ),
      ],
    );
  }

  Widget _buildExportCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.file_download_outlined, color: AppTheme.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Business Report',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      'Download executive PDF or Excel data sheets',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isExportingPdf || _isExportingExcel) ? null : () => _exportReport(isPdf: true),
                  icon: _isExportingPdf
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: Text(_isExportingPdf ? 'Exporting...' : 'Export PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isExportingPdf || _isExportingExcel) ? null : () => _exportReport(isPdf: false),
                  icon: _isExportingExcel
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.table_chart_rounded, size: 18),
                  label: Text(_isExportingExcel ? 'Exporting...' : 'Export Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport({required bool isPdf}) async {
    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    final endpoint = isPdf ? ApiConstants.reportsExportPdf : ApiConstants.reportsExportExcel;
    final filename = isPdf
        ? 'HealthyHomeFoods_Report_${DateTime.now().millisecondsSinceEpoch}.pdf'
        : 'HealthyHomeFoods_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    try {
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = await getTemporaryDirectory();
      }
      final savePath = '${dir.path}/$filename';

      final queryParams = <String, dynamic>{};
      if (_startDate != null) queryParams['start_date'] = _startDate;
      if (_endDate != null) queryParams['end_date'] = _endDate;

      await _api.dio.download(
        endpoint,
        savePath,
        queryParameters: queryParams,
      );

      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
        _showExportSuccessModal(savePath, filename, isPdf);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export report: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showExportSuccessModal(String filePath, String filename, bool isPdf) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPdf ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPdf ? Icons.picture_as_pdf_rounded : Icons.table_chart_rounded,
                  color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  size: 36,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Report Exported Successfully!',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              Text(
                filename,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await OpenFile.open(filePath);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open file: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 18),
                      label: const Text('Open Document'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                        foregroundColor: AppTheme.primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          await Share.shareXFiles(
                            [XFile(filePath)],
                            text: 'Healthy Home Foods Report (${_selectedFilter})',
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not share file: $e')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Document'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
