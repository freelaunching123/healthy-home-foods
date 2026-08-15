import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryPartnerProfileScreen extends StatefulWidget {
  final String partnerId;
  final Map<String, dynamic>? initialData;

  const DeliveryPartnerProfileScreen({
    super.key,
    required this.partnerId,
    this.initialData,
  });

  @override
  State<DeliveryPartnerProfileScreen> createState() =>
      _DeliveryPartnerProfileScreenState();
}

class _DeliveryPartnerProfileScreenState
    extends State<DeliveryPartnerProfileScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  Map<String, dynamic>? _data;
  List<dynamic> _deliveries = [];
  bool _isLoading = true;
  bool _isDeliveriesLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _data = widget.initialData;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _isDeliveriesLoading = true;
    });
    try {
      final res = await _api.get('/delivery-partners/${widget.partnerId}');
      setState(() => _data = res.data as Map<String, dynamic>);
      
      // Fetch deliveries assigned to the partner
      final delRes = await _api.get('/admin/deliveries', queryParameters: {
        'delivery_partner_id': widget.partnerId,
        'start_date': '2020-01-01',
        'end_date': '2030-12-31',
      });
      setState(() {
        _deliveries = delRes.data is List ? delRes.data : [];
      });
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isDeliveriesLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: _isLoading && data == null
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            )
          : data == null
              ? _ErrorView(onRetry: _load)
              : CustomScrollView(
                  slivers: [
                    // Profile header sliver
                    _ProfileHeader(data: data),

                    // Info cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            _InfoSection(data: data),
                            const SizedBox(height: 16),
                            _StatsSection(data: data),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),

                    // Tabs header
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        TabBar(
                          controller: _tabController,
                          labelColor: AppTheme.primaryGreen,
                          unselectedLabelColor: AppTheme.textSecondary,
                          indicatorColor: AppTheme.primaryGreen,
                          indicatorSize: TabBarIndicatorSize.tab,
                          tabs: const [
                            Tab(text: 'Overview'),
                            Tab(text: 'Completed'),
                            Tab(text: 'Pending'),
                          ],
                        ),
                      ),
                    ),

                    // Tab content
                    SliverFillRemaining(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _OverviewTab(data: data),
                          _DeliveryListTab(
                            deliveries: _deliveries.where((d) => d['status'] == 'delivered' || d['status'] == 'failed' || d['status'] == 'missed').toList(),
                            isLoading: _isDeliveriesLoading,
                            label: 'completed',
                            color: AppTheme.success,
                          ),
                          _DeliveryListTab(
                            deliveries: _deliveries.where((d) => d['status'] != 'delivered' && d['status'] != 'failed' && d['status'] != 'missed').toList(),
                            isLoading: _isDeliveriesLoading,
                            label: 'pending',
                            color: AppTheme.warning,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ProfileHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final isActive = data['is_active'] as bool? ?? true;
    final photoUrl = data['photo_url'] as String?;
    final name = data['full_name'] ?? 'Unknown';

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      backgroundColor: AppTheme.primaryGreen,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: photoUrl != null
                          ? NetworkImage('${ApiClient().mediaBaseUrl}$photoUrl')
                          : null,
                      child: photoUrl == null
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isActive ? AppTheme.success : Colors.grey.shade400,
                          border:
                              Border.all(color: Colors.white, width: 2.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data['employee_code'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.success
                            : Colors.grey.shade500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Info Section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InfoSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Personal Information',
      icon: Icons.person_outline_rounded,
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile',
            value: data['mobile_number'] ?? '-',
          ),
          _InfoRow(
            icon: Icons.cake_outlined,
            label: 'Age',
            value: data['age'] != null ? '${data['age']} years' : '-',
          ),
          _InfoRow(
            icon: Icons.wc_outlined,
            label: 'Gender',
            value: data['gender'] ?? '-',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

// ── Stats Section ─────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    final completed = data['completed_deliveries'] ?? 0;
    final pending = data['pending_deliveries'] ?? 0;
    final total = data['total_deliveries'] ?? 0;
    final rating = data['rating'];

    return _Card(
      title: 'Delivery Statistics',
      icon: Icons.bar_chart_rounded,
      child: Row(
        children: [
          _StatCell(
            label: 'Completed',
            value: '$completed',
            color: AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
          _Divider(),
          _StatCell(
            label: 'Pending',
            value: '$pending',
            color: AppTheme.warning,
            icon: Icons.pending_outlined,
          ),
          _Divider(),
          _StatCell(
            label: 'Total',
            value: '$total',
            color: AppTheme.info,
            icon: Icons.local_shipping_outlined,
          ),
          _Divider(),
          _StatCell(
            label: 'Rating',
            value: rating != null ? rating.toStringAsFixed(1) : 'N/A',
            color: AppTheme.warning,
            icon: Icons.star_outline,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.shade200,
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Tab content ───────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final createdAt = data['created_at'] as String?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          title: 'Account Details',
          icon: Icons.info_outline_rounded,
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Employee Code',
                value: data['employee_code'] ?? '-',
              ),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Joined',
                value: createdAt != null
                    ? createdAt.substring(0, 10)
                    : '-',
              ),
              _InfoRow(
                icon: Icons.circle_outlined,
                label: 'Status',
                value: (data['is_active'] as bool? ?? true)
                    ? 'Active'
                    : 'Inactive',
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeliveryListTab extends StatelessWidget {
  final List<dynamic> deliveries;
  final bool isLoading;
  final String label;
  final Color color;
  
  const _DeliveryListTab({
    required this.deliveries,
    required this.isLoading,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: color));
    }

    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 56,
              color: color.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No $label deliveries',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Delivery history will appear here',
              style: TextStyle(fontSize: 13, color: AppTheme.textLight),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final d = deliveries[index];
        final isDelivered = d['status'] == 'delivered';
        final isFailed = d['status'] == 'missed' || d['status'] == 'failed';
        final statusText = d['status'].toString().toUpperCase();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['customer_name'] ?? 'Unknown Customer',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d['delivery_address'] ?? '',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${d['scheduled_date'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          Text(
                            'Slot: ${d['delivery_time'] ?? 'Standard'}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDelivered 
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1) 
                        : isFailed 
                            ? Colors.red.withValues(alpha: 0.1) 
                            : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDelivered 
                          ? AppTheme.primaryGreen 
                          : isFailed 
                              ? Colors.red 
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Card({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.textLight),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: AppTheme.error),
          const SizedBox(height: 12),
          const Text('Failed to load profile'),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ── Tab bar delegate ──────────────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
