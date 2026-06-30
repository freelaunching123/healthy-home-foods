import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class PackageCartScreen extends StatefulWidget {
  const PackageCartScreen({super.key});

  @override
  State<PackageCartScreen> createState() => _PackageCartScreenState();
}

class _PackageCartScreenState extends State<PackageCartScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _items = [];
  double _total = 0;
  bool _loading = true;
  bool _clearing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.packageCart);
      setState(() {
        _items = List<Map<String, dynamic>>.from(res.data['items'] as List);
        _total = (res.data['total_amount'] as num).toDouble();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Could not load cart.'; _loading = false; });
    }
  }

  Future<void> _updateQty(Map<String, dynamic> item, int newQty) async {
    if (newQty <= 0) {
      await _removeItem(item);
      return;
    }
    try {
      await _api.put('${ApiConstants.packageCart}/${item['id']}', data: {'quantity': newQty});
      _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    try {
      await _api.delete('${ApiConstants.packageCart}/${item['id']}');
      _loadCart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _clearCart() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cart?'),
        content: const Text('All items will be removed from your cart.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Clear', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _clearing = true);
    try {
      await _api.delete(ApiConstants.packageCart + '/clear'); // The package cart uses /clear unlike fruit cart
      _loadCart();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('My Package Cart', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _clearing ? null : _clearCart,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.error),
              label: Text('Clear', style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _error != null
              ? _buildError()
              : _items.isEmpty
                  ? _buildEmpty()
                  : _buildCart(),
      bottomNavigationBar: _items.isNotEmpty && !_loading
          ? _buildCheckoutBar()
          : null,
    );
  }

  Widget _buildCart() {
    final baseUrl = _api.dio.options.baseUrl.replaceAll('/api/v1', '');
    return RefreshIndicator(
      color: AppTheme.primaryGreen,
      onRefresh: _loadCart,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final item = _items[i];
          final qty = (item['quantity'] as num).toInt();
          final price = (item['unit_price'] as num).toDouble();
          final subtotal = (item['subtotal'] as num).toDouble();
          final imageUrl = item['product_image_url'] as String?;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: '$baseUrl$imageUrl',
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 40),
                            )
                          : const Icon(Icons.eco, color: AppTheme.primaryGreen, size: 40),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'] as String,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${price.toStringAsFixed(0)} / pack',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Stepper
                            _InlineQtyStepper(
                              qty: qty,
                              onMinus: () => _updateQty(item, qty - 1),
                              onPlus: () => _updateQty(item, qty + 1),
                            ),
                            const Spacer(),
                            Text(
                              '₹${subtotal.toStringAsFixed(2)}',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Remove
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textLight, size: 20),
                    onPressed: () => _removeItem(item),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12)),
              Text(
                '₹${_total.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20, color: AppTheme.primaryGreen),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.push('/packages/checkout'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text('Proceed to Checkout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shopping_cart_outlined, size: 72, color: AppTheme.accentLight),
        const SizedBox(height: 16),
        Text('Your cart is empty', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Add some packages to get started!', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 44)),
          child: const Text('Browse Packages'),
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
        ElevatedButton(onPressed: _loadCart, child: const Text('Retry')),
      ],
    ),
  );
}


class _InlineQtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _InlineQtyStepper({required this.qty, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: 28, height: 30,
              decoration: const BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
              ),
              child: const Icon(Icons.remove_rounded, size: 14, color: AppTheme.primaryGreen),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$qty',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: onPlus,
            child: Container(
              width: 28, height: 30,
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
              ),
              child: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
