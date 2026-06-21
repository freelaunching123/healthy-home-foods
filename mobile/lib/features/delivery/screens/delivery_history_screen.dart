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

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('${ApiConstants.partnerHistory}?filter_period=$_selectedFilter');
      setState(() {
        _history = res.data is List ? res.data : [];
        _applySearch();
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredHistory = List.from(_history);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredHistory = _history.where((item) {
        final cust = (item['customer_name'] ?? '').toString().toLowerCase();
        final prod = (item['product_name'] ?? '').toString().toLowerCase();
        return cust.contains(q) || prod.contains(q);
      }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by Customer or Order...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _applySearch();
                });
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _filteredHistory.isEmpty
                    ? const Center(child: Text('No delivery history found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];
                          return _buildHistoryCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('Today', 'today'),
          const SizedBox(width: 8),
          _buildFilterChip('This Week', 'week'),
          const SizedBox(width: 8),
          _buildFilterChip('This Month', 'month'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _selectedFilter != value) {
          setState(() {
            _selectedFilter = value;
          });
          _loadHistory();
        }
      },
      selectedColor: AppTheme.primaryGreen.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryGreen : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildHistoryCard(dynamic item) {
    final status = item['status'] as String? ?? '';
    final isDelivered = status == 'delivered';
    final dateStr = item['delivery_date'] as String? ?? '';
    
    DateTime? dt;
    try {
      if (item['delivery_time'] != null) {
        dt = DateTime.parse(item['delivery_time']).toLocal();
      } else {
        dt = DateTime.parse(dateStr).toLocal();
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDelivered ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
          child: Icon(
            isDelivered ? Icons.check_circle : Icons.error,
            color: isDelivered ? Colors.green : Colors.red,
          ),
        ),
        title: Text(item['customer_name'] ?? 'Unknown Customer'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(item['product_name'] ?? ''),
            const SizedBox(height: 4),
            Text(
              dt != null ? DateFormat('MMM dd, yyyy - hh:mm a').format(dt) : dateStr,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
