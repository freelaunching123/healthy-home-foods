import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
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
        start = null;
        end = null;
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
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.date_range, color: AppTheme.primaryGreen),
            tooltip: 'Filter by Date',
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              'Today',
              'Last 7 Days',
              'This Month',
              'All Time',
              'Custom',
            ].map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
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
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text('Failed to load data', style: TextStyle(color: Colors.grey.shade700)),
            TextButton(onPressed: _loadData, child: const Text('Retry')),
          ],
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
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No report data available for the selected period.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterHeader(),
          const SizedBox(height: 16),
          _buildBusinessSummary(),
          const SizedBox(height: 16),
          _buildSalesDistribution(),
          const SizedBox(height: 16),
          _buildTopItems('Top 5 Groceries', _fruitsData?['top_selling'] as List?),
          const SizedBox(height: 16),
          _buildTopItems('Top 5 Packages', _packagesData?['top_selling'] as List?),
          const SizedBox(height: 16),
          _buildOrderStatusSummary(),
          const SizedBox(height: 16),
          _buildBusinessHighlights(),
          const SizedBox(height: 24),
          _buildExportButton(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Row(
      children: [
        const Icon(Icons.insights, color: Colors.grey, size: 20),
        const SizedBox(width: 8),
        Text(
          'Showing: $_selectedFilter',
          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBusinessSummary() {
    final totalRev = (_overviewData?['total_revenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrd = (_overviewData?['total_orders'] as num?)?.toInt() ?? 0;
    final fruitOrd = (_overviewData?['fruit_orders_count'] as num?)?.toInt() ?? 0;
    final pkgOrd = (_overviewData?['package_orders_count'] as num?)?.toInt() ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard(Icons.account_balance_wallet_rounded, const Color(0xFF10B981), const Color(0xFFE8F5E9), 'Total Revenue', _formatCurrency(totalRev)),
        _buildSummaryCard(Icons.shopping_bag_rounded, const Color(0xFF3B82F6), const Color(0xFFEBF8FF), 'Total Orders', totalOrd.toString()),
        _buildSummaryCard(Icons.shopping_basket_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF8E1), 'Grocery Orders', fruitOrd.toString()),
        _buildSummaryCard(Icons.inventory_2_rounded, const Color(0xFF8B5CF6), const Color(0xFFF3E8FF), 'Package Orders', pkgOrd.toString()),
      ],
    );
  }

  Widget _buildSummaryCard(IconData icon, Color color, Color bg, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
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
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  Widget _buildSalesDistribution() {
    final fruitOrd = (_overviewData?['fruit_orders_count'] as num?)?.toDouble() ?? 0.0;
    final pkgOrd = (_overviewData?['package_orders_count'] as num?)?.toDouble() ?? 0.0;
    
    final total = fruitOrd + pkgOrd;
    if (total == 0) return const SizedBox.shrink();

    final fruitPct = (fruitOrd / total * 100);
    final pkgPct = (pkgOrd / total * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sales Distribution', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 20,
                    sections: [
                      PieChartSectionData(
                        color: const Color(0xFFF59E0B),
                        value: fruitPct,
                        title: fruitPct > 0 ? '${fruitPct.toStringAsFixed(0)}%' : '',
                        radius: 30,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        color: const Color(0xFF8B5CF6),
                        value: pkgPct,
                        title: pkgPct > 0 ? '${pkgPct.toStringAsFixed(0)}%' : '',
                        radius: 30,
                        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem(const Color(0xFFF59E0B), 'Grocery Orders', fruitOrd.toInt()),
                    const SizedBox(height: 12),
                    _buildLegendItem(const Color(0xFF8B5CF6), 'Package Orders', pkgOrd.toInt()),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
        Text(count.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildTopItems(String title, List<dynamic>? items) {
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ...items.take(5).map((item) {
            final map = item as Map<String, dynamic>;
            final name = map['name'] as String;
            final count = map['quantity'] ?? map['orders'] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: AppTheme.scaffoldBg, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.star_rounded, size: 16, color: Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text('$count sold', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatusItem('Pending', pending, Icons.schedule_rounded, const Color(0xFFF59E0B)),
              _buildStatusItem('Assigned', assigned, Icons.assignment_ind_rounded, const Color(0xFF3B82F6)),
              _buildStatusItem('Out for Delivery', outForDelivery, Icons.directions_bike_rounded, const Color(0xFF8B5CF6)),
              _buildStatusItem('Delivered', delivered, Icons.check_circle_rounded, const Color(0xFF10B981)),
              _buildStatusItem('Failed', failed, Icons.error_rounded, const Color(0xFFEF4444)),
              _buildStatusItem('Cancelled', cancelled, Icons.cancel_rounded, const Color(0xFF9CA3AF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 1),
              Text(count.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessHighlights() {
    final topPackages = _packagesData?['top_selling'] as List?;
    final bestPkg = topPackages != null && topPackages.isNotEmpty ? topPackages.first['name'] : 'N/A';
    
    final topFruits = _fruitsData?['top_selling'] as List?;
    final bestFruit = topFruits != null && topFruits.isNotEmpty ? topFruits.first['name'] : 'N/A';
    
    final avgOrder = (_overviewData?['avg_order_value'] as num?)?.toDouble() ?? 0.0;
    final activeSubs = (_overviewData?['active_subscriptions'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Business Highlights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _buildHighlightRow(Icons.star_rounded, 'Best Selling Grocery', bestFruit),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          _buildHighlightRow(Icons.inventory_2_rounded, 'Best Selling Package', bestPkg),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          _buildHighlightRow(Icons.payments_rounded, 'Average Order Value', _formatCurrency(avgOrder)),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          _buildHighlightRow(Icons.people_alt_rounded, 'Active Subscriptions', activeSubs.toString()),
        ],
      ),
    );
  }

  Widget _buildHighlightRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textLight),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showExportOptions,
        icon: const Icon(Icons.download_rounded, size: 20),
        label: const Text('Export Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Export As', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('PDF Document'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndShare(ApiConstants.reportsExportPdf, 'report.pdf');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Colors.green),
                title: const Text('Excel Spreadsheet'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadAndShare(ApiConstants.reportsExportExcel, 'report.xlsx');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAndShare(String endpoint, String filename) async {
    setState(() => _isLoading = true);
    try {
      final dir = await getTemporaryDirectory();
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
        setState(() => _isLoading = false);
        await Share.shareXFiles([XFile(savePath)], text: 'Here is the report you requested.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
