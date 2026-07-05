import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _routeData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.partnerRoute);
      setState(() {
        _routeData = res.data;
      });
    } catch (e) {
      debugPrint('Error loading route: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchRouteInMaps(List<dynamic> stops) async {
    if (stops.isEmpty) return;
    
    final StringBuffer waypoints = StringBuffer();
    for (int i = 0; i < stops.length - 1; i++) {
      final stop = stops[i];
      if (stop['latitude'] != null && stop['longitude'] != null) {
        if (waypoints.isNotEmpty) waypoints.write('|');
        waypoints.write('${stop['latitude']},${stop['longitude']}');
      }
    }
    
    final dest = stops.last;
    final destStr = dest['latitude'] != null ? '${dest['latitude']},${dest['longitude']}' : '';
    
    if (destStr.isEmpty && waypoints.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid coordinates available for routing.'))
        );
      }
      return;
    }

    String urlStr = 'https://www.google.com/maps/dir/?api=1&destination=$destStr';
    if (waypoints.isNotEmpty) {
      urlStr += '&waypoints=${waypoints.toString()}';
    }

    final url = Uri.parse(urlStr);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps'))
        );
      }
    }
  }

  Future<void> _launchSingleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Maps'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasStops = _routeData != null && (_routeData!['stops'] as List).isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Optimization'),

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : !hasStops
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'No active stops to route.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              : _buildRouteContent(),
      floatingActionButton: hasStops
          ? FloatingActionButton.extended(
              onPressed: () => _launchRouteInMaps(_routeData!['stops'] as List),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Start Navigation'),
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildRouteContent() {
    final stops = _routeData!['stops'] as List;
    final distance = _routeData!['total_distance_km'];
    final time = _routeData!['total_estimated_minutes'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRouteHeaderStat('Total Distance', '${distance.toStringAsFixed(1)} km', Icons.directions_car_outlined),
              _buildRouteHeaderStat('Est. Time', '$time mins', Icons.access_time_outlined),
              _buildRouteHeaderStat('Stops', '${stops.length}', Icons.location_on_outlined),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stops in Optimized Order',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              final orderType = stop['order_type'] == 'fruit' ? 'Fruit Order' : 'Subscription';
              final lat = stop['latitude'];
              final lng = stop['longitude'];
              
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
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              stop['customer_name'] ?? 'Unknown Customer',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              orderType,
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.primaryGreen,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              stop['delivery_address'] ?? '',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Time: ${stop['scheduled_time'] ?? 'Standard (9 AM - 6 PM)'}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (lat != null && lng != null)
                            OutlinedButton.icon(
                              onPressed: () => _launchSingleMaps(lat.toDouble(), lng.toDouble()),
                              icon: const Icon(Icons.map_outlined, size: 16, color: AppTheme.primaryGreen),
                              label: const Text(
                                'Open in Google Maps', 
                                style: TextStyle(color: AppTheme.primaryGreen, fontSize: 12)
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                side: const BorderSide(color: AppTheme.primaryGreen),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                            ),
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
    );
  }

  Widget _buildRouteHeaderStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 16,
            color: AppTheme.textPrimary
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11, 
            color: AppTheme.textLight
          ),
        ),
      ],
    );
  }
}
