import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

// ── Session meta (mirrors delivery_dashboard_screen.dart) ─────────────────────
class _Session {
  final String label;
  final IconData icon;
  final Color color;
  const _Session({required this.label, required this.icon, required this.color});
}

const _sessions = [
  _Session(label: 'Morning',   icon: Icons.wb_sunny_outlined,    color: Color(0xFFF59E0B)),
  _Session(label: 'Afternoon', icon: Icons.wb_cloudy_outlined,   color: Color(0xFFEF4444)),
  _Session(label: 'Evening',   icon: Icons.nights_stay_outlined, color: Color(0xFF6366F1)),
];

// ── Widget ────────────────────────────────────────────────────────────────────
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> with WidgetsBindingObserver {
  final _api = ApiClient();
  Map<String, dynamic>? _routeData;
  bool _isLoading = true;

  /// Selected session — null = show all stops
  String? _selectedSession;

  // ── Computed helpers ────────────────────────────────────────────────────────

  List<dynamic> get _allStops =>
      _routeData == null ? [] : (_routeData!['stops'] as List? ?? []);

  /// Sessions that have at least one stop
  List<String> get _availableSessions {
    final set = <String>{};
    for (final s in _allStops) {
      final t = _normalizeSession(s['scheduled_time'] as String? ?? '');
      if (t != null) set.add(t);
    }
    return _sessions.map((s) => s.label).where((l) => set.contains(l)).toList();
  }

  /// Stops visible after applying the session filter
  List<dynamic> get _filteredStops {
    if (_selectedSession == null) return _allStops;
    return _allStops.where((s) {
      return _normalizeSession(s['scheduled_time'] as String? ?? '') == _selectedSession;
    }).toList();
  }

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
    _loadRoute();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadRoute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Data ────────────────────────────────────────────────────────────────────

  Future<void> _loadRoute() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.partnerRoute);
      setState(() {
        _routeData = res.data;
        // Reset filter if selected session no longer exists
        if (_selectedSession != null &&
            !_availableSessions.contains(_selectedSession)) {
          _selectedSession = null;
        }
      });
    } catch (e) {
      debugPrint('Error loading route: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Maps helpers ────────────────────────────────────────────────────────────

  Future<void> _launchRouteInMaps(List<dynamic> stops) async {
    if (stops.isEmpty) return;

    final waypoints = StringBuffer();
    for (int i = 0; i < stops.length - 1; i++) {
      final stop = stops[i];
      if (stop['latitude'] != null && stop['longitude'] != null) {
        if (waypoints.isNotEmpty) waypoints.write('|');
        waypoints.write('${stop['latitude']},${stop['longitude']}');
      }
    }

    final dest = stops.last;
    final destStr = dest['latitude'] != null
        ? '${dest['latitude']},${dest['longitude']}'
        : '';

    if (destStr.isEmpty && waypoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No valid coordinates available for routing.')),
        );
      }
      return;
    }

    String urlStr =
        'https://www.google.com/maps/dir/?api=1&destination=$destStr';
    if (waypoints.isNotEmpty) {
      urlStr += '&waypoints=${waypoints.toString()}';
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  Future<void> _launchSingleMaps(double lat, double lng) async {
    final url =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps')),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredStops;
    final hasStops = filtered.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Route Optimization')),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              color: AppTheme.primaryGreen,
              onRefresh: _loadRoute,
              child: _allStops.isEmpty
                  ? _buildNoStops()
                  : _buildRouteContent(filtered),
            ),
      floatingActionButton: hasStops
          ? FloatingActionButton.extended(
              onPressed: () => _launchRouteInMaps(filtered),
              icon: const Icon(Icons.navigation_outlined),
              label: Text(_selectedSession != null
                  ? 'Navigate $_selectedSession'
                  : 'Start Navigation'),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // ── No-stops empty state ────────────────────────────────────────────────────
  Widget _buildNoStops() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text(
              'No active stops to route.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ── Main route content ──────────────────────────────────────────────────────
  Widget _buildRouteContent(List<dynamic> stops) {
    // Recalculate estimates for the filtered stop count
    final stopCount = stops.length;
    final distance = (_routeData!['total_distance_km'] as num?)?.toDouble() ??
        (stopCount * 2.5);
    // Scale estimate proportionally when filtered
    final allCount = _allStops.length;
    final scaledDistance = allCount > 0
        ? (distance * stopCount / allCount)
        : distance;
    final scaledTime = allCount > 0
        ? (((_routeData!['total_estimated_minutes'] as num?)?.toDouble() ??
                    (allCount * 15.0)) *
                stopCount /
                allCount)
            .round()
        : stopCount * 15;

    return Column(
      children: [
        // ── Summary header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRouteHeaderStat('Distance',
                      '${scaledDistance.toStringAsFixed(1)} km',
                      Icons.directions_car_outlined),
                  _buildRouteHeaderStat(
                      'Est. Time', '$scaledTime mins', Icons.access_time_outlined),
                  _buildRouteHeaderStat(
                      'Stops', '$stopCount', Icons.location_on_outlined),
                ],
              ),

              // ── Session filter chips ──────────────────────────────────
              if (_availableSessions.isNotEmpty) ...[
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _RouteSessionChip(
                        label: 'All',
                        icon: Icons.all_inbox_outlined,
                        color: AppTheme.primaryGreen,
                        count: _allStops.length,
                        selected: _selectedSession == null,
                        onTap: () => setState(() => _selectedSession = null),
                      ),
                      const SizedBox(width: 8),
                      ..._availableSessions.map((sessionLabel) {
                        final meta =
                            _sessions.firstWhere((s) => s.label == sessionLabel);
                        final count = _allStops
                            .where((s) =>
                                _normalizeSession(
                                    s['scheduled_time'] as String? ?? '') ==
                                sessionLabel)
                            .length;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _RouteSessionChip(
                            label: sessionLabel,
                            icon: meta.icon,
                            color: meta.color,
                            count: count,
                            selected: _selectedSession == sessionLabel,
                            onTap: () =>
                                setState(() => _selectedSession = sessionLabel),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Stops list header ───────────────────────────────────────────
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Text(
                _selectedSession != null
                    ? '$_selectedSession Stops'
                    : 'Stops in Optimized Order',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedSession != null)
                Text(
                  '$stopCount of ${_allStops.length} stops',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
            ],
          ),
        ),

        // ── Filtered-stops empty state ─────────────────────────────────
        if (stops.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _sessions
                        .firstWhere((s) => s.label == _selectedSession,
                            orElse: () => _sessions[0])
                        .icon,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No $_selectedSession stops',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            ),
          )
        else
          // ── Stop cards ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: stops.length,
              itemBuilder: (context, index) =>
                  _buildStopCard(stops[index], index),
            ),
          ),
      ],
    );
  }

  // ── Individual stop card ────────────────────────────────────────────────────
  Widget _buildStopCard(Map<String, dynamic> stop, int index) {
    final orderType =
        stop['order_type'] == 'fruit' ? 'Grocery Order' : 'Subscription';
    final lat = stop['latitude'];
    final lng = stop['longitude'];
    final session = _normalizeSession(stop['scheduled_time'] as String? ?? '');
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
            // ── Stop number + name + session badge ────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.primaryGreen,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    stop['customer_name'] ?? 'Unknown Customer',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                // Order type badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    orderType,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                // Session badge
                if (sessionMeta != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: sessionMeta.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sessionMeta.icon,
                            size: 10, color: sessionMeta.color),
                        const SizedBox(width: 3),
                        Text(
                          sessionMeta.label,
                          style: TextStyle(
                              fontSize: 10,
                              color: sessionMeta.color,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // ── Address ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stop['delivery_address'] ?? '',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // ── Scheduled time ────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Delivery Time: ${stop['scheduled_time'] ?? 'Morning'}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Maps button ───────────────────────────────────────────
            if (lat != null && lng != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        _launchSingleMaps(lat.toDouble(), lng.toDouble()),
                    icon: const Icon(Icons.map_outlined,
                        size: 16, color: AppTheme.primaryGreen),
                    label: const Text('Open in Google Maps',
                        style: TextStyle(
                            color: AppTheme.primaryGreen, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      side:
                          const BorderSide(color: AppTheme.primaryGreen),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textLight)),
      ],
    );
  }
}

// ── Route-specific session chip (same visual as dashboard chip) ───────────────
class _RouteSessionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _RouteSessionChip({
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
                size: 15, color: selected ? Colors.white : color),
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
