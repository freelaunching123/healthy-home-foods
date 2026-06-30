import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_storage_service.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _isWishlisted = false;
  
  // Reviews state
  List<dynamic> _reviews = [];
  double _averageRating = 0.0;
  int _totalReviews = 0;

  // Cart state
  int _cartCount = 0;
  int _productQty = 0;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final res = await _api.get('${ApiConstants.products}/${widget.productId}');
      
      _isWishlisted = await LocalStorageService.isInWishlist(widget.productId);
      
      if (res.data != null) {
        LocalStorageService.addRecentlyViewed('package', res.data);
      }
      
      try {
        final reviewRes = await _api.get(ApiConstants.productReviews(widget.productId), queryParameters: {'page': 1, 'page_size': 3});
        _reviews = reviewRes.data['items'] ?? [];
        _averageRating = (reviewRes.data['average_rating'] as num?)?.toDouble() ?? 0.0;
        _totalReviews = reviewRes.data['total'] ?? 0;
      } catch (e) {
        debugPrint('Failed to load reviews: $e');
      }
      
      setState(() { 
        _product = res.data; 
        _planType = _product?['plan_type'];
        _isLoading = false; 
      });
      _loadCartData();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCartData() async {
    try {
      final res = await _api.get(ApiConstants.packageCart);
      final items = res.data['items'] as List? ?? [];
      int qty = 0;
      for (var item in items) {
        if (item['product_id'] == widget.productId) {
          qty = (item['quantity'] as num).toInt();
          break;
        }
      }
      if (mounted) {
        setState(() {
          _cartCount = items.length;
          _productQty = qty;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateQty(int newQty) async {
    if (newQty < 0) newQty = 0;
    setState(() => _productQty = newQty);
    
    try {
      if (newQty == 0) {
        final res = await _api.get(ApiConstants.packageCart);
        final items = res.data['items'] as List? ?? [];
        final cartItem = items.firstWhere((item) => item['product_id'] == widget.productId, orElse: () => null);
        if (cartItem != null) {
          await _api.delete('${ApiConstants.packageCart}/${cartItem['id']}');
        }
      } else {
        await _api.post(ApiConstants.packageCartAdd, data: {
          'product_id': widget.productId,
          'quantity': newQty,
        });
      }
      _loadCartData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update cart: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _toggleWishlist() async {
    if (_product == null) return;
    await LocalStorageService.toggleWishlist(_product!);
    final isWishlisted = await LocalStorageService.isInWishlist(widget.productId);
    setState(() => _isWishlisted = isWishlisted);
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
            actions: [
              IconButton(
                icon: Icon(
                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: _isWishlisted ? Colors.red : Colors.white,
                ),
                onPressed: _toggleWishlist,
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart_rounded, color: Colors.white),
                    onPressed: () => context.push('/packages/cart'),
                    tooltip: 'Package Cart',
                  ),
                  if (_cartCount > 0)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                        child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
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

                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 24),
                  
                  // Reviews Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reviews', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      if (_totalReviews > 0)
                        TextButton(
                          onPressed: () => context.push('/reviews/product/${widget.productId}'),
                          child: Text('See All', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (_totalReviews == 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: Text('No reviews yet', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
                    )
                  else
                    ..._reviews.map((review) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
                                child: Text(review['customer_name']?.substring(0, 1).toUpperCase() ?? 'A', style: const TextStyle(color: AppTheme.primaryGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(review['customer_name'] ?? 'Anonymous', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Row(
                                      children: List.generate(5, (index) => Icon(
                                        index < review['rating'] ? Icons.star_rounded : Icons.star_outline_rounded,
                                        size: 14, color: Colors.amber,
                                      )),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (review['review_text'] != null && review['review_text'].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(review['review_text'], style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                          ],
                        ],
                      ),
                    )),
                  
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
          child: isOutOfStock
              ? ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Currently Unavailable'),
                )
              : _productQty == 0
                  ? ElevatedButton(
                      onPressed: () => _updateQty(1),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Add to Cart  •  ₹${total.toStringAsFixed(0)}'),
                    )
                  : Row(
                      children: [
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, color: AppTheme.primaryGreen),
                                onPressed: () => _updateQty(_productQty - 1),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('$_productQty', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, color: AppTheme.primaryGreen),
                                onPressed: () => _updateQty(_productQty + 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => context.push('/packages/cart'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            child: const Text('View Cart'),
                          ),
                        ),
                      ],
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
