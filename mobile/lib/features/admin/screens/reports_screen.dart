import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/reports/overview_cards.dart';
import '../widgets/reports/sales_analytics.dart';
import '../widgets/reports/package_performance.dart';
import '../widgets/reports/fruit_performance.dart';
import '../widgets/reports/customer_analytics.dart';
import '../widgets/reports/delivery_analytics.dart';
import '../widgets/reports/order_analytics.dart';
import '../widgets/reports/payment_analytics.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _selectedFilter = 'This Month';
  String? _startDate;
  String? _endDate;

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
      case 'Last 30 Days':
        start = now.subtract(const Duration(days: 30));
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
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
              'Last 30 Days',
              'This Month',
              'All Time',
              'Custom',
            ].map((e) => PopupMenuItem(value: e, child: Text(e))).toList(),
          ),
        ],
      ),
      drawer: const AdminDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Showing Data for: $_selectedFilter',
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                OverviewCards(startDate: _startDate, endDate: _endDate),
                const SizedBox(height: 24),
                
                SalesAnalytics(startDate: _startDate, endDate: _endDate),
                const SizedBox(height: 24),
                
                PackagePerformance(startDate: _startDate, endDate: _endDate),
                const SizedBox(height: 24),

                FruitPerformance(startDate: _startDate, endDate: _endDate),
                const SizedBox(height: 24),
                
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: CustomerAnalytics(startDate: _startDate, endDate: _endDate)),
                    const SizedBox(width: 16),
                    Expanded(child: DeliveryAnalytics(startDate: _startDate, endDate: _endDate)),
                  ],
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: OrderAnalytics(startDate: _startDate, endDate: _endDate)),
                    const SizedBox(width: 16),
                    Expanded(child: PaymentAnalytics(startDate: _startDate, endDate: _endDate)),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
