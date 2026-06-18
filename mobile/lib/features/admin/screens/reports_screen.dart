import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ApiClient();
  bool _isLoadingSummary = true;
  bool _isLoadingCategoryData = false;
  Map<String, dynamic>? _summaryData;
  List<dynamic> _categories = [];
  Map<String, dynamic>? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  List<dynamic> _categoryProductsPerformance = [];

  static const List<Color> _chartColors = [
    AppTheme.primaryGreen,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
  ];

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _loadCategories();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final res = await _api.get('${ApiConstants.reports}/product-performance-summary');
      setState(() => _summaryData = res.data);
    } catch (e) {
      debugPrint('Error loading reports summary: $e');
    } finally {
      setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get(ApiConstants.categories, queryParameters: {'active_only': false});
      setState(() => _categories = res.data is List ? res.data : []);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> _loadCategoryPerformance() async {
    if (_selectedCategory == null) return;
    setState(() => _isLoadingCategoryData = true);
    try {
      final Map<String, dynamic> qParams = {
        'category_id': _selectedCategory!['id'],
      };
      if (_startDate != null) {
        qParams['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      if (_endDate != null) {
        qParams['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      final res = await _api.get(
        '${ApiConstants.reports}/category-performance',
        queryParameters: qParams,
      );
      setState(() {
        _categoryProductsPerformance = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading category performance: $e');
    } finally {
      setState(() => _isLoadingCategoryData = false);
    }
  }

  void _selectCategory(Map<String, dynamic> category) {
    setState(() {
      _selectedCategory = category;
      _categoryProductsPerformance = [];
    });
    _loadCategoryPerformance();
  }

  Widget _buildDateRangeSelector(BuildContext context) {
    String label = 'All time';
    if (_startDate != null && _endDate != null) {
      label = 'Custom';
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
      if (start == today && end == today) {
        label = 'Today';
      } else if (start == today.subtract(const Duration(days: 7)) && end == today) {
        label = 'Last 7 Days';
      } else if (start == today.subtract(const Duration(days: 30)) && end == today) {
        label = 'Last 30 Days';
      } else if (start == today.subtract(const Duration(days: 90)) && end == today) {
        label = 'Last 90 Days';
      }
    }

    return PopupMenuButton<String>(
      tooltip: 'Select date range',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 16, color: AppTheme.primaryGreen),
          ],
        ),
      ),
      onSelected: (value) => _onRangePresetSelected(context, value),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'all_time',
          child: Row(
            children: [
              Icon(Icons.all_inclusive, size: 16),
              SizedBox(width: 8),
              Text('All time'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'today',
          child: Row(
            children: [
              Icon(Icons.today, size: 16),
              SizedBox(width: 8),
              Text('Today'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: '7_days',
          child: Row(
            children: [
              Icon(Icons.date_range, size: 16),
              SizedBox(width: 8),
              Text('Last 7 Days'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: '30_days',
          child: Row(
            children: [
              Icon(Icons.date_range, size: 16),
              SizedBox(width: 8),
              Text('Last 30 Days'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: '90_days',
          child: Row(
            children: [
              Icon(Icons.date_range, size: 16),
              SizedBox(width: 8),
              Text('Last 90 Days'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'custom',
          child: Row(
            children: [
              Icon(Icons.edit_calendar, size: 16),
              SizedBox(width: 8),
              Text('Custom Range...'),
            ],
          ),
        ),
      ],
    );
  }

  void _onRangePresetSelected(BuildContext context, String preset) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (preset == 'all_time') {
      setState(() {
        _startDate = null;
        _endDate = null;
      });
      _loadCategoryPerformance();
    } else if (preset == 'today') {
      setState(() {
        _startDate = today;
        _endDate = today;
      });
      _loadCategoryPerformance();
    } else if (preset == '7_days') {
      setState(() {
        _startDate = today.subtract(const Duration(days: 7));
        _endDate = today;
      });
      _loadCategoryPerformance();
    } else if (preset == '30_days') {
      setState(() {
        _startDate = today.subtract(const Duration(days: 30));
        _endDate = today;
      });
      _loadCategoryPerformance();
    } else if (preset == '90_days') {
      setState(() {
        _startDate = today.subtract(const Duration(days: 90));
        _endDate = today;
      });
      _loadCategoryPerformance();
    } else if (preset == 'custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2025),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDateRange: _startDate != null && _endDate != null
            ? DateTimeRange(start: _startDate!, end: _endDate!)
            : null,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppTheme.primaryGreen,
                onPrimary: Colors.white,
                onSurface: AppTheme.textPrimary,
              ),
            ),
            child: child!,
          );
        },
      );

      if (picked != null) {
        setState(() {
          _startDate = picked.start;
          _endDate = picked.end;
        });
        _loadCategoryPerformance();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSummary();
              _loadCategories();
              if (_selectedCategory != null) {
                _loadCategoryPerformance();
              }
            },
          ),
        ],
      ),
      body: _isLoadingSummary
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadSummary();
                await _loadCategories();
                if (_selectedCategory != null) {
                  await _loadCategoryPerformance();
                }
              },
              color: AppTheme.primaryGreen,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _buildStatRow(),
                  const SizedBox(height: 24),
                  _buildPerformanceLists(),
                  const SizedBox(height: 32),
                  const Text(
                    'Category-wise Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoriesSelector(),
                  const SizedBox(height: 16),
                  _buildPieChartCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatRow() {
    final total = _summaryData?['total_products']?.toString() ?? '0';
    final active = _summaryData?['active_products']?.toString() ?? '0';
    final inactive = _summaryData?['inactive_products']?.toString() ?? '0';

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total',
            value: total,
            icon: Icons.inventory_2_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Active',
            value: active,
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: 'Inactive',
            value: inactive,
            icon: Icons.hide_source_outlined,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceLists() {
    final topList = _summaryData?['top_performing'] as List<dynamic>? ?? [];
    final worstList = _summaryData?['worst_performing'] as List<dynamic>? ?? [];

    return Column(
      children: [
        _buildPerformanceCard('Best Performing Products (Top 5)', topList, Colors.green),
        const SizedBox(height: 16),
        _buildPerformanceCard('Worst Performing Products (Bottom 5)', worstList, Colors.red),
      ],
    );
  }

  Widget _buildPerformanceCard(String title, List<dynamic> list, Color badgeColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stars_rounded, color: badgeColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (list.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No performance data available', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (ctx, i) => Divider(color: Colors.grey.shade100, height: 1),
                itemBuilder: (ctx, i) {
                  final prod = list[i];
                  final deliveredCount = prod['delivered_count'] ?? 0;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(prod['name'] ?? 'Unknown Product', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$deliveredCount delivered',
                        style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSelector() {
    if (_categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No categories available. Add them in Category Management.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (ctx, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory != null && _selectedCategory!['id'] == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                cat['name'] ?? '',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              selectedColor: AppTheme.primaryGreen,
              backgroundColor: Colors.white,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
                ),
              ),
              onSelected: (selected) {
                if (selected) {
                  _selectCategory(cat);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPieChartCard() {
    if (_selectedCategory == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('Select a category above to view performance details', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ),
      );
    }

    final totalDeliveries = _categoryProductsPerformance.fold<int>(
      0,
      (sum, item) => sum + (item['delivered_count'] as num).toInt(),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
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
                    '${_selectedCategory!['name']} - Product Share',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                _buildDateRangeSelector(context),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Date', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                _startDate == null ? 'All time' : DateFormat('yyyy-MM-dd').format(_startDate!),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 16, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('End Date', style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              Text(
                                _endDate == null ? 'All time' : DateFormat('yyyy-MM-dd').format(_endDate!),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _isLoadingCategoryData
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48.0),
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                    ),
                  )
                : _categoryProductsPerformance.isEmpty || totalDeliveries == 0
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 36, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No delivered sales in this category / range', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 200,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 50,
                                sections: _buildPieSections(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Legend
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _categoryProductsPerformance.length,
                            itemBuilder: (context, i) {
                              final item = _categoryProductsPerformance[i];
                              final color = _chartColors[i % _chartColors.length];
                              final count = item['delivered_count'] as int;
                              final pct = totalDeliveries > 0 ? (count / totalDeliveries * 100).toStringAsFixed(1) : '0';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        item['name'] ?? 'Unknown Product',
                                        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                    Text(
                                      '$count del. ($pct%)',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final totalDeliveries = _categoryProductsPerformance.fold<int>(
      0,
      (sum, item) => sum + (item['delivered_count'] as num).toInt(),
    );

    return List.generate(_categoryProductsPerformance.length, (i) {
      final item = _categoryProductsPerformance[i];
      final count = item['delivered_count'] as int;
      final color = _chartColors[i % _chartColors.length];
      final pct = totalDeliveries > 0 ? (count / totalDeliveries * 100).toStringAsFixed(0) : '0';
      return PieChartSectionData(
        color: color,
        value: count.toDouble(),
        title: '$pct%',
        radius: 40,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
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
