import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class OrderDetailScreen extends StatefulWidget {
  final String assignmentId;
  const OrderDetailScreen({super.key, required this.assignmentId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _delivery;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/delivery-partner/assignments/${widget.assignmentId}');
      setState(() {
        _delivery = res.data;
      });
    } catch (e) {
      debugPrint('Error loading delivery details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load delivery details')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _isLoading = true);
    try {
      await _api.put(
        ApiConstants.partnerUpdateStatus(widget.assignmentId),
        data: {'status': status},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order marked as ${status.toUpperCase()}!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  Future<void> _callCustomer(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not initiate call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _delivery == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Failed to load order details.')),
      );
    }

    final delivery = _delivery!;
    final orderType = delivery['order_type'] == 'fruit' ? 'Grocery Order' : 'Subscription';
    final lat = delivery['latitude'];
    final lng = delivery['longitude'];
    final status = delivery['status'] as String? ?? 'pending';
    final isDelivered = status == 'delivered';
    final isFailed = status == 'failed';
    final isOutForDelivery = status == 'out_for_delivery';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Order #${delivery['order_id']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Header Info Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade100, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scheduled: ${delivery['scheduled_time'] ?? 'Standard Slot'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDelivered 
                            ? AppTheme.primaryGreen.withValues(alpha: 0.1) 
                            : isFailed 
                                ? Colors.red.withValues(alpha: 0.1)
                                : isOutForDelivery 
                                    ? Colors.orange.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDelivered 
                              ? AppTheme.primaryGreen 
                              : isFailed 
                                  ? Colors.red 
                                  : isOutForDelivery 
                                      ? Colors.orange 
                                      : Colors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer details
            Card(
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
                    const Text(
                      'Customer Information',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const Divider(height: 24),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppTheme.primaryGreen),
                      ),
                      title: Text(delivery['customer_name'] ?? 'Unknown Customer', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(delivery['customer_phone'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.phone, color: Colors.blue),
                        onPressed: () => _callCustomer(delivery['customer_phone'] ?? ''),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            delivery['delivery_address'] ?? '',
                            style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items details
            Card(
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
                    const Text(
                      'Delivery Content',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.inventory_2_outlined, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            delivery['items_summary'] ?? 'Items list empty',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    if (delivery['delivery_instructions'] != null && delivery['delivery_instructions'].toString().isNotEmpty) ...[
                      const Divider(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blueGrey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Note', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                Text(
                                  delivery['delivery_instructions'],
                                  style: const TextStyle(color: AppTheme.textSecondary, fontStyle: FontStyle.italic, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Actions
            if (!isDelivered && !isFailed) ...[
              if (!isOutForDelivery) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _updateStatus('out_for_delivery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Start Delivery (Out for Delivery)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (lat != null && lng != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _launchMaps(lat.toDouble(), lng.toDouble()),
                    icon: const Icon(Icons.map, color: AppTheme.primaryGreen),
                    label: const Text('Open in Google Maps', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (isOutForDelivery) ...[
                Center(
                  child: _SwipeButton(
                    onSwiped: () => _updateStatus('delivered'),
                  ),
                ),
              ],
            ],
            if (isDelivered)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.primaryGreen, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'This delivery is completed!',
                        style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SwipeButton extends StatefulWidget {
  final VoidCallback onSwiped;
  const _SwipeButton({required this.onSwiped});
  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  double _dragPosition = 0.0;
  static const double _buttonWidth = 280.0;
  static const double _handleSize = 48.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _buttonWidth,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              'Swipe to Deliver',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.primaryGreen.withOpacity(0.7),
              ),
            ),
          ),
          Positioned(
            left: _dragPosition,
            top: 3,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPosition = (_dragPosition + details.delta.dx)
                      .clamp(0.0, _buttonWidth - _handleSize - 8.0);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragPosition >= _buttonWidth - _handleSize - 16.0) {
                  widget.onSwiped();
                } else {
                  setState(() {
                    _dragPosition = 0.0;
                  });
                }
              },
              child: Container(
                width: _handleSize,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
