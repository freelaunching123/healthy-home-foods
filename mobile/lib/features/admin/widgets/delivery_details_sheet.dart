import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> details;

  const DeliveryDetailsSheet({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final customer = details['customer'] ?? {};
    final address = details['address'] ?? {};
    final timeline = List<Map<String, dynamic>>.from(details['timeline'] ?? []);
    final partner = details['delivery_partner'];
    
    final lat = address['latitude'];
    final lng = address['longitude'];
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DefaultTabController(
        length: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TabBar(
              labelColor: AppTheme.primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryGreen,
              tabs: [
                Tab(text: 'Details & Timeline'),
                Tab(text: 'Map View'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDetailsTab(customer, address, timeline, partner),
                  _buildMapTab(lat, lng, partner),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(
      Map<String, dynamic> customer,
      Map<String, dynamic> address,
      List<Map<String, dynamic>> timeline,
      Map<String, dynamic>? partner) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Customer Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Name: ${customer['full_name'] ?? 'Unknown'}'),
        Text('Phone: ${customer['phone'] ?? 'N/A'}'),
        Text('Address: ${address['address_line1'] ?? ''} ${address['address_line2'] ?? ''} ${address['city'] ?? ''}'),
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),
        
        if (partner != null) ...[
          const Text('Assigned Partner', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Name: ${partner['full_name'] ?? 'Unknown'}'),
          Text('ID: ${partner['employee_code'] ?? 'N/A'}'),
          Text('Vehicle: ${partner['vehicle_type'] ?? 'N/A'} - ${partner['vehicle_number'] ?? 'N/A'}'),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
        ],

        const Text('Delivery Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...timeline.map((event) {
          final timestamp = event['timestamp'] != null 
              ? DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(event['timestamp']).toLocal()) 
              : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 30,
                      color: Colors.grey[300],
                    )
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['status'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (event['description'] != null)
                        Text(event['description'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(timestamp, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMapTab(dynamic lat, dynamic lng, Map<String, dynamic>? partner) {
    if (lat == null || lng == null) {
      return const Center(
        child: Text('Coordinates not available for map preview.'),
      );
    }
    
    final customerPos = LatLng(lat, lng);
    final partnerPos = partner != null && partner['current_lat'] != null && partner['current_lng'] != null 
        ? LatLng(partner['current_lat'], partner['current_lng']) 
        : null;

    return FlutterMap(
      options: MapOptions(
        initialCenter: customerPos,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.healthyhomefoods',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: customerPos,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
            if (partnerPos != null)
              Marker(
                point: partnerPos,
                width: 40,
                height: 40,
                child: const Icon(Icons.local_shipping, color: Colors.blue, size: 40),
              ),
          ],
        ),
      ],
    );
  }
}
