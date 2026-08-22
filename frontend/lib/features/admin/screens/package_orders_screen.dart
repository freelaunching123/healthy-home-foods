import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class PackageOrdersScreen extends StatefulWidget {
  const PackageOrdersScreen({super.key});

  @override
  State<PackageOrdersScreen> createState() => _PackageOrdersScreenState();
}

class _PackageOrdersScreenState extends State<PackageOrdersScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.adminPackageOrders);
      final dpRes = await _api.get(ApiConstants.adminDeliveryPartners);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(res.data as List);
        _partners = List<Map<String, dynamic>>.from(dpRes.data as List);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading package orders: $e');
      setState(() { _error = 'Failed to load package orders.\n\nError: $e'; _loading = false; });
    }
  }

  Future<void> _assignPartner(String orderId, String? partnerId) async {
    try {
      await _api.post('/packages/orders/admin/package-orders/$orderId/assign', data: {'delivery_partner_id': partnerId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery partner assigned successfully')));
        _loadOrders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to assign delivery partner')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Package Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _loading
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
                      Text('No package orders found', style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary)),
                    ]))
                  : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final order = _orders[i];
                          return _AdminPackageOrderCard(
                            order: order,
                            partners: _partners,
                            onAssign: (partnerId) => _assignPartner(order['id'], partnerId),
                            onViewDetails: () => _showOrderDetails(context, order),
                          );
                        },
                      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    
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
                  Text('Package Order Details', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              
              Text(
                'Order ID: ${order['order_id'] ?? order['id'].toString().substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),const SizedBox(height: 16),

              const Text('Customer Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Customer Name', value: order['customer_name'] ?? 'N/A'),
              _DetailRow(label: 'Customer Phone', value: order['customer_phone'] ?? 'N/A'),
              const SizedBox(height: 16),

              const Text('Payment Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _DetailRow(label: 'Payment Status', value: order['payment_status'] ?? 'pending'),
              _DetailRow(label: 'Gateway Order ID', value: order['gateway_order_id'] ?? 'N/A'),
              _DetailRow(label: 'Gateway Payment ID', value: order['gateway_payment_id'] ?? 'N/A'),
              _DetailRow(label: 'Total Amount', value: '₹${(order['total_amount'] as num).toDouble().toStringAsFixed(2)}'),
              const SizedBox(height: 16),

              const Text('Packages Subscribed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              ...items.map((item) {
                final qty = (item['quantity'] as num).toInt();
                final price = (item['package_price'] as num).toDouble();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['product_name'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('$qty × ₹${price.toStringAsFixed(0)}'),
                  trailing: Text('₹${(item['subtotal'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPackageOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> partners;
  final Function(String?) onAssign;
  final VoidCallback onViewDetails;

  const _AdminPackageOrderCard({
    required this.order, required this.partners, required this.onAssign, required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List? ?? [];
    final total = (order['total_amount'] as num).toDouble();
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final customerName = order['customer_name'] as String? ?? 'Customer';
    final createdAt = order['created_at'] as String?;

    final itemSummary = items.take(2).map((i) {
      final qty = (i['quantity'] as num).toInt();
      return '${i['product_name']} ($qty)';
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
              color: AppTheme.primaryGreen.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(order['order_number'] as String,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
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
                      onPressed: onViewDetails,
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
                    const Icon(Icons.delivery_dining_rounded, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: order['delivery_partner_id'] as String?,
                          hint: Text('Assign Partner', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGreen),
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Unassigned'),
                            ),
                            ...partners.map((p) => DropdownMenuItem<String>(
                                  value: p['id'] as String,
                                  child: Text(p['full_name'] ?? 'Unknown Partner'),
                                )),
                          ],
                          onChanged: (val) async {
                            if (val == order['delivery_partner_id']) return;
                            final partnerName = val == null ? 'Unassigned' : partners.firstWhere((p) => p['id'] == val, orElse: () => {'full_name': 'Unknown Partner'})['full_name'] ?? 'Unknown Partner';
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
                              onAssign(val);
                            }
                          },
                        ),
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
          SizedBox(
            width: 150,
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
