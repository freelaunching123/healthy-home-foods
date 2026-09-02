import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();

  // Active/paused subscriptions list
  List<dynamic> _currentSubs = [];

  // All subscriptions history
  List<dynamic> _allSubs = [];

  bool _isLoadingCurrent = true;
  bool _isLoadingAll = true;
  bool _isActionInProgress = false;

  late TabController _historyTabController;
  final _historyStatuses = ['active', 'paused', 'completed', 'cancelled'];

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _historyTabController = TabController(length: _historyStatuses.length, vsync: this);
    _loadAll();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _historyTabController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted && !_isActionInProgress) {
        _loadAll(isSilent: true);
      }
    });
  }

  Future<void> _loadAll({bool isSilent = false}) async {
    await Future.wait([
      _loadCurrentSubscriptions(isSilent: isSilent),
      _loadAllSubscriptions(isSilent: isSilent)
    ]);
  }

  Future<void> _loadCurrentSubscriptions({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoadingCurrent = true);
    try {
      final res = await _api.get(ApiConstants.subscriptions);
      if (res.data is List) {
        final all = res.data as List;
        final activeList = all.where((s) {
          final st = (s['status'] ?? '').toString().toLowerCase();
          return st == 'active' || st == 'paused';
        }).toList();
        setState(() => _currentSubs = activeList);
      } else {
        setState(() => _currentSubs = []);
      }
    } catch (e) {
      setState(() => _currentSubs = []);
    } finally {
      if (!isSilent) setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _loadAllSubscriptions({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoadingAll = true);
    try {
      final res = await _api.get(ApiConstants.subscriptions);
      setState(() => _allSubs = res.data is List ? res.data : []);
    } catch (_) {
      setState(() => _allSubs = []);
    } finally {
      if (!isSilent) setState(() => _isLoadingAll = false);
    }
  }

  Future<void> _pauseSubscription(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Pause Subscription?'),
          ],
        ),
        content: const Text(
          'If you click pause today, you will not receive today\'s delivery. Are you sure you want to pause?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warning,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Yes, Pause'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/pause', data: {'reason': 'User requested'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription paused'), backgroundColor: AppTheme.success),
        );
      }
      await _loadAll();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pause'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _resumeSubscription(String id) async {
    setState(() => _isActionInProgress = true);
    try {
      await _api.post('${ApiConstants.subscriptions}/$id/resume');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription resumed'), backgroundColor: AppTheme.success),
        );
      }
      await _loadAll();
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to resume';
        if (e is DioException && e.response?.data != null && e.response!.data['detail'] != null) {
          msg = e.response!.data['detail'].toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
      try {
        await launchUrl(launchUri);
      } catch (_) {}
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return AppTheme.success;
      case 'paused': return AppTheme.warning;
      case 'cancelled': return AppTheme.error;
      case 'completed': return AppTheme.info;
      default: return AppTheme.textSecondary;
    }
  }

  String _formatDate(String? iso, {String format = 'MMM dd, yyyy'}) {
    if (iso == null) return '—';
    try {
      return DateFormat(format).format(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }

  String _getProductName(Map<String, dynamic> sub) {
    if (sub['product_name'] != null && sub['product_name'] != '—') {
      return sub['product_name'];
    }
    if (sub['product'] != null && sub['product']['name'] != null) {
      return sub['product']['name'];
    }
    if (sub['items'] != null && sub['items'] is List && (sub['items'] as List).isNotEmpty) {
      final items = sub['items'] as List;
      final firstItem = items[0] is Map ? items[0] as Map<String, dynamic> : <String, dynamic>{};
      final firstProductName = firstItem['product_name'] ?? firstItem['product']?['name'] ?? 'Item';
      if (items.length == 1) {
        return firstProductName;
      }
      return '$firstProductName + ${items.length - 1} other(s)';
    }
    if (sub['package_name'] != null && sub['package_name'] != '—') {
      return sub['package_name'];
    }
    if (sub['plan_name'] != null && sub['plan_name'] != '—') {
      return sub['plan_name'];
    }
    return 'Custom Package';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Subscriptions'),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current Active/Paused Subscriptions ──────────────────────────
            _isLoadingCurrent
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                  ))
                : _currentSubs.isEmpty
                    ? _buildNoActivePlan()
                    : Column(
                        children: _currentSubs.map((sub) {
                          final mapData = sub is Map ? Map<String, dynamic>.from(sub) : <String, dynamic>{};
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildSingleSubscriptionCard(mapData),
                          );
                        }).toList(),
                      ),

            const SizedBox(height: 12),
            // ── All Plans History ──────────────────────────────────────
            const Text(
              'All Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  // ── Single Subscription card ─────────────────────────────────────────────

  Widget _buildSingleSubscriptionCard(Map<String, dynamic> sub) {
    final status = (sub['status'] ?? 'unknown').toString();
    final statusColor = _statusColor(status);
    final total = sub['total_deliveries'] ?? 0;
    final completed = sub['completed_deliveries'] ?? 0;
    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
    final subId = sub['id']?.toString();

    return Column(
      children: [
        // Main Info Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getProductName(sub),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          if (sub['plan_name'] != null && sub['plan_name'].toString().isNotEmpty && sub['plan_name'] != '—') ...[
                            const SizedBox(height: 4),
                            Text(
                              '${sub['plan_name']} · ${(sub['plan_type'] ?? '').toString().toUpperCase()}',
                              style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Range
                Row(
                  children: [
                    Expanded(
                      child: _buildDateChip(
                        Icons.play_circle_outline,
                        'Started',
                        _formatDate(sub['start_date']),
                        AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDateChip(
                        Icons.stop_circle_outlined,
                        'Ends',
                        _formatDate(sub['expected_end_date']),
                        AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Delivery Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Progress',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    Text(
                      '$completed / $total',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                  ),
                ),

                // Next Delivery Date
                if (sub['next_delivery_date'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryGreen.withValues(alpha: 0.08), AppTheme.primaryGreen.withValues(alpha: 0.04)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, color: AppTheme.primaryGreen, size: 18),
                        const SizedBox(width: 10),
                        const Text('Next Delivery:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(width: 6),
                        Text(
                          _formatDate(sub['next_delivery_date'], format: 'EEE, MMM dd'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Today's Delivery Card (if exists)
        if (sub['today_delivery'] != null)
          _buildTodayDeliveryCard(sub['today_delivery'], subId),

        const SizedBox(height: 12),

        // Stats Row
        _buildDeliveryStatsRow(sub),

        const SizedBox(height: 12),

        // Action Buttons
        if (_isActionInProgress)
          const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
        else
          _buildActionButtons(sub, subId),
      ],
    );
  }

  Widget _buildDateChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildTodayDeliveryCard(Map<String, dynamic> delivery, String? subId) {
    final deliveryStatus = (delivery['status'] ?? 'pending').toString();
    final partnerName = delivery['partner_name'] as String?;
    final partnerPhone = delivery['partner_phone'] as String?;
    final eta = delivery['estimated_minutes'] as int?;
    final deliveryId = delivery['delivery_id'] as String?;

    Color statusColor;
    IconData statusIcon;
    switch (deliveryStatus) {
      case 'out_for_delivery':
        statusColor = AppTheme.outForDelivery;
        statusIcon = Icons.delivery_dining;
        break;
      case 'delivered':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'assigned':
        statusColor = AppTheme.warning;
        statusIcon = Icons.assignment_ind_outlined;
        break;
      default:
        statusColor = AppTheme.textSecondary;
        statusIcon = Icons.hourglass_empty;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, size: 18, color: statusColor),
                ),
                const SizedBox(width: 10),
                Text(
                  "Today's Delivery",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    deliveryStatus.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            if (partnerName != null || eta != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            if (partnerName != null)
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, size: 20, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(partnerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        if (partnerPhone != null)
                          Text(partnerPhone, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (partnerPhone != null)
                    IconButton(
                      icon: const Icon(Icons.phone_rounded, color: AppTheme.primaryGreen),
                      onPressed: () => _makePhoneCall(partnerPhone),
                      tooltip: 'Call Delivery Partner',
                    ),
                ],
              ),
            if (eta != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'ETA: ~$eta minutes',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
            if (deliveryId != null && deliveryStatus == 'out_for_delivery') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/tracking/$deliveryId'),
                  icon: const Icon(Icons.location_on, size: 18),
                  label: const Text('Live Track Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'No active delivery tracking available.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryStatsRow(Map<String, dynamic> sub) {
    return Row(
      children: [
        Expanded(child: _buildStatChip('Remaining', '${sub['remaining_deliveries'] ?? 0}', AppTheme.info)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('Paused Days', '${sub['paused_days'] ?? 0}', AppTheme.warning)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('Missed', '${sub['missed_deliveries'] ?? 0}', AppTheme.error)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatChip('Carry Fwd', '${sub['carry_forward_deliveries'] ?? 0}', Colors.purple)),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> sub, String? subId) {
    final status = (sub['status'] ?? '').toString().toLowerCase();
    if (subId == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            if (status == 'active')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pauseSubscription(subId),
                  icon: const Icon(Icons.pause, size: 18),
                  label: const Text('Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warning,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            if (status == 'paused')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _resumeSubscription(subId),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Resume'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push('/delivery-calendar/$subId'),
                icon: const Icon(Icons.calendar_month_outlined, size: 18, color: AppTheme.primaryGreen),
                label: const Text('Calendar'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: const BorderSide(color: AppTheme.primaryGreen),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => context.push('/profile/subscription/$subId'),
              child: const Text(
                'View Full Details →',
                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── History Section ───────────────────────────────────────────────────────

  Widget _buildHistorySection() {
    return Column(
      children: [
        // Filter Tabs
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TabBar(
            controller: _historyTabController,
            indicator: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondary,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: _historyStatuses.map((s) {
              return Tab(text: s[0].toUpperCase() + s.substring(1));
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: _isLoadingAll
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
              : TabBarView(
                  controller: _historyTabController,
                  children: _historyStatuses.map((status) {
                    final filtered = _allSubs.where((s) {
                      return (s['status'] ?? '').toString().toLowerCase() == status;
                    }).toList();
                    return filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No ${status} plans',
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) => _buildHistoryCard(filtered[idx]),
                          );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> sub) {
    final status = (sub['status'] ?? 'unknown').toString();
    final color = _statusColor(status);
    final startDate = _formatDate(sub['start_date']);
    final endDate = _formatDate(sub['expected_end_date']);
    final total = sub['total_deliveries'] ?? 0;
    final completed = sub['completed_deliveries'] ?? 0;

    return InkWell(
      onTap: () => context.push('/profile/subscription/${sub['id']}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.restaurant_menu_outlined, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getProductName(sub),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$startDate → $endDate',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$completed / $total deliveries',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoActivePlan() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant_menu_outlined, size: 48, color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 20),
            const Text('No Active Plans', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Subscribe to a healthy meal plan to get\nfresh food delivered daily.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.explore_outlined),
              label: const Text('Explore Plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(180, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
