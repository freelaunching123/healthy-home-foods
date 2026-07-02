import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  final String deliveryId;
  const TrackingScreen({super.key, required this.deliveryId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _api = ApiClient();
  final MapController _mapController = MapController();
  
  Map<String, dynamic>? _trackingData;
  LatLng? _driverLocation;
  LatLng? _customerLocation;
  List<Marker> _markers = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Default location (e.g. city center)
    _customerLocation = const LatLng(13.0827, 80.2707); // Chennai mock
    _loadTrackingData();
    
    // Poll for updates every 10 seconds since WebSocket is not fully setup in this mock
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadTrackingData(isRefresh: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTrackingData({bool isRefresh = false}) async {
    if (!isRefresh) setState(() => _isLoading = true);
    
    try {
      final res = await _api.get('${ApiConstants.gpsTrack}/${widget.deliveryId}');
      if (res.data != null) {
        final data = res.data;
        setState(() {
          _trackingData = data;
          if (data['latitude'] != null && data['longitude'] != null) {
            _driverLocation = LatLng(data['latitude'], data['longitude']);
            _updateMarkers();
            _animateToDriver();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading tracking: $e');
    } finally {
      if (!isRefresh) setState(() => _isLoading = false);
    }
  }

  void _updateMarkers() {
    final markers = <Marker>[];
    
    if (_customerLocation != null) {
      markers.add(Marker(
        point: _customerLocation!,
        child: const Icon(
          Icons.location_on,
          color: Colors.green,
          size: 40,
        ),
      ));
    }
    
    if (_driverLocation != null) {
      markers.add(Marker(
        point: _driverLocation!,
        child: const Icon(
          Icons.directions_car_rounded,
          color: Colors.orange,
          size: 40,
        ),
      ));
    }
    
    setState(() {
      _markers = markers;
    });
  }

  Future<void> _animateToDriver() async {
    if (_driverLocation == null) return;
    try {
      _mapController.move(_driverLocation!, 15.0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : Column(
              children: [
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _driverLocation ?? _customerLocation ?? const LatLng(13.0827, 80.2707),
                      initialZoom: 14.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.healthyhomefoods.app',
                      ),
                      MarkerLayer(
                        markers: _markers,
                      ),
                    ],
                  ),
                ),
                _buildTrackingInfoPanel(),
              ],
            ),
    );
  }

  Widget _buildTrackingInfoPanel() {
    final estMinutes = _trackingData?['estimated_minutes'] ?? '--';
    final driverName = _trackingData?['delivery_partner_name'] ?? 'Delivery Agent';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Estimated Arrival', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('$estMinutes mins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.accentLight,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const Text('Delivery Partner', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.phone, color: AppTheme.primaryGreen),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling driver...')));
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
