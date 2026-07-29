import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_drawer.dart';
import '../widgets/delivery_unified_card.dart';
import '../widgets/delivery_partner_dialog.dart';
import '../widgets/delivery_details_sheet.dart';

class DeliveryManagementScreen extends StatefulWidget {
  const DeliveryManagementScreen({super.key});

  @override
  State<DeliveryManagementScreen> createState() => _DeliveryManagementScreenState();
}

class _DeliveryManagementScreenState extends State<DeliveryManagementScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'all';
  String _selectedOrderType = 'all';
  String _selectedPartnerId = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _deliveries = [];
  List<Map<String, dynamic>> _partners = [];
  
  Map<String, int> _dashboardStats = {
    'total': 0,
    'pending': 0,
    'assigned': 0,
    'out': 0,
    'delivered': 0,
    'failed': 0,
    'cancelled': 0,
  };

  bool _isLoading = true;
  bool _isActionInProgress = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isActionInProgress) {
        _loadDeliveries();
      }
    });
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadDeliveries(),
        _loadPartners(),
      ]);
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error loading data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDeliveries() async {
    try {
      final Map<String, dynamic> qParams = {
        'selected_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
      };
      if (_selectedStatus != 'all') qParams['status'] = _selectedStatus;
      if (_selectedPartnerId != 'all') qParams['delivery_partner_id'] = _selectedPartnerId;
      if (_searchQuery.isNotEmpty) qParams['search'] = _searchQuery;

      final res = await _api.get('/api/v1/admin/deliveries/', queryParameters: qParams);
      
      if (mounted) {
        setState(() {
          if (res.data is List) {
            _deliveries = List<Map<String, dynamic>>.from(res.data);
            if (_selectedOrderType != 'all') {
              _deliveries = _deliveries.where((d) => d['order_type'] == _selectedOrderType).toList();
            }
            _calculateStats();
          } else {
            _deliveries = [];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading deliveries: $e');
    }
  }

  void _calculateStats() {
    int total = _deliveries.length;
    int pending = 0;
    int assigned = 0;
    int out = 0;
    int delivered = 0;
    int failed = 0;
    int cancelled = 0;

    for (var d in _deliveries) {
      final status = (d['status'] ?? '').toString().toLowerCase();
      if (status == 'pending') pending++;
      else if (status == 'assigned') assigned++;
      else if (status == 'out_for_delivery' || status == 'out') out++;
      else if (status == 'delivered') delivered++;
      else if (status == 'failed' || status == 'missed') failed++;
      else if (status == 'cancelled' || status == 'skipped') cancelled++;
    }

    _dashboardStats = {
      'total': total,
      'pending': pending,
      'assigned': assigned,
      'out': out,
      'delivered': delivered,
      'failed': failed,
      'cancelled': cancelled,
    };
  }

  Future<void> _loadPartners() async {
    try {
      final res = await _api.get('/api/v1/admin/delivery-partners/');
      if (mounted && res.data != null) {
        setState(() {
          _partners = List<Map<String, dynamic>>.from(res.data['items'] ?? res.data);
        });
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.success));
  }

  Future<void> _handleAssignPartner(Map<String, dynamic> delivery) async {
    showDialog(
      context: context,
      builder: (context) => DeliveryPartnerDialog(
        partners: _partners,
        onAssign: (partnerId) async {
          Navigator.pop(context);
          setState(() => _isActionInProgress = true);
          try {
            String endpoint = '';
            if (delivery['order_type'] == 'subscription') {
              endpoint = '/api/v1/admin/deliveries/subscription/${delivery['subscription_id']}/assign';
            } else {
              endpoint = '/api/v1/admin/deliveries/fruit/${delivery['fruit_order_id']}/assign';
            }

            await _api.post(endpoint, data: {'delivery_partner_id': partnerId});
            _showSuccessSnackBar('Delivery Partner Assigned Successfully');
            await _loadDeliveries();
            await _loadPartners();
          } catch (e) {
            _showErrorSnackBar('Failed to assign partner: $e');
          } finally {
            setState(() => _isActionInProgress = false);
          }
        },
      ),
    );
  }

  Future<void> _showDeliveryDetails(Map<String, dynamic> delivery) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FutureBuilder(
        future: _api.get('/api/v1/admin/deliveries/${delivery['id']}'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Container(
              height: 300,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Container(
              height: 300,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              child: Center(child: Text('Failed to load details')),
            );
          }
          final details = snapshot.data!.data as Map<String, dynamic>;
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: DeliveryDetailsSheet(details: details),
          );
        },
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _loadDeliveries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AdminDrawer(),
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Deliveries', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Column(
              children: [
                _buildDashboardSummary(),
                _buildFilters(),
                Expanded(
                  child: _deliveries.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadDeliveries,
                          color: AppTheme.primaryGreen,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _deliveries.length,
                            itemBuilder: (context, index) {
                              final delivery = _deliveries[index];
                              return DeliveryUnifiedCard(
                                delivery: delivery,
                                onAssignTap: () => _handleAssignPartner(delivery),
                                onTap: () => _showDeliveryDetails(delivery),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildDashboardSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatBadge('Total', _dashboardStats['total'].toString(), Colors.grey[700]!),
            _StatBadge('Pending', _dashboardStats['pending'].toString(), AppTheme.warning),
            _StatBadge('Assigned', _dashboardStats['assigned'].toString(), AppTheme.primaryGreen),
            _StatBadge('Out', _dashboardStats['out'].toString(), AppTheme.primaryBlue),
            _StatBadge('Delivered', _dashboardStats['delivered'].toString(), AppTheme.success),
            _StatBadge('Failed', _dashboardStats['failed'].toString(), AppTheme.error),
            _StatBadge('Cancelled', _dashboardStats['cancelled'].toString(), AppTheme.error),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search orders, customers...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) {
                    setState(() {
                      _searchQuery = val;
                      _isLoading = true;
                    });
                    _loadDeliveries();
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('MMM dd').format(_selectedDate)),
                onPressed: () => _selectDate(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  value: _selectedOrderType,
                  items: const {
                    'all': 'All Types',
                    'subscription': 'Subscriptions',
                    'fruit': 'Fruit Orders',
                  },
                  onChanged: (val) {
                    setState(() {
                      _selectedOrderType = val!;
                      _isLoading = true;
                    });
                    _loadDeliveries();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  value: _selectedStatus,
                  items: const {
                    'all': 'All Statuses',
                    'pending': 'Pending',
                    'assigned': 'Assigned',
                    'out_for_delivery': 'Out',
                    'delivered': 'Delivered',
                    'failed': 'Failed',
                  },
                  onChanged: (val) {
                    setState(() {
                      _selectedStatus = val!;
                      _isLoading = true;
                    });
                    _loadDeliveries();
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.entries.map((e) {
            return DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No deliveries available for the selected date.',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: _loadDeliveries,
          )
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _StatBadge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
