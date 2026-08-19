import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class FruitOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const FruitOrderDetailScreen({super.key, required this.orderId});

  @override
  State<FruitOrderDetailScreen> createState() => _FruitOrderDetailScreenState();
}

class _FruitOrderDetailScreenState extends State<FruitOrderDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;

  int _selectedRating = 0;
  final _reviewController = TextEditingController();
  bool _submittingRating = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get('${ApiConstants.fruitOrders}/${widget.orderId}');
      setState(() { _order = Map<String, dynamic>.from(res.data as Map); _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load order details.'; _loading = false; });
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating <= 0) return;
    setState(() => _submittingRating = true);
    try {
      await _api.post(
        '${ApiConstants.fruitOrders}/${widget.orderId}/rate',
        data: {
          'rating': _selectedRating,
          'review_text': _reviewController.text.trim().isNotEmpty ? _reviewController.text.trim() : null,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted successfully!'), backgroundColor: AppTheme.success),
      );
      _loadOrder();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit feedback'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _submittingRating = false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching phone dialer: $e');
      try {
        await launchUrl(launchUri);
      } catch (_) {}
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'out_for_delivery': return AppTheme.outForDelivery;
      default: return AppTheme.pending;
    }
  }

  String _statusLabel(String status) => status.replaceAll('_', ' ')
      .split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Order Detail', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondary)))
              : _buildDetail(),
    );
  }

  Widget _buildDetail() {
    final order = _order!;
    final items = order['items'] as List? ?? [];
    final orderStatus = order['order_status'] as String? ?? 'pending';
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final total = (order['total_amount'] as num).toDouble();
    final baseUrl = _api.dio.options.baseUrl.replaceAll('/api/v1', '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryGreen, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order['order_number'] as String,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(orderStatus),
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(order['created_at'] as String? ?? ''),
                  style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Status tracker
          _StatusTracker(currentStatus: orderStatus),

          const SizedBox(height: 16),

          // Items
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('Items Ordered', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Divider(height: 1, color: Colors.grey.shade100),
                ...items.asMap().entries.map((e) {
                  final item = e.value as Map<String, dynamic>;
                  final qty = (item['quantity_kg'] as num).toDouble();
                  final price = (item['price_per_kg'] as num).toDouble();
                  final subtotal = (item['subtotal'] as num).toDouble();
                  final imageUrl = item['fruit_image_url'] as String?;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 48, height: 48,
                                child: imageUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: '$baseUrl$imageUrl', fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                                          child: const Center(child: Icon(Icons.eco_rounded, size: 20, color: AppTheme.primaryGreen)),
                                        ),
                                      )
                                    : Container(
                                        color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                                        child: const Center(child: Icon(Icons.eco_rounded, size: 20, color: AppTheme.primaryGreen)),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['fruit_name'] as String, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${qty % 1 == 0 ? qty.toInt() : qty} KG × ₹${price.toStringAsFixed(0)}',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen),
                            ),
                          ],
                        ),
                      ),
                      if (e.key < items.length - 1) Divider(height: 1, color: Colors.grey.shade100),
                    ],
                  );
                }),
                Divider(color: Colors.grey.shade200, height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Text('Total', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                      const Spacer(),
                      Text('₹${total.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryGreen)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Payment info
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment Details', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  _InfoRow(label: 'Payment Status', value: _statusLabel(paymentStatus),
                      valueColor: paymentStatus == 'success' ? AppTheme.success : paymentStatus == 'failed' ? AppTheme.error : AppTheme.warning),
                  if (order['gateway_payment_id'] != null)
                    _InfoRow(label: 'Payment ID', value: order['gateway_payment_id'] as String),
                  if (order['paid_at'] != null)
                    _InfoRow(label: 'Paid At', value: _formatDate(order['paid_at'] as String)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Delivery address
          if (order['address_line1'] != null)
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Address', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.primaryGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${order['address_line1']}, ${order['address_city']}',
                            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 14),

          // Delivery schedule card
          if (order['delivery_date'] != null) ...[
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery Schedule', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    _InfoRow(label: 'Scheduled Date', value: _formatDate(order['delivery_date'] as String)),
                    _InfoRow(label: 'Time Slot', value: order['delivery_slot'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Assigned Delivery Partner Card
          if (order['assigned_partner_name'] != null) ...[
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      child: const Icon(Icons.person, size: 22, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delivery Executive', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
                          Text(order['assigned_partner_name'] as String, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          if (order['assigned_partner_phone'] != null)
                            Text(order['assigned_partner_phone'] as String, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    if (order['assigned_partner_phone'] != null)
                      IconButton(
                        icon: const Icon(Icons.phone_rounded, color: AppTheme.primaryGreen, size: 24),
                        onPressed: () => _makePhoneCall(order['assigned_partner_phone'] as String),
                        tooltip: 'Call Delivery Partner',
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Rating card
          if (orderStatus == 'delivered') ...[
            if (order['rating'] != null)
              _Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Rating & Review', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            starIndex < (order['rating'] as int) ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber,
                            size: 24,
                          );
                        }),
                      ),
                      if (order['review_text'] != null && (order['review_text'] as String).isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          '"${order['review_text']}"',
                          style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              _Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rate Your Order', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text('How was your grocery order delivery?', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(5, (starIndex) {
                          final starVal = starIndex + 1;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedRating = starVal;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Icon(
                                starVal <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                                color: Colors.amber,
                                size: 32,
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_selectedRating > 0) ...[
                        const SizedBox(height: 16),
                        TextField(
                          controller: _reviewController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Share your feedback (optional)...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _submittingRating ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 40),
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: _submittingRating
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Submit Feedback'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
          ],

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) { return iso; }
  }
}


class _StatusTracker extends StatelessWidget {
  final String currentStatus;
  const _StatusTracker({required this.currentStatus});

  static const _steps = [
    ('pending', 'Order Placed', Icons.check_circle_outline_rounded),
    ('out_for_delivery', 'Out for Delivery', Icons.delivery_dining_rounded),
    ('delivered', 'Delivered', Icons.home_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    if (currentStatus == 'cancelled') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppTheme.error),
            const SizedBox(width: 10),
            Text('Order Cancelled', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final currentIdx = _steps.indexWhere((s) => s.$1 == currentStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_steps.length, (idx) {
              final isDone = idx <= currentIdx;
              final isCurrent = idx == currentIdx;
              final step = _steps[idx];

              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (idx > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: idx <= currentIdx ? AppTheme.primaryGreen : Colors.grey.shade200,
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDone ? AppTheme.primaryGreen : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: isCurrent ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 8)] : [],
                      ),
                      child: Icon(step.$3, size: 14, color: isDone ? Colors.white : AppTheme.textLight),
                    ),
                    if (idx < _steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: idx < currentIdx ? AppTheme.primaryGreen : Colors.grey.shade200,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_steps.length, (idx) {
              final isDone = idx <= currentIdx;
              final isCurrent = idx == currentIdx;
              final step = _steps[idx];

              return Expanded(
                child: Text(
                  step.$2,
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isDone ? AppTheme.primaryGreen : AppTheme.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}


class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
    ),
    child: child,
  );
}


class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: valueColor)),
      ],
    ),
  );
}
