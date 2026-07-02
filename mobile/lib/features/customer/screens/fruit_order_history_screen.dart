import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class FruitOrderHistoryScreen extends StatefulWidget {
  const FruitOrderHistoryScreen({super.key});

  @override
  State<FruitOrderHistoryScreen> createState() => _FruitOrderHistoryScreenState();
}

class _FruitOrderHistoryScreenState extends State<FruitOrderHistoryScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _orders = [];
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
      final res = await _api.get(ApiConstants.fruitOrdersHistory);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(res.data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load orders.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('My Fruit Orders', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _error != null
              ? _buildError()
              : _orders.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      color: AppTheme.primaryGreen,
                      onRefresh: _loadOrders,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _OrderCard(
                          order: _orders[i],
                          onTap: () => context.push('/fruits/orders/${_orders[i]['id']}'),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_long_outlined, size: 72, color: AppTheme.accentLight),
        const SizedBox(height: 16),
        Text('No orders yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Start ordering fresh fruits!', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/fruits'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 44)),
          child: const Text('Browse Fruits'),
        ),
      ],
    ),
  );

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.textLight),
        const SizedBox(height: 12),
        Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
      ],
    ),
  );
}


class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  Color _orderStatusColor(String status) {
    switch (status) {
      case 'delivered': return AppTheme.success;
      case 'cancelled': return AppTheme.error;
      case 'out_for_delivery': return AppTheme.outForDelivery;
      case 'preparing': return AppTheme.info;
      case 'ready': return AppTheme.warning;
      default: return AppTheme.pending;
    }
  }

  String _orderStatusLabel(String status) {
    switch (status) {
      case 'out_for_delivery': return 'Out for Delivery';
      default: return status.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStatus = order['order_status'] as String? ?? 'pending';
    final paymentStatus = order['payment_status'] as String? ?? 'pending';
    final total = (order['total_amount'] as num).toDouble();
    final items = order['items'] as List? ?? [];
    final orderNum = order['order_number'] as String;
    final createdAt = order['created_at'] as String?;
    final statusColor = _orderStatusColor(orderStatus);

    // Summarise items
    final itemSummary = items.take(3).map((i) {
      final qty = (i['quantity_kg'] as num).toDouble();
      return '${i['fruit_name']} (${qty % 1 == 0 ? qty.toInt() : qty} KG)';
    }).join(', ');
    final moreCount = items.length - 3;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(orderNum, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _orderStatusLabel(orderStatus),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                    ),
                  ),
                ],
              ),
              if (createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDate(createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textLight),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                itemSummary + (moreCount > 0 ? ' +$moreCount more' : ''),
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  // Payment status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: paymentStatus == 'success'
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : paymentStatus == 'failed'
                              ? AppTheme.error.withValues(alpha: 0.1)
                              : AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      paymentStatus == 'success' ? '✓ Paid' : paymentStatus == 'failed' ? '✗ Failed' : 'Pending',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: paymentStatus == 'success'
                            ? AppTheme.success
                            : paymentStatus == 'failed'
                                ? AppTheme.error
                                : AppTheme.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Delivery Date if available
                  if (order['expected_delivery_date'] != null || order['delivery_date'] != null)
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(order['delivery_date'] ?? order['expected_delivery_date']),
                          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  const Spacer(),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 18),
                ],
              ),
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
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
