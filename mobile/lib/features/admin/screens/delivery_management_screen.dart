import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
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

  // Filter Chips Options
  final List<String> _filterChips = [
    'All', 'Packages', 'Fruits', 'Pending', 'Assigned', 'Out for Delivery', 'Delivered', 'Cancelled', 'Failed'
  ];
  String _activeChip = 'All';

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
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
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

      final res = await _api.get(ApiConstants.adminDeliveries, queryParameters: qParams);
      
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
      final res = await _api.get('/delivery-partners');
      if (mounted && res.data is List) {
        setState(() {
          _partners = List<Map<String, dynamic>>.from(res.data);
        });
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.error,
    ));
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.success,
    ));
  }

  void _handleChipSelection(String chip) {
    setState(() {
      _activeChip = chip;
      // Reset complex filters
      _selectedOrderType = 'all';
      _selectedStatus = 'all';

      switch (chip) {
        case 'Packages': _selectedOrderType = 'subscription'; break;
        case 'Fruits': _selectedOrderType = 'fruit'; break;
        case 'Pending': _selectedStatus = 'pending'; break;
        case 'Assigned': _selectedStatus = 'assigned'; break;
        case 'Out for Delivery': _selectedStatus = 'out_for_delivery'; break;
        case 'Delivered': _selectedStatus = 'delivered'; break;
        case 'Cancelled': _selectedStatus = 'cancelled'; break;
        case 'Failed': _selectedStatus = 'failed'; break;
        default: break;
      }
      _isLoading = true;
    });
    _loadDeliveries();
  }

  Future<void> _assignPartner(String orderType, String id, String partnerId) async {
    setState(() => _isActionInProgress = true);
    try {
      if (orderType == 'subscription') {
        // Find subscription_id
        final deliv = _deliveries.firstWhere((d) => d['id'] == id);
        final subId = deliv['subscription_id'];
        await _api.post('/packages/orders/admin/package-orders/$subId/assign', data: {
          'delivery_partner_id': partnerId
        });
      } else {
        await _api.post('/fruits/admin/orders/$id/assign', data: {
          'delivery_partner_id': partnerId
        });
      }
      _showSuccessSnackBar('Partner assigned successfully');
      await _loadDeliveries();
    } catch (e) {
      _showErrorSnackBar('Failed to assign partner');
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _updateStatus(String id, String status) async {
    setState(() => _isActionInProgress = true);
    try {
      await _api.put('/admin/deliveries/$id/status', data: {
        'status': status
      });
      _showSuccessSnackBar('Status updated');
      await _loadDeliveries();
    } catch (e) {
      _showErrorSnackBar('Failed to update status');
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  void _showAssignDialog(Map<String, dynamic> delivery) {
    showDialog(
      context: context,
      builder: (context) => DeliveryPartnerDialog(
        partners: _partners,
        onAssign: (partnerId) {
          _assignPartner(delivery['order_type'], delivery['id'], partnerId);
        },
      ),
    );
  }

  void _showDeliveryDetails(Map<String, dynamic> delivery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeliveryDetailsSheet(details: delivery),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                // Date Filter
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryGreen),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setModalState(() => _selectedDate = picked);
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
                const Divider(),
                
                // Status Filter
                const Text('Status', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                    DropdownMenuItem(value: 'out_for_delivery', child: Text('Out for Delivery')),
                    DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(value: 'failed', child: Text('Failed')),
                  ],
                  onChanged: (val) {
                    setModalState(() => _selectedStatus = val!);
                    setState(() => _selectedStatus = val!);
                  },
                ),
                const SizedBox(height: 16),

                // Order Type
                const Text('Order Type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedOrderType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'subscription', child: Text('Packages')),
                    DropdownMenuItem(value: 'fruit', child: Text('Fruits')),
                  ],
                  onChanged: (val) {
                    setModalState(() => _selectedOrderType = val!);
                    setState(() => _selectedOrderType = val!);
                  },
                ),
                const SizedBox(height: 16),

                // Delivery Partner
                const Text('Delivery Partner', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedPartnerId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('All Partners')),
                    ..._partners.map((p) => DropdownMenuItem(
                      value: p['id'].toString(),
                      child: Text(p['full_name'] ?? 'Unknown'),
                    ))
                  ],
                  onChanged: (val) {
                    setModalState(() => _selectedPartnerId = val!);
                    setState(() => _selectedPartnerId = val!);
                  },
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedDate = DateTime.now();
                            _selectedStatus = 'all';
                            _selectedOrderType = 'all';
                            _selectedPartnerId = 'all';
                            _activeChip = 'All';
                          });
                          setState(() {
                            _selectedDate = DateTime.now();
                            _selectedStatus = 'all';
                            _selectedOrderType = 'all';
                            _selectedPartnerId = 'all';
                            _activeChip = 'All';
                            _isLoading = true;
                          });
                          Navigator.pop(context);
                          _loadDeliveries();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _activeChip = ''; // clear chip if advanced filters used
                            _isLoading = true;
                          });
                          Navigator.pop(context);
                          _loadDeliveries();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Apply', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F7FA), // Modern light grey background
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          color: AppTheme.textPrimary,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Deliveries',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Summary Grid
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.5,
                children: [
                  _buildSummaryCard("Today's Deliveries", _dashboardStats['total'] ?? 0, Icons.local_shipping, AppTheme.primaryBlue),
                  _buildSummaryCard("Pending", _dashboardStats['pending'] ?? 0, Icons.hourglass_empty, AppTheme.accentOrange),
                  _buildSummaryCard("Assigned", _dashboardStats['assigned'] ?? 0, Icons.assignment_ind, Colors.teal),
                  _buildSummaryCard("Completed", _dashboardStats['delivered'] ?? 0, Icons.check_circle, AppTheme.primaryGreen),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Order ID, Name, Mobile, Partner...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
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

            // Filter Chips Row
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filterChips.length,
                itemBuilder: (context, index) {
                  final chip = _filterChips[index];
                  final isActive = _activeChip == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(chip),
                      selected: isActive,
                      onSelected: (val) {
                        if (val) _handleChipSelection(chip);
                      },
                      selectedColor: AppTheme.primaryGreen,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isActive ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isActive ? AppTheme.primaryGreen : Colors.grey.shade300,
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Deliveries List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : _deliveries.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _deliveries.length,
                          itemBuilder: (context, index) {
                            final delivery = _deliveries[index];
                            return DeliveryUnifiedCard(
                              delivery: delivery,
                              onTap: () => _showDeliveryDetails(delivery),
                              onAssignTap: () => _showAssignDialog(delivery),
                              onCancelTap: () => _updateStatus(delivery['id'], 'cancelled'),
                              onMarkOutTap: () => _updateStatus(delivery['id'], 'out_for_delivery'),
                              onDeliveredTap: () => _updateStatus(delivery['id'], 'delivered'),
                              onFailedTap: () => _updateStatus(delivery['id'], 'failed'),
                              onNavigateTap: () {}, // Optional feature
                              onInvoiceTap: () {}, // Optional feature
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterBottomSheet,
        backgroundColor: AppTheme.primaryGreen,
        child: const Icon(Icons.filter_list, color: Colors.white),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 24),
          const Text(
            'No deliveries available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          const Text(
            'When new customer orders arrive, they will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
