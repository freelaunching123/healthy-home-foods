import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

// ── Session definitions ────────────────────────────────────────────────────────
class _Session {
  final String label;
  final IconData icon;
  final Color color;
  const _Session({required this.label, required this.icon, required this.color});
}

const _sessions = [
  _Session(label: 'Morning',   icon: Icons.wb_sunny_outlined,     color: Color(0xFFF59E0B)),
  _Session(label: 'Afternoon', icon: Icons.wb_cloudy_outlined,    color: Color(0xFFEF4444)),
  _Session(label: 'Evening',   icon: Icons.nights_stay_outlined,  color: Color(0xFF6366F1)),
];

// ── Widget ────────────────────────────────────────────────────────────────────
class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen>
    with WidgetsBindingObserver {
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  List<dynamic> _activeDeliveries = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  // Selected session filter — null means "show all"
  String? _selectedSession;

  // ── Computed helpers ────────────────────────────────────────────────────────

  /// Sessions that actually have at least one active delivery
  List<String> get _availableSessions {
    final sessions = <String>{};
    for (final d in _activeDeliveries) {
      final t = _normalizeSession(d['scheduled_time'] as String? ?? '');
      if (t != null) sessions.add(t);
    }
    // Return in canonical order
    return _sessions
        .map((s) => s.label)
        .where((l) => sessions.contains(l))
        .toList();
  }

  /// Active deliveries after applying the session filter
  List<dynamic> get _filteredDeliveries {
    if (_selectedSession == null) return _activeDeliveries;
    return _activeDeliveries.where((d) {
      return _normalizeSession(d['scheduled_time'] as String? ?? '') == _selectedSession;
    }).toList();
  }

  /// Normalise a raw scheduled_time string → 'Morning' | 'Afternoon' | 'Evening' | null
  String? _normalizeSession(String raw) {
    final lower = raw.toLowerCase().split(' (')[0].trim();
    if (lower == 'morning') return 'Morning';
    if (lower == 'afternoon') return 'Afternoon';
    if (lower == 'evening') return 'Evening';
    return null;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final statsRes  = await _api.get(ApiConstants.partnerDashboard);
      final activeRes = await _api.get(ApiConstants.partnerActiveDeliveries);

      if (mounted) {
        setState(() {
          _stats            = statsRes.data;
          _activeDeliveries = activeRes.data is List ? activeRes.data : [];

          // If the previously-selected session no longer has orders, clear filter
          if (_selectedSession != null &&
              !_availableSessions.contains(_selectedSession)) {
            _selectedSession = null;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard: $e');
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String assignmentId, String newStatus) async {
    setState(() {
      if (newStatus == 'delivered' || newStatus == 'failed') {
        _activeDeliveries.removeWhere((item) => item['id'] == assignmentId);
      } else {
        final idx = _activeDeliveries.indexWhere((item) => item['id'] == assignmentId);
        if (idx != -1) _activeDeliveries[idx]['status'] = newStatus;
      }
    });

    try {
      await _api.put(ApiConstants.partnerUpdateStatus(assignmentId),
          data: {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newStatus == 'out_for_delivery'
              ? 'Delivery started successfully!'
              : 'Status updated to $newStatus'),
          backgroundColor: AppTheme.success,
          duration: const Duration(seconds: 1),
        ));
      }
      _loadData(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to update status'),
          backgroundColor: AppTheme.error,
        ));
      }
      _loadData(silent: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Performance",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildStatsSection(),
                  const SizedBox(height: 32),

                  // ── Active deliveries header ──────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Current Active Deliveries',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/delivery/active'),
                        child: const Text('View All'),
                      ),
                    ],
                  ),

                  // ── Session filter chips (only when sessions available) ───
                  if (_availableSessions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSessionFilter(),
                  ],

                  const SizedBox(height: 8),
                  _buildActiveDeliveriesList(),
                ],
              ),
            ),
    );
  }

  // ── Session filter chips ────────────────────────────────────────────────────
  Widget _buildSessionFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          _SessionChip(
            label: 'All',
            icon: Icons.all_inbox_outlined,
            color: AppTheme.primaryGreen,
            count: _activeDeliveries.length,
            selected: _selectedSession == null,
            onTap: () => setState(() => _selectedSession = null),
          ),
          const SizedBox(width: 8),
          // Per-session chips — only sessions that have deliveries
          ..._availableSessions.map((sessionLabel) {
            final meta = _sessions.firstWhere((s) => s.label == sessionLabel);
            final count = _activeDeliveries
                .where((d) =>
                    _normalizeSession(d['scheduled_time'] as String? ?? '') ==
                    sessionLabel)
                .length;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SessionChip(
                label: sessionLabel,
                icon: meta.icon,
                color: meta.color,
                count: count,
                selected: _selectedSession == sessionLabel,
                onTap: () => setState(() => _selectedSession = sessionLabel),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Active deliveries list ──────────────────────────────────────────────────
  Widget _buildActiveDeliveriesList() {
    final deliveries = _filteredDeliveries;

    if (_activeDeliveries.isEmpty) {
      return _buildEmptyState(
        icon: Icons.task_alt_rounded,
        title: "Today's Deliveries Completed!",
        subtitle:
            'All package deliveries for today are complete. Next delivery will show tomorrow.',
      );
    }

    if (deliveries.isEmpty && _selectedSession != null) {
      final meta = _sessions.firstWhere((s) => s.label == _selectedSession);
      return _buildEmptyState(
        icon: meta.icon,
        color: meta.color,
        title: 'No $_selectedSession Deliveries',
        subtitle: 'No active deliveries scheduled for the $_selectedSession session.',
      );
    }

    final showCount = deliveries.length > 3 ? 3 : deliveries.length;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: showCount,
      itemBuilder: (context, index) => _buildDeliveryCard(deliveries[index]),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Color color = AppTheme.primaryGreen,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final orderType =
        delivery['order_type'] == 'fruit' ? 'Grocery Order' : 'Subscription';
    final statusVal = delivery['status'] as String? ?? '';
    final isOutForDelivery = statusVal == 'out_for_delivery';
    final session = _normalizeSession(delivery['scheduled_time'] as String? ?? '');
    final sessionMeta =
        session != null ? _sessions.firstWhere((s) => s.label == session) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row: order-id + status badge ──────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Order ID: ${delivery['order_id'] ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOutForDelivery
                        ? Colors.orange.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOutForDelivery ? 'OUT FOR DELIVERY' : 'ASSIGNED',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOutForDelivery ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Customer row ──────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      AppTheme.primaryGreen.withValues(alpha: 0.1),
                  child:
                      const Icon(Icons.person, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery['customer_name'] ?? 'Unknown',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderType,
                        style: const TextStyle(
                            color: AppTheme.textLight, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Session badge
                if (sessionMeta != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sessionMeta.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sessionMeta.icon,
                            size: 13, color: sessionMeta.color),
                        const SizedBox(width: 4),
                        Text(
                          sessionMeta.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: sessionMeta.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Address ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    delivery['delivery_address'] ?? '',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Delivery time ─────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.access_time_outlined,
                    size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Delivery Time: ${delivery['scheduled_time'] ?? 'Morning'}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final delivered = await context
                          .push<bool>('/delivery/order/${delivery['id']}');
                      if (delivered == true && mounted) {
                        _loadData(silent: true);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.primaryGreen),
                    ),
                    child: const Text('View Details',
                        style: TextStyle(color: AppTheme.primaryGreen)),
                  ),
                ),
                if (!isOutForDelivery) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _updateStatus(delivery['id'], 'out_for_delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Start Delivery'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats section (unchanged) ───────────────────────────────────────────────
  Widget _buildStatsSection() {
    if (_stats == null) return const SizedBox.shrink();

    return Column(
      children: [
        _buildStatCard(
          'Today Deliveries',
          _stats!['assigned_today']?.toString() ?? '0',
          Icons.assignment_outlined,
          Colors.blue,
          isHero: true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Completed Today',
                _stats!['completed_today']?.toString() ?? '0',
                Icons.check_circle_outline,
                AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Pending Today',
                _stats!['pending_deliveries']?.toString() ?? '0',
                Icons.pending_actions_outlined,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color,
      {bool isHero = false}) {
    if (isHero) {
      return Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(value,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ── Reusable Session Chip ─────────────────────────────────────────────────────
class _SessionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SessionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.3)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
