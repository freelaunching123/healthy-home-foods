import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionManagementScreen extends StatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  State<SubscriptionManagementScreen> createState() => _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState extends State<SubscriptionManagementScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();

  List<dynamic> _subscriptions = [];
  bool _isLoading = true;
  String _statusFilter = 'all'; // all, active, paused, pending_payment, completed, cancelled
  int _page = 1;
  bool _hasMore = true;
  List<dynamic> _plans = [];

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
    _loadPlans();
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
      if (mounted) {
        _loadSubscriptions(refresh: false, isSilent: true);
      }
    });
  }

  Future<void> _loadPlans() async {
    try {
      final res = await _api.get(ApiConstants.subscriptionPlans);
      if (res.data is List) {
        setState(() => _plans = res.data);
      }
    } catch (e) {
      debugPrint('Error loading plans: $e');
    }
  }

  Future<void> _loadSubscriptions({bool refresh = true, bool isSilent = false}) async {
    if (!mounted) return;
    if (refresh) {
      setState(() {
        _page = 1;
        _isLoading = true;
        _subscriptions.clear();
        _hasMore = true;
      });
    }

    try {
      final Map<String, dynamic> queryParams = {
        'page': isSilent ? 1 : _page,
        'page_size': 15,
      };

      if (_statusFilter != 'all') {
        queryParams['status'] = _statusFilter;
      }

      if (_searchController.text.isNotEmpty) {
        queryParams['search'] = _searchController.text;
      }

      final res = await _api.get(ApiConstants.subscriptions, queryParameters: queryParams);
      final List<dynamic> items = res.data is List ? res.data : (res.data['items'] ?? []);

      setState(() {
        if (refresh || isSilent) {
          _subscriptions = items;
          if (isSilent) _page = 1;
        } else {
          _subscriptions.addAll(items);
        }
        _hasMore = items.length == 15;
        if (!isSilent) _isLoading = false;
      });
    } catch (e) {
      if (!isSilent) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load subscriptions: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    _loadSubscriptions(refresh: true);
  }

  Future<void> _pauseSubscription(String subId) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pause Subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Provide a reason for pausing this subscription:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. On vacation, temporary shift...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pause'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _api.post('/subscriptions/$subId/pause', data: {
        'reason': reasonCtrl.text.isNotEmpty ? reasonCtrl.text : 'Administrative pause',
      });
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription paused successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _resumeSubscription(String subId) async {
    setState(() => _isLoading = true);
    try {
      await _api.post('/subscriptions/$subId/resume');
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription resumed successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }



  Future<void> _renewSubscription(String subId, String currentPlanId, bool autoRenew) async {
    String? selectedPlanId = currentPlanId.isNotEmpty ? currentPlanId : null;
    bool isAutoRenew = autoRenew;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Text('Renew Subscription'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Choose the subscription plan for renewal:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPlanId,
                  decoration: const InputDecoration(
                    labelText: 'Select Plan',
                    border: OutlineInputBorder(),
                  ),
                  items: _plans.map((p) => DropdownMenuItem<String>(
                    value: p['id'].toString(),
                    child: Text('${p['name']} (${p['total_deliveries']} deliveries)'),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedPlanId = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Auto Renew after this cycle'),
                  value: isAutoRenew,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => isAutoRenew = val);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                onPressed: () {
                  if (selectedPlanId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a plan to renew'), backgroundColor: AppTheme.error),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Confirm Renewal'),
              ),
            ],
          );
        },
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _api.post('/subscriptions/$subId/renew?new_plan_id=$selectedPlanId&auto_renew=$isAutoRenew');
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription renewed successfully (pending payment)'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      _loadSubscriptions(refresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to renew: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showSubscriptionDetails(String subId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubscriptionDetailsSheet(
        subscriptionId: subId,
        onActionComplete: () => _loadSubscriptions(refresh: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage Subscriptions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search and Filters
          if (_subscriptions.isNotEmpty || _searchController.text.isNotEmpty || _statusFilter != 'all')
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _onSearchChanged(),
                    decoration: InputDecoration(
                      hintText: 'Search by customer, phone, or product...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged();
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.search_rounded, size: 18),
                              onPressed: _onSearchChanged,
                            ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'All',
                          selected: _statusFilter == 'all',
                          onTap: () {
                            setState(() => _statusFilter = 'all');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Active',
                          selected: _statusFilter == 'active',
                          onTap: () {
                            setState(() => _statusFilter = 'active');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Paused',
                          selected: _statusFilter == 'paused',
                          onTap: () {
                            setState(() => _statusFilter = 'paused');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Pending Payment',
                          selected: _statusFilter == 'pending_payment',
                          onTap: () {
                            setState(() => _statusFilter = 'pending_payment');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Completed',
                          selected: _statusFilter == 'completed',
                          onTap: () {
                            setState(() => _statusFilter = 'completed');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: 'Cancelled',
                          selected: _statusFilter == 'cancelled',
                          onTap: () {
                            setState(() => _statusFilter = 'cancelled');
                            _loadSubscriptions(refresh: true);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Subscriptions List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _subscriptions.isEmpty
                    ? const Center(
                        child: Text(
                          'No subscriptions found',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _subscriptions.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _subscriptions.length) {
                              _page++;
                              _loadSubscriptions(refresh: false);
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                                ),
                              );
                            }

                            final sub = _subscriptions[i];
                            final status = sub['status'] ?? 'pending_payment';
                            final subId = sub['id']?.toString() ?? '';
                            final items = (sub['items'] as List? ?? []).cast<Map<String, dynamic>>();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Customer Header
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                          foregroundColor: AppTheme.primaryGreen,
                                          child: Text((sub['customer_name'] ?? 'C')[0].toUpperCase()),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                sub['customer_name'] ?? 'Customer',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                sub['customer_phone'] ?? '—',
                                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _StatusBadge(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),

                                    // Plan & Pricing Detail
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildDetailCol('Plan', sub['plan_name'] ?? '—'),
                                        _buildDetailCol('Deliveries', '${sub['completed_deliveries']} / ${sub['total_deliveries']}'),
                                        _buildDetailCol('Total', '₹${parseFloat(sub['total_amount'])}'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Product list in card
                                    if (items.isNotEmpty) ...[
                                      const Text(
                                        'Items Subscribed:',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                                      ),
                                      const SizedBox(height: 4),
                                      ...items.map((item) => Padding(
                                            padding: const EdgeInsets.only(bottom: 2),
                                            child: Text(
                                              '• ${item['product_name'] ?? 'Product'} (x${item['quantity']})',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            ),
                                          )),
                                      const SizedBox(height: 12),
                                    ],

                                    // Schedule details
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_month, size: 14, color: AppTheme.textLight),
                                        const SizedBox(width: 6),
                                        Text(
                                          sub['start_date'] != null
                                              ? 'Started: ${DateFormat('dd MMM yyyy').format(DateTime.parse(sub['start_date']))}'
                                              : 'Start Date: Not set',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Actions row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(80, 36),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.info_outline, size: 16),
                                          label: const Text('Details', style: TextStyle(fontSize: 12)),
                                          onPressed: () => _showSubscriptionDetails(subId),
                                        ),
                                        const SizedBox(width: 8),

                                        if (status == 'active') ...[
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.warning,
                                              minimumSize: const Size(80, 36),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.pause, size: 16),
                                            label: const Text('Pause', style: TextStyle(fontSize: 12, color: Colors.white)),
                                            onPressed: () => _pauseSubscription(subId),
                                          ),
                                          const SizedBox(width: 8),
                                        ],

                                        if (status == 'paused') ...[
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primaryGreen,
                                              minimumSize: const Size(80, 36),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.play_arrow, size: 16),
                                            label: const Text('Resume', style: TextStyle(fontSize: 12, color: Colors.white)),
                                            onPressed: () => _resumeSubscription(subId),
                                          ),
                                          const SizedBox(width: 8),
                                        ],

                                        if (['completed', 'cancelled'].contains(status)) ...[
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.info,
                                              minimumSize: const Size(80, 36),
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            icon: const Icon(Icons.replay_rounded, size: 16),
                                            label: const Text('Renew', style: TextStyle(fontSize: 12, color: Colors.white)),
                                            onPressed: () => _renewSubscription(subId, sub['plan_id']?.toString() ?? '', sub['auto_renew'] ?? false),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCol(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textLight, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
      ],
    );
  }

  double parseFloat(dynamic val) {
    if (val == null) return 0.0;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? 0.0;
    }
    return 0.0;
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGreen : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.grey.shade100;
    Color fg = AppTheme.textSecondary;
    String label = status.toUpperCase();

    if (status == 'active') {
      bg = Colors.green.shade50;
      fg = AppTheme.success;
      label = 'ACTIVE';
    } else if (status == 'paused') {
      bg = Colors.amber.shade50;
      fg = AppTheme.warning;
      label = 'PAUSED';
    } else if (status == 'pending_payment') {
      bg = Colors.blue.shade50;
      fg = AppTheme.info;
      label = 'PENDING PAYMENT';
    } else if (status == 'completed') {
      bg = Colors.grey.shade100;
      fg = AppTheme.textSecondary;
      label = 'COMPLETED';
    } else if (status == 'cancelled') {
      bg = Colors.red.shade50;
      fg = AppTheme.error;
      label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

// ── Subscription Details Bottom Sheet ──────────────────────────────────────────────

class _SubscriptionDetailsSheet extends StatefulWidget {
  final String subscriptionId;
  final VoidCallback onActionComplete;

  const _SubscriptionDetailsSheet({
    required this.subscriptionId,
    required this.onActionComplete,
  });

  @override
  State<_SubscriptionDetailsSheet> createState() => _SubscriptionDetailsSheetState();
}

class _SubscriptionDetailsSheetState extends State<_SubscriptionDetailsSheet> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;
  Map<String, dynamic>? _subDetail;
  List<dynamic> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Fetch Subscription detail
      final detailRes = await _api.get('/subscriptions/${widget.subscriptionId}');
      _subDetail = detailRes.data;

      // 2. Fetch Deliveries schedule
      final deliveriesRes = await _api.get('/subscriptions/${widget.subscriptionId}/deliveries');
      _deliveries = deliveriesRes.data is List ? deliveriesRes.data : (deliveriesRes.data['items'] ?? []);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load subscription details: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _skipDeliveryDay(String deliveryId) async {
    try {
      await _api.post('/subscriptions/deliveries/$deliveryId/skip');
      await _loadAllDetails();
      widget.onActionComplete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery skipped and extended carry-forward scheduled!'), backgroundColor: AppTheme.success),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  child: Text(_subDetail?['customer_name']?[0]?.toUpperCase() ?? '?'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _subDetail?['customer_name'] ?? 'Loading Detail...',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'ID: ${widget.subscriptionId.substring(0, 8)}...',
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
              Tab(text: 'Items & Info'),
              Tab(text: 'Deliveries'),
              Tab(text: 'Audit Logs'),
            ],
          ),

          // Tab View Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _subDetail == null
                    ? const Center(child: Text('Failed to load detail.'))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildItemsInfoTab(),
                          _buildDeliveriesTab(),
                          _buildAuditLogsTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsInfoTab() {
    final items = (_subDetail?['items'] as List? ?? []).cast<Map<String, dynamic>>();
    
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Subscription Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                title: Text(item['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Price per delivery: ₹${item['price_per_delivery'] ?? '0.0'}'),
                trailing: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  radius: 14,
                  child: Text('x${item['quantity']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            )),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Additional Parameters', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildInfoRow('Plan Name', _subDetail?['plan_name'] ?? '—'),
        _buildInfoRow('Preferred Time', _subDetail?['preferred_delivery_time'] ?? 'Not configured'),
        _buildInfoRow('Auto Renew', _subDetail?['auto_renew'] == true ? 'Enabled' : 'Disabled'),
        _buildInfoRow('Price per Delivery', '₹${_subDetail?['price_per_delivery'] ?? '0.0'}'),
        _buildInfoRow('Delivery Charge', '₹${_subDetail?['delivery_charge'] ?? '0.0'}'),
        _buildInfoRow('Tax Amount', '₹${_subDetail?['tax_amount'] ?? '0.0'}'),
        _buildInfoRow('Total Amount', '₹${_subDetail?['total_amount'] ?? '0.0'}'),
        _buildInfoRow('Address ID', _subDetail?['address_id'] ?? '—'),
        if (_subDetail != null && _subDetail!['notes'] != null && _subDetail!['notes'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Admin Notes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Text(_subDetail?['notes'] ?? '', style: const TextStyle(fontSize: 13)),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveriesTab() {
    if (_deliveries.isEmpty) {
      return const Center(child: Text('No deliveries scheduled yet'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _deliveries.length,
      itemBuilder: (context, i) {
        final d = _deliveries[i];
        final status = d['status'] ?? 'pending';
        final isActionable = status == 'pending' || status == 'assigned' || status == 'carry_forward';
        final dateStr = DateFormat('EEE, dd MMM yyyy').format(DateTime.parse(d['scheduled_date']));

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
                    _buildDeliveryBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                if (d['is_carry_forward'] == true)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('Carry-forward rescheduled delivery', style: TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                if (isActionable) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple,
                        elevation: 0,
                        minimumSize: const Size(100, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 14),
                      label: const Text('Skip Day', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _skipDeliveryDay(d['id']?.toString() ?? ''),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeliveryBadge(String status) {
    Color bg = Colors.grey.shade50;
    Color fg = AppTheme.textSecondary;
    String label = status.replaceAll('_', ' ').toUpperCase();

    if (status == 'delivered') {
      bg = Colors.green.shade50;
      fg = AppTheme.success;
    } else if (status == 'pending') {
      bg = Colors.amber.shade50;
      fg = AppTheme.warning;
    } else if (status == 'out_for_delivery') {
      bg = Colors.purple.shade50;
      fg = Colors.purple;
    } else if (status == 'missed') {
      bg = Colors.red.shade50;
      fg = AppTheme.error;
    } else if (status == 'skipped') {
      bg = Colors.grey.shade200;
      fg = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  Widget _buildAuditLogsTab() {
    final statusLogs = (_subDetail?['status_history'] as List? ?? []).cast<Map<String, dynamic>>();
    final pauseLogs = (_subDetail?['pause_history'] as List? ?? []).cast<Map<String, dynamic>>();
    final paymentLogs = (_subDetail?['payment_history'] as List? ?? []).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Status Changes History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (statusLogs.isEmpty)
          const Text('No status transitions logged', style: TextStyle(fontSize: 12, color: AppTheme.textLight))
        else
          ...statusLogs.map((log) => _buildTimelineTile(
                title: '${log['old_status'].toString().toUpperCase()} → ${log['new_status'].toString().toUpperCase()}',
                subtitle: log['reason'] ?? 'No reason provided',
                date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(log['changed_at'])),
                icon: Icons.swap_horiz,
                color: AppTheme.primaryGreen,
              )),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Pause Durations History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (pauseLogs.isEmpty)
          const Text('No pause entries logged', style: TextStyle(fontSize: 12, color: AppTheme.textLight))
        else
          ...pauseLogs.map((log) => _buildTimelineTile(
                title: 'Paused duration: ${log['paused_days']} day(s)',
                subtitle: 'Reason: ${log['pause_reason'] ?? '—'}\nResumed at: ${log['resumed_at'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(log['resumed_at'])) : 'Ongoing'}',
                date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(log['paused_at'])),
                icon: Icons.pause_circle_filled_rounded,
                color: AppTheme.warning,
              )),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),

        const Text('Payment History Logs', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (paymentLogs.isEmpty)
          const Text('No payments recorded', style: TextStyle(fontSize: 12, color: AppTheme.textLight))
        else
          ...paymentLogs.map((log) => _buildTimelineTile(
                title: 'Amount: ₹${log['amount']} (${log['status'].toString().toUpperCase()})',
                subtitle: 'Transaction ID: ${log['transaction_id'] ?? '—'}',
                date: DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(log['changed_at'])),
                icon: Icons.payment,
                color: AppTheme.info,
              )),
      ],
    );
  }

  Widget _buildTimelineTile({
    required String title,
    required String subtitle,
    required String date,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
