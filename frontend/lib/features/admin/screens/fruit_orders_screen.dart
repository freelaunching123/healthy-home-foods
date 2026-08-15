import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class FruitOrdersScreen extends StatefulWidget {
  const FruitOrdersScreen({super.key});

  @override
  State<FruitOrdersScreen> createState() => _FruitOrdersScreenState();
}

class _FruitOrdersScreenState extends State<FruitOrdersScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  String? _error;
  String? _filterOrderStatus;
  String? _filterPaymentStatus;
  final _searchController = TextEditingController();

  static const _orderStatuses = [
    'pending', 'out_for_delivery', 'delivered', 'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadPartners();
    _loadOrders();
  }

  Future<void> _loadPartners() async {
    try {
      final res = await _api.get('/delivery-partners');
      if (res.data is List) {
        if (mounted) {
          setState(() {
            _partners = List<Map<String, dynamic>>.from(res.data);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading partners: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_filterOrderStatus != null) params['order_status'] = _filterOrderStatus!;
      if (_filterPaymentStatus != null) params['payment_status'] = _filterPaymentStatus!;
      if (_searchController.text.trim().isNotEmpty) params['search'] = _searchController.text.trim();

      final res = await _api.get(ApiConstants.adminFruitOrders, queryParameters: params);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(res.data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load orders.'; _loading = false; });
    }
  }



  Future<void> _assignPartner(Map<String, dynamic> order, String? partnerId) async {
    try {
      await _api.post('${ApiConstants.adminFruitOrders}/${order['id']}/assign', data: {'delivery_partner_id': partnerId});
      _loadOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delivery partner updated successfully'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update delivery partner'), backgroundColor: AppTheme.error),
      );
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
        title: Text('Grocery Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: Column(
        children: [
          // Search + Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by order number...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                      onPressed: _loadOrders,
                    ),
                    filled: true, fillColor: AppTheme.scaffoldBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _loadOrders(),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All Orders', selected: _filterOrderStatus == null,
                        onTap: () { setState(() => _filterOrderStatus = null); _loadOrders(); }),
                      ..._orderStatuses.map((s) => _FilterChip(
                        label: _statusLabel(s), selected: _filterOrderStatus == s,
                        onTap: () { setState(() => _filterOrderStatus = s); _loadOrders(); },
                        color: _statusColor(s),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('Payment: ', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                    ...[null, 'pending', 'success', 'failed'].map((s) => GestureDetector(
                      onTap: () { setState(() => _filterPaymentStatus = s); _loadOrders(); },
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _filterPaymentStatus == s ? AppTheme.primaryGreen : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          s == null ? 'All' : s[0].toUpperCase() + s.substring(1),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _filterPaymentStatus == s ? Colors.white : AppTheme.textSecondary,
                            fontWeight: _filterPaymentStatus == s ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ],
            ),
          ),

          // Orders list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _error != null
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
                      ]))
                    : _orders.isEmpty
                        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.receipt_long_outlined, size: 64, color: AppTheme.accentLight),
                            const SizedBox(height: 12),
                            Text('No orders found', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                          ]))
                        : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final order = _orders[i];
                                return _AdminOrderCard(
                                  order: order,
                                  partners: _partners,
                                  statusColor: _statusColor(order['order_status'] as String? ?? 'pending'),
                                  statusLabel: _statusLabel(order['order_status'] as String? ?? 'pending'),
                                  onAssignPartner: (partnerId) => _assignPartner(order, partnerId),
                                );
                              },
                            ),
          ),
        ],
      ),
    );
  }
}


class _AdminOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> partners;
  final Color statusColor;
  final String statusLabel;
  final Function(String?) onAssignPartner;

  const _AdminOrderCard({
    required this.order, required this.partners, required this.statusColor,
    required this.statusLabel, required this.onAssignPartner,
  });

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List? ?? [];
    final total = (order['total_amount'] as num).toDouble();
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final customerName = order['customer_name'] as String? ?? 'Customer';
    final createdAt = order['created_at'] as String?;

    final itemSummary = items.take(2).map((i) {
      final qty = (i['quantity_kg'] as num).toDouble();
      return '${i['fruit_name']} (${qty % 1 == 0 ? qty.toInt() : qty}kg)';
    }).join(', ');
    final moreCount = items.length - 2;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(order['order_number'] as String,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 6),
                    Text(customerName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (createdAt != null)
                      Text(_formatDate(createdAt), style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  itemSummary + (moreCount > 0 ? ' +$moreCount more' : ''),
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Payment badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: paymentStatus == 'success' ? AppTheme.success.withValues(alpha: 0.1)
                            : paymentStatus == 'failed' ? AppTheme.error.withValues(alpha: 0.1)
                            : AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        paymentStatus == 'success' ? '✓ Paid' : paymentStatus == 'failed' ? '✗ Failed' : 'Unpaid',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                          color: paymentStatus == 'success' ? AppTheme.success
                              : paymentStatus == 'failed' ? AppTheme.error : AppTheme.warning),
                      ),
                    ),
                    const Spacer(),
                    Text('₹${total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryGreen)),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _showOrderDetails(context, order),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Details'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String?>(
                        value: order['assigned_partner_id']?.toString(),
                        hint: Text('Assign Partner', style: GoogleFonts.inter(fontSize: 13)),
                        isExpanded: true,
                        isDense: true,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned', style: GoogleFonts.inter(fontSize: 13, fontStyle: FontStyle.italic)),
                          ),
                          ...partners.map((p) => DropdownMenuItem<String?>(
                                value: p['id'].toString(),
                                child: Text(p['full_name'] ?? 'Unknown Partner', style: GoogleFonts.inter(fontSize: 13)),
                              )),
                        ],
                        onChanged: (val) async {
                          if (val == order['assigned_partner_id']?.toString()) return;
                          final partnerName = val == null ? 'Unassigned' : partners.firstWhere((p) => p['id'].toString() == val, orElse: () => {'full_name': 'Unknown Partner'})['full_name'] ?? 'Unknown Partner';
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Assignment'),
                              content: Text('Assign this order to $partnerName?'),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true), 
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                                  child: const Text('Confirm')
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            onAssignPartner(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final deliveryDate = order['delivery_date'] as String?;
    final deliverySlot = order['delivery_slot'] as String?;
    final rating = order['rating'] as int?;
    final reviewText = order['review_text'] as String?;
    final lat = order['latitude'] as double?;
    final lng = order['longitude'] as double?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Grocery Order Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              
              Text('Order Number: ${order['order_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Status: ${order['order_status'].toString().toUpperCase()}', style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 16),

              const Text('Customer & Recipient Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Customer Name', value: order['customer_name'] ?? 'N/A'),
              _DetailRow(label: 'Customer Phone', value: order['customer_phone'] ?? 'N/A'),
              _DetailRow(label: 'Recipient Name', value: order['recipient_name'] ?? 'N/A'),
              _DetailRow(label: 'Recipient Phone', value: order['recipient_phone'] ?? 'N/A'),
              const SizedBox(height: 16),

              const Text('Delivery Address & Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Address', value: '${order['address_line1'] ?? ''} ${order['address_line2'] ?? ''}, ${order['address_city'] ?? ''}, ${order['address_state'] ?? ''} - ${order['address_pincode'] ?? ''}'),
              _DetailRow(label: 'Coordinates (Lat, Lng)', value: lat != null && lng != null ? '$lat, $lng' : 'N/A'),
              _DetailRow(label: 'Scheduled Date', value: deliveryDate ?? 'N/A'),
              _DetailRow(label: 'Time Slot', value: deliverySlot ?? 'N/A'),
              const SizedBox(height: 16),

              const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Payment Status', value: order['payment_status'] ?? 'pending'),
              _DetailRow(label: 'Total Amount', value: '₹${(order['total_amount'] as num).toDouble().toStringAsFixed(2)}'),
              const SizedBox(height: 16),

              const Text('Items Ordered', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...items.map((item) {
                final qty = (item['quantity_kg'] as num).toDouble();
                final price = (item['price_per_kg'] as num).toDouble();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['fruit_name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${qty % 1 == 0 ? qty.toInt() : qty} KG × ₹${price.toStringAsFixed(0)}'),
                  trailing: Text('₹${(item['subtotal'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
              const SizedBox(height: 16),

              if (rating != null) ...[
                const Text('Customer Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.amber)),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (starIdx) => Icon(
                    starIdx < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: Colors.amber,
                    size: 20,
                  )),
                ),
                if (reviewText != null && reviewText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('"$reviewText"', style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 16),
              ],

              if (order['notes'] != null && (order['notes'] as String).trim().isNotEmpty) ...[
                const Text('Special Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Text(order['notes'] as String, style: const TextStyle(color: AppTheme.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) { return ''; }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Spacer(), // dummy spacer just to match signature but we'll use expanded
          SizedBox(
            width: 130,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}



class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({required this.label, required this.selected, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? (color ?? AppTheme.primaryGreen) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : AppTheme.textSecondary,
      )),
    ),
  );
}
