import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _product;
  String? _planType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final res = await _api.get('${ApiConstants.products}/${widget.productId}');
      setState(() { 
        _product = res.data; 
        _planType = _product?['plan_type'];
        _isLoading = false; 
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    }
    if (_product == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Product not found')));
    }

    final double packagePrice = double.tryParse(_product!['package_price']?.toString() ?? '0') ?? 0;
    final double? discountPrice = _product!['discount_price'] != null ? double.tryParse(_product!['discount_price'].toString()) : null;
    
    final double effectiveCurrentPrice = discountPrice ?? packagePrice;
    
    final int packageDays = _product!['package_days'] ?? 6;
    final total = effectiveCurrentPrice;
    final bool isOutOfStock = _product!['availability'] != 'available';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppTheme.primaryGreen,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.textPrimary),
              ),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [AppTheme.primaryGreen.withValues(alpha: 0.1), AppTheme.primaryGreen.withValues(alpha: 0.05)],
                  ),
                ),
                child: _product!['image_url'] != null
                  ? Image.network('${_api.mediaBaseUrl}${_product!['image_url']}', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.eco_rounded, size: 80, color: AppTheme.primaryGreen)))
                  : const Center(child: Icon(Icons.eco_rounded, size: 80, color: AppTheme.primaryGreen)),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name & price
                  Text(_product!['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (discountPrice != null) ...[
                        Text('₹${packagePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                      ],
                      Text('₹${effectiveCurrentPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                      const Text(' /pack', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: !isOutOfStock ? AppTheme.delivered.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          !isOutOfStock ? '✅ Available' : '❌ Out of Stock',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: !isOutOfStock ? AppTheme.delivered : AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  if (_product!['description'] != null) ...[
                    const Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(_product!['description'], style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Benefits
                  if (_product!['benefits'] != null) ...[
                    const Text('Benefits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    ...(_product!['benefits'] as String).split(',').map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Text(b.trim(), style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                      ]),
                    )),
                    const SizedBox(height: 20),
                  ],

                  const Text('Plan Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PlanCard(
                        label: '${_planType?.toUpperCase() ?? 'PLAN'} PACKAGE', deliveries: '$packageDays deliveries', price: '₹${effectiveCurrentPrice.toStringAsFixed(0)}',
                        isSelected: true,
                        onTap: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow('Plan', _planType?.toUpperCase() ?? 'PACKAGE'),
                        _SummaryRow('Deliveries', '$packageDays days'),
                        _SummaryRow('Package Price', '₹${effectiveCurrentPrice.toStringAsFixed(0)}'),
                        const Divider(),
                        _SummaryRow('Total', '₹${total.toStringAsFixed(0)}', isBold: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: isOutOfStock ? null : () => context.push('/checkout?productId=${widget.productId}&plan=$_planType'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOutOfStock ? Colors.grey : AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(isOutOfStock ? 'Currently Unavailable' : 'Subscribe Now  •  ₹${total.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label, deliveries, price;
  final bool isSelected;
  final VoidCallback onTap;
  const _PlanCard({required this.label, required this.deliveries, required this.price, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200, width: 2),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : AppTheme.textPrimary)),
              const SizedBox(height: 4),
              Text(deliveries, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : AppTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(price, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : AppTheme.primaryGreen)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  const _SummaryRow(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? AppTheme.primaryGreen : AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
