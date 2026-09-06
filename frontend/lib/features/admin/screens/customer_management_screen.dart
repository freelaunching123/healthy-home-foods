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
          if (_users.isNotEmpty || _searchController.text.isNotEmpty || _statusFilter != 'all')
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

class _CustomerDetailsSheetState extends State<_CustomerDetailsSheet> {
  final _api = ApiClient();
  Map<String, dynamic>? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
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
          SnackBar(content: Text('Failed to load profile details: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final user = _detail?['user'] ?? {};
    final customer = _detail?['customer'] ?? {};
    final addresses = (_detail?['addresses'] as List? ?? []).cast<Map<String, dynamic>>();
    final fullName = user['full_name'] ?? 'Customer Profile';
    final customerCode = customer['customer_code'] ?? '—';
    final status = (user['status'] ?? 'active').toString().toUpperCase();

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.primaryGreen,
                  radius: 26,
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Customer Code: $customerCode',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Profile Content
          Flexible(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                  )
                : _detail == null
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: Text('Failed to load profile.')),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Info Tiles
                          _buildInfoTile('Mobile Phone', user['phone'] ?? '—', Icons.phone_outlined),
                          _buildInfoTile('Email Address', user['email'] ?? '—', Icons.email_outlined),
                          _buildInfoTile('Status', status, Icons.info_outline),
                          if (user['created_at'] != null)
                            _buildInfoTile(
                              'Joined Date',
                              DateFormat('dd MMM yyyy').format(DateTime.parse(user['created_at'])),
                              Icons.calendar_today_outlined,
                            ),

                          const SizedBox(height: 16),

                          // Delivery Addresses Section
                          Row(
                            children: const [
                              Icon(Icons.location_on_outlined, size: 18, color: AppTheme.primaryGreen),
                              SizedBox(width: 8),
                              Text('Delivery Addresses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (addresses.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAF9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF0F2F0)),
                              ),
                              child: const Center(
                                child: Text('No addresses configured', style: TextStyle(color: AppTheme.textLight, fontSize: 13)),
                              ),
                            )
                          else
                            ...addresses.map((addr) => Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: (addr['is_default'] ?? false) ? Colors.green.shade50 : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (addr['is_default'] ?? false) ? Colors.green.shade200 : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${addr['label'] ?? 'Address'} (${addr['address_type'] ?? 'home'})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          if (addr['is_default'] ?? false)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryGreen,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('DEFAULT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${addr['address_line1']}${addr['address_line2'] != null ? ', ${addr['address_line2']}' : ''}, ${addr['city']}, ${addr['state']} - ${addr['pincode']}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String val, IconData icon) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
        subtitle: Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        dense: true,
      ),
    );
  }
}
