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
    
    // Construct Google Maps URL with waypoints
    final firstStop = stops.first;
    final lastStop = stops.last;
    
    // Simple maps link for the first stop if only one, or waypoints
    // Google Maps dir format: https://www.google.com/maps/dir/?api=1&origin=Current+Location&destination=lat,lng&waypoints=lat1,lng1|lat2,lng2
    
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid coordinates available for routing.')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Optimization'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRoute),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _routeData == null || (_routeData!['stops'] as List).isEmpty
              ? const Center(child: Text('No active stops to route.'))
              : _buildRouteContent(),
      floatingActionButton: _routeData != null && (_routeData!['stops'] as List).isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _launchRouteInMaps(_routeData!['stops'] as List),
              icon: const Icon(Icons.navigation),
              label: const Text('Start Navigation'),
              backgroundColor: AppTheme.primaryGreen,
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
          padding: const EdgeInsets.all(16),
          color: AppTheme.primaryGreen.withOpacity(0.1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Total Distance', style: TextStyle(color: Colors.grey)),
                  Text('${distance.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Column(
                children: [
                  const Text('Est. Time', style: TextStyle(color: Colors.grey)),
                  Text('$time mins', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              Column(
                children: [
                  const Text('Total Stops', style: TextStyle(color: Colors.grey)),
                  Text('${stops.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryGreen,
                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
                ),
                title: Text(stop['customer_name'] ?? ''),
                subtitle: Text(stop['delivery_address'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.location_on, color: Colors.grey),
              );
            },
          ),
        ),
      ],
    );
  }
}
