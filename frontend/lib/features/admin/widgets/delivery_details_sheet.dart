import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    final products = List<Map<String, dynamic>>.from(details['products'] ?? []);
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
                  _buildDetailsTab(customer, address, timeline, products, partner),
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
      List<Map<String, dynamic>> products,
      Map<String, dynamic>? partner) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (products.isEmpty)
          const Text('No products listed.', style: TextStyle(color: Colors.grey))
        else
          ...products.map((p) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${p['product_name'] ?? p['name']} (x${p['quantity']})'),
                  ),
                ],
              ),
            );
          }),
        
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 16),

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
        if (timeline.isEmpty)
          const Text('No timeline available.', style: TextStyle(color: Colors.grey))
        else
          ...timeline.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final isLast = index == timeline.length - 1;
            
            final stageName = (event['stage'] ?? event['status'] ?? event['title'] ?? 'Stage ${index + 1}').toString();
            final isCompleted = event['completed'] == true || event['timestamp'] != null;
            final description = event['description']?.toString() ?? '';
            
            String? timestampStr;
            if (event['timestamp'] != null) {
              try {
                timestampStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.parse(event['timestamp']).toLocal());
              } catch (_) {
                timestampStr = event['timestamp'].toString();
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: isCompleted ? AppTheme.primaryGreen : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? AppTheme.primaryGreen : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check, size: 10, color: Colors.white)
                            : null,
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 48,
                          color: isCompleted ? AppTheme.primaryGreen.withAlpha(128) : Colors.grey[300],
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stageName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isCompleted ? Colors.black87 : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCompleted ? Colors.green[50] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isCompleted ? Colors.green[200]! : Colors.grey[300]!,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isCompleted ? 'Completed' : 'Pending',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted ? Colors.green[700] : Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              description,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: 3.0),
                          child: Text(
                            timestampStr != null ? 'Time: $timestampStr' : 'Time: Pending / Scheduled',
                            style: TextStyle(
                              color: timestampStr != null ? Colors.grey[700] : Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('customer'),
        position: customerPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
    if (partnerPos != null) {
      markers.add(Marker(
        markerId: const MarkerId('partner'),
        position: partnerPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }

    return GoogleMap(
      mapType: MapType.normal,
      liteModeEnabled: false,
      initialCameraPosition: CameraPosition(
        target: customerPos,
        zoom: 15.0,
      ),
      markers: markers,
      zoomControlsEnabled: true,
      myLocationButtonEnabled: false,
    );
  }
}
