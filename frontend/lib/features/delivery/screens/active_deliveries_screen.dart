import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class ActiveDeliveriesScreen extends StatefulWidget {
  const ActiveDeliveriesScreen({super.key});

  @override
  State<ActiveDeliveriesScreen> createState() => _ActiveDeliveriesScreenState();
}

class _ActiveDeliveriesScreenState extends State<ActiveDeliveriesScreen> {
  final _api = ApiClient();
  List<dynamic> _deliveries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.partnerActiveDeliveries);
      if (mounted) {
        setState(() {
          _deliveries = res.data is List ? res.data : [];
        });
      }
    } catch (e) {
      debugPrint('Error loading active deliveries: $e');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load active deliveries')),
        );
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String assignmentId, String newStatus, {String? failureReason}) async {
    // Optimistic UI update: Remove delivered/failed items instantly from UI
    setState(() {
      if (newStatus == 'delivered' || newStatus == 'failed') {
        _deliveries.removeWhere((item) => item['id'] == assignmentId);
      } else {
        final idx = _deliveries.indexWhere((item) => item['id'] == assignmentId);
        if (idx != -1) _deliveries[idx]['status'] = newStatus;
      }
    });

    try {
      final data = {
        'status': newStatus,
        'failure_reason': failureReason,
      }..removeWhere((_, v) => v == null);
      
      await _api.put(ApiConstants.partnerUpdateStatus(assignmentId), data: data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status updated to $newStatus'), duration: const Duration(seconds: 1)),
        );
      }
      _loadDeliveries(silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
      _loadDeliveries(silent: true);
    }
  }

  void _showFailureReasonModal(String assignmentId) {
    final reasonController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report Failed Delivery', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('Please select or enter the reason for failure:'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Customer not available'),
                    onPressed: () => _updateStatus(assignmentId, 'failed', failureReason: 'Customer not available').then((_) => Navigator.pop(context)),
                  ),
                  ActionChip(
                    label: const Text('Wrong address'),
                    onPressed: () => _updateStatus(assignmentId, 'failed', failureReason: 'Wrong address').then((_) => Navigator.pop(context)),
                  ),
                  ActionChip(
                    label: const Text('Customer rejected'),
                    onPressed: () => _updateStatus(assignmentId, 'failed', failureReason: 'Customer rejected').then((_) => Navigator.pop(context)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Other Reason',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (reasonController.text.trim().isEmpty) return;
                    _updateStatus(assignmentId, 'failed', failureReason: reasonController.text.trim()).then((_) => Navigator.pop(context));
                  },
                  child: const Text('Submit Failure'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showStatusUpdateModal(dynamic delivery) {
    final currentStatus = delivery['status'] as String? ?? '';
    final assignmentId = delivery['id'] as String;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Update Delivery Status', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              if (currentStatus == 'pending')
                ListTile(
                  leading: const Icon(Icons.local_shipping, color: Colors.orange),
                  title: const Text('Mark Out For Delivery'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateStatus(assignmentId, 'out_for_delivery');
                  },
                ),
              if (currentStatus == 'out_for_delivery')
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Mark as Delivered'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateStatus(assignmentId, 'delivered');
                  },
                ),
              ListTile(
                leading: const Icon(Icons.error, color: Colors.red),
                title: const Text('Mark as Failed'),
                onTap: () {
                  Navigator.pop(context);
                  _showFailureReasonModal(assignmentId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Deliveries'),

      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _deliveries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.task_alt_rounded, size: 56, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Today\'s Deliveries Completed!',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'All package deliveries for today have been marked complete. Next delivery will be scheduled for tomorrow.',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _deliveries.length,
                  itemBuilder: (context, index) {
                    final delivery = _deliveries[index];
                    return _buildDeliveryCard(delivery);
                  },
                ),
    );
  }

  Widget _buildDeliveryCard(dynamic delivery) {
    final orderType = delivery['order_type'] == 'fruit' ? 'Grocery Order' : 'Subscription';
    final lat = delivery['latitude'];
    final lng = delivery['longitude'];
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order: ${delivery['order_id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    (delivery['status'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primaryGreen,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(delivery['customer_name'] ?? 'Unknown'),
              subtitle: Text(delivery['customer_phone'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.phone, color: Colors.blue),
                onPressed: () {
                  final phone = delivery['customer_phone'];
                  if (phone != null) launchUrl(Uri.parse('tel:$phone'));
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(delivery['delivery_address'] ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.inventory_2, size: 20, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$orderType - ${delivery['items_summary'] ?? ''}'),
                ),
              ],
            ),
            if (delivery['delivery_instructions'] != null && delivery['delivery_instructions'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Note: ${delivery['delivery_instructions']}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (lat != null && lng != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('Maps'),
                      onPressed: () => _launchMaps(lat.toDouble(), lng.toDouble()),
                    ),
                  )
                else
                  const Expanded(
                    child: OutlinedButton(
                      onPressed: null,
                      child: Text('No Location'),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showStatusUpdateModal(delivery),
                    child: const Text('Update Status'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
