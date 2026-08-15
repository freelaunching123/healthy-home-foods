import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';

class CustomerManagementScreen extends StatefulWidget {
  const CustomerManagementScreen({super.key});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _statusFilter = 'all'; // all, active, inactive, suspended

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadData(isSilent: true);
    });
  }

  Future<void> _loadData({bool isSilent = false}) async {
    if (!mounted) return;
    if (!isSilent) setState(() => _isLoading = true);
    try {
      // Load users & delivery partners
      final usersRes = await _api.get('/users/?role=customer');
      final partnersRes = await _api.get('/delivery-partners');

      final usersList = (usersRes.data['items'] as List).cast<Map<String, dynamic>>();
      final partnersList = (partnersRes.data as List).cast<Map<String, dynamic>>();

      setState(() {
        _users = usersList;
        _partners = partnersList;
        _applyFilter();
      });
    } catch (e) {
      if (!isSilent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load customers: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (!isSilent && mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _users.where((u) {
        final matchSearch = q.isEmpty ||
            (u['full_name'] ?? '').toString().toLowerCase().contains(q) ||
            (u['phone'] ?? '').toString().contains(q);
        
        final matchStatus = _statusFilter == 'all' ||
            (u['status'] ?? '').toString().toLowerCase() == _statusFilter;
            
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _deactivateUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Customer'),
        content: Text('Are you sure you want to deactivate ${user['full_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('/users/${user['id']}');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer deactivated successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to deactivate: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CustomerDetailsSheet(
        userId: user['id'],
        partners: _partners,
        onActionComplete: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage Customers'),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search by name or phone...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All',
                      selected: _statusFilter == 'all',
                      onTap: () {
                        setState(() => _statusFilter = 'all');
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Active',
                      selected: _statusFilter == 'active',
                      onTap: () {
                        setState(() => _statusFilter = 'active');
                        _applyFilter();
                      },
                    ),
                    const SizedBox(width: 6),
                    _FilterChip(
                      label: 'Inactive',
                      selected: _statusFilter == 'inactive',
                      onTap: () {
                        setState(() => _statusFilter = 'inactive');
                        _applyFilter();
                      },
                    ),
                    const Spacer(),
                    Text('${_filtered.length} found', style: const TextStyle(fontSize: 12, color: AppTheme.textLight)),
                  ],
                ),
              ],
            ),
          ),

          // Customers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _filtered.isEmpty
                    ? const Center(child: Text('No customers found', style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final u = _filtered[i];
                            final status = u['status'] ?? 'active';
                            final isActive = status == 'active';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                  foregroundColor: AppTheme.primaryGreen,
                                  child: Text((u['full_name'] ?? 'U')[0].toUpperCase()),
                                ),
                                title: Text(u['full_name'] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: AppTheme.textLight),
                                        const SizedBox(width: 4),
                                        Text(u['phone'] ?? '—', style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    if (u['created_at'] != null)
                                      Text(
                                        'Joined: ${DateFormat('dd MMM yyyy').format(DateTime.parse(u['created_at']))}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                                      ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? AppTheme.success : AppTheme.error,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isActive)
                                      IconButton(
                                        icon: const Icon(Icons.person_off_outlined, color: AppTheme.error, size: 20),
                                        onPressed: () => _deactivateUser(u),
                                        tooltip: 'Deactivate',
                                      ),
                                  ],
                                ),
                                onTap: () => _showDetails(u),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Customer Details Bottom Sheet ──────────────────────────────────────────────

class _CustomerDetailsSheet extends StatefulWidget {
  final String userId;
  final List<Map<String, dynamic>> partners;
  final VoidCallback onActionComplete;

  const _CustomerDetailsSheet({
    required this.userId,
    required this.partners,
    required this.onActionComplete,
  });

  @override
  State<_CustomerDetailsSheet> createState() => _CustomerDetailsSheetState();
}

class _CustomerDetailsSheetState extends State<_CustomerDetailsSheet> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDetail();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/users/customers/${widget.userId}/detail');
      setState(() => _detail = res.data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile history: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reassign(String deliveryId, String partnerId) async {
    try {
      await _api.post('/deliveries/assign', data: {
        'delivery_id': deliveryId,
        'delivery_partner_id': partnerId,
      });
      await _loadDetail();
      widget.onActionComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery Partner re-assigned successfully!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to re-assign: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _skipDay(String deliveryId) async {
    try {
      await _api.post('/subscriptions/deliveries/$deliveryId/skip');
      await _loadDetail();
      widget.onActionComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery skipped & carry-forward scheduled!'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to skip: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final sheetHeight = media.size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryGreen,
                  radius: 24,
                  child: Text(_detail?['user']?['full_name']?[0]?.toUpperCase() ?? '?'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _detail?['user']?['full_name'] ?? 'Loading Details...',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Customer Code: ${_detail?['customer']?['customer_code'] ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryGreen,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryGreen,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Subs History'),
              Tab(text: 'Deliveries'),
              Tab(text: 'Payments'),
            ],
          ),

          // Tab View Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _detail == null
                    ? const Center(child: Text('Failed to load detail.'))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(),
                          _buildSubscriptionsTab(),
                          _buildDeliveriesTab(),
                          _buildPaymentsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final user = _detail?['user'] ?? {};
    final addresses = (_detail?['addresses'] as List? ?? []).cast<Map<String, dynamic>>();
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Contact stats
        _buildInfoTile('Mobile Phone', user['phone'] ?? '—', Icons.phone_outlined),
        _buildInfoTile('Email Address', user['email'] ?? '—', Icons.email_outlined),
        _buildInfoTile('Status', (user['status'] ?? '—').toString().toUpperCase(), Icons.info_outline),
        const SizedBox(height: 20),

        // Address Section
        Row(
          children: const [
            Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryGreen),
            SizedBox(width: 8),
            Text('Delivery Addresses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        if (addresses.isEmpty)
          const Text('No addresses configured', style: TextStyle(color: AppTheme.textLight, fontSize: 13))
        else
          ...addresses.map((addr) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (addr['is_default'] ?? false) ? Colors.green.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: (addr['is_default'] ?? false) ? Colors.green.shade200 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${addr['label'] ?? 'Address'} (${addr['address_type']})',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        if (addr['is_default'] ?? false)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(4)),
                            child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${addr['address_line1']}${addr['address_line2'] != null ? ', ${addr['address_line2']}' : ''}, ${addr['city']}, ${addr['state']} - ${addr['pincode']}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _buildInfoTile(String title, String val, IconData icon) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        title: Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
        subtitle: Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        dense: true,
      ),
    );
  }

  Widget _buildSubscriptionsTab() {
    final subs = (_detail?['subscriptions'] as List? ?? []).cast<Map<String, dynamic>>();

    if (subs.isEmpty) {
      return const Center(child: Text('No subscriptions found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: subs.length,
      itemBuilder: (context, i) {
        final sub = subs[i];
        final isActive = sub['status'] == 'active';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isActive ? Colors.green.shade200 : Colors.grey.shade200),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(sub['product_name'] ?? 'Subscription', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (sub['status'] ?? '—').toString().toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isActive ? AppTheme.success : AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Plan: ${sub['plan_name']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text('Total Paid: ₹${sub['total_amount']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Total', '${sub['total_deliveries']}'),
                    _buildStatCol('Done', '${sub['completed_deliveries']}'),
                    _buildStatCol('Missed', '${sub['missed_deliveries']}'),
                    _buildStatCol('Paused', '${sub['total_paused_days']} days'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCol(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
      ],
    );
  }

  Widget _buildDeliveriesTab() {
    final deliveries = (_detail?['deliveries'] as List? ?? []).cast<Map<String, dynamic>>();

    if (deliveries.isEmpty) {
      return const Center(child: Text('No scheduled deliveries'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: deliveries.length,
      itemBuilder: (context, i) {
        final d = deliveries[i];
        final status = d['status'] ?? 'pending';
        final isActionable = status == 'pending' || status == 'assigned' || status == 'carry_forward';
        final dateStr = DateFormat('EEE, dd MMM').format(DateTime.parse(d['scheduled_date']));
        final assignedPartner = d['assigned_partner'] as Map<String, dynamic>?;
        final assignedPartnerId = assignedPartner != null ? assignedPartner['id']?.toString() : null;
        final hasAssignedPartner = assignedPartnerId != null && widget.partners.any((p) => p['id']?.toString() == assignedPartnerId);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getDeliveryStatusBg(status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status.toString().replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _getDeliveryStatusColor(status)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                if (isActionable) ...[
                  Row(
                    children: [
                      const Text('Assigned partner: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: hasAssignedPartner ? assignedPartnerId : null,
                          hint: const Text('Unassigned', style: TextStyle(fontSize: 12)),
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                          items: widget.partners.map((p) => DropdownMenuItem<String>(
                            value: p['id'].toString(),
                            child: Text(
                              '${p['full_name']} (Workload: ${p['assigned_count']})',
                              style: const TextStyle(fontSize: 11),
                            ),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _reassign(d['id'], val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 14),
                      label: const Text('Pause Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _skipDay(d['id']),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppTheme.textLight),
                      const SizedBox(width: 6),
                      Text(
                        d['assigned_partner'] != null
                            ? '${d['assigned_partner']['full_name']} (${d['assigned_partner']['mobile_number']})'
                            : 'Unassigned',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getDeliveryStatusBg(String status) {
    switch (status) {
      case 'delivered': return Colors.green.shade50;
      case 'missed': return Colors.red.shade50;
      case 'skipped': return Colors.purple.shade50;
      case 'carry_forward': return Colors.pink.shade50;
      case 'out_for_delivery': return Colors.amber.shade50;
      case 'assigned': return Colors.blue.shade50;
      default: return Colors.grey.shade100;
    }
  }

  Color _getDeliveryStatusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'missed': return AppTheme.error;
      case 'skipped': return Colors.purple;
      case 'carry_forward': return Colors.pink;
      case 'out_for_delivery': return AppTheme.warning;
      case 'assigned': return Colors.blue.shade700;
      default: return AppTheme.textSecondary;
    }
  }

  Widget _buildPaymentsTab() {
    final payments = (_detail?['payments'] as List? ?? []).cast<Map<String, dynamic>>();

    if (payments.isEmpty) {
      return const Center(child: Text('No payments recorded'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i];
        final isSuccess = p['status'] == 'capture_success' || p['status'] == 'success';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.shade100),
          ),
          child: ListTile(
            title: Text('₹${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ref: ${p['gateway_payment_id'] ?? '—'}', style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                if (p['paid_at'] != null)
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(p['paid_at'])),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isSuccess ? 'SUCCESS' : (p['status'] ?? '—').toString().toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSuccess ? AppTheme.success : AppTheme.error),
              ),
            ),
          ),
        );
      },
    );
  }
}
