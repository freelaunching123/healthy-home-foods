import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class DeliveryHistoryScreen extends StatefulWidget {
  const DeliveryHistoryScreen({super.key});

  @override
  State<DeliveryHistoryScreen> createState() => _DeliveryHistoryScreenState();
}

class _DeliveryHistoryScreenState extends State<DeliveryHistoryScreen> {
  final _api = ApiClient();
  List<dynamic> _history = [];
  List<dynamic> _filteredHistory = [];
  bool _isLoading = true;
  String _selectedFilter = 'today'; // today, week, month
  String _searchQuery = '';

  int _completedToday = 0;
  int _completedThisWeek = 0;
  int _completedThisMonth = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // Always load the maximum window (month) so we can calculate stats client-side
      final res = await _api.get('${ApiConstants.partnerHistory}?filter_period=month');
      setState(() {
        _history = res.data is List ? res.data : [];
        _calculateStats();
        _applyFiltersAndSearch();
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int todayCount = 0;
    int weekCount = 0;
    int monthCount = 0;

    for (var item in _history) {
      if (item['status'] != 'delivered') continue;
      
      try {
        final parsedDate = DateTime.parse(item['delivery_date'] as String);
        final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        final diffDays = today.difference(dateOnly).inDays;
        
        if (dateOnly.isAtSameMomentAs(today)) {
          todayCount++;
        }
        if (diffDays >= 0 && diffDays < 7) {
          weekCount++;
        }
        if (diffDays >= 0 && diffDays < 30) {
          monthCount++;
        }
      } catch (e) {
        debugPrint('Error parsing date for stats: $e');
      }
    }

    _completedToday = todayCount;
    _completedThisWeek = weekCount;
    _completedThisMonth = monthCount;
  }

  void _applyFiltersAndSearch() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. Filter by Period
    List<dynamic> periodFiltered = _history.where((item) {
      try {
        final parsedDate = DateTime.parse(item['delivery_date'] as String);
        final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
        final diffDays = today.difference(dateOnly).inDays;

        if (_selectedFilter == 'today') {
          return dateOnly.isAtSameMomentAs(today);
        } else if (_selectedFilter == 'week') {
          return diffDays >= 0 && diffDays < 7;
        } else {
          return diffDays >= 0 && diffDays < 30;
        }
      } catch (_) {
        return false;
      }
    }).toList();

    // 2. Filter by Search Query
    if (_searchQuery.isEmpty) {
      _filteredHistory = periodFiltered;
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredHistory = periodFiltered.where((item) {
        final cust = (item['customer_name'] ?? '').toString().toLowerCase();
        final orderId = (item['order_id'] ?? '').toString().toLowerCase();
        final prod = (item['product_name'] ?? '').toString().toLowerCase();
        return cust.contains(q) || orderId.contains(q) || prod.contains(q);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Delivery History'),

      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Customer or Order ID...',
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applyFiltersAndSearch();
                });
              },
            ),
          ),

          // Summary Cards Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(child: _buildSummaryCard('Today', '$_completedToday', AppTheme.primaryGreen)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('This Week', '$_completedThisWeek', Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _buildSummaryCard('This Month', '$_completedThisMonth', Colors.purple)),
              ],
            ),
          ),

          // Date Filters Tabs
          _buildFilterTabs(),

          // Deliveries List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _filteredHistory.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No deliveries recorded for this period.' : 'No matches found.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppTheme.primaryGreen,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredHistory.length,
                          itemBuilder: (context, index) {
                            final item = _filteredHistory[index];
                            return _buildHistoryCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              count,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            const Text(
              'Delivered',
              style: TextStyle(fontSize: 9, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTabChip('Today', 'today')),
          Expanded(child: _buildTabChip('This Week', 'week')),
          Expanded(child: _buildTabChip('This Month', 'month')),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedFilter = value;
            _applyFiltersAndSearch();
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final status = item['status'] as String? ?? '';
    final isDelivered = status == 'delivered';
    final isFailed = status == 'failed';
    final dateStr = item['delivery_date'] as String? ?? '';
    final orderType = item['order_type'] == 'fruit' ? 'Fruit Order' : 'Subscription';
    
    DateTime? dt;
    try {
      if (item['delivery_time'] != null) {
        dt = DateTime.parse(item['delivery_time']).toLocal();
      } else {
        dt = DateTime.parse(dateStr).toLocal();
      }
    } catch (_) {}

    final displayTime = dt != null 
        ? DateFormat('hh:mm a').format(dt) 
        : 'Standard Time';
    final displayDate = dt != null 
        ? DateFormat('MMM dd, yyyy').format(dt) 
        : dateStr;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: isDelivered 
                  ? AppTheme.primaryGreen.withValues(alpha: 0.1) 
                  : isFailed 
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
              child: Icon(
                isDelivered 
                    ? Icons.check_circle_outline 
                    : isFailed 
                        ? Icons.error_outline 
                        : Icons.local_shipping_outlined,
                color: isDelivered 
                    ? AppTheme.primaryGreen 
                    : isFailed 
                        ? Colors.red 
                        : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${item['order_id'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDelivered 
                              ? AppTheme.primaryGreen.withValues(alpha: 0.08) 
                              : isFailed 
                                  ? Colors.red.withValues(alpha: 0.08)
                                  : Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            color: isDelivered 
                                ? AppTheme.primaryGreen 
                                : isFailed 
                                    ? Colors.red 
                                    : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item['customer_name'] ?? 'Unknown Customer',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$orderType • ${item['product_name'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(displayDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(displayTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
