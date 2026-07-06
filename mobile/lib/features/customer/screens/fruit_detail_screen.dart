import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_storage_service.dart';

class FruitDetailScreen extends StatefulWidget {
  final String fruitId;
  const FruitDetailScreen({super.key, required this.fruitId});

  @override
  State<FruitDetailScreen> createState() => _FruitDetailScreenState();
}

class _FruitDetailScreenState extends State<FruitDetailScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _fruit;
  bool _isLoading = true;
  String? _error;
  bool _isWishlisted = false;
  
  double _cartQuantity = 0;
  bool _isCartLoading = true;
  
  // Reviews state
  List<dynamic> _reviews = [];
  double _averageRating = 0.0;
  int _totalReviews = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load fruit details
      final res = await _api.get('${ApiConstants.fruitDetail}/${widget.fruitId}');
      _fruit = res.data;
      
      // Load cart quantity for this fruit
      final cartRes = await _api.get(ApiConstants.fruitCart);
      final items = cartRes.data['items'] as List? ?? [];
      final cartItem = items.firstWhere((item) => item['fruit_id'] == widget.fruitId, orElse: () => null);
      if (cartItem != null) {
        _cartQuantity = (cartItem['quantity_kg'] as num).toDouble();
      }
      
      // Load wishlist status
      _isWishlisted = await LocalStorageService.isInWishlist(widget.fruitId);
      
      // Track recently viewed
      if (_fruit != null) {
        LocalStorageService.addRecentlyViewed('fruit', _fruit!);
      }
      
      // Load reviews
      try {
        final reviewRes = await _api.get(ApiConstants.fruitReviews(widget.fruitId), queryParameters: {'page': 1, 'page_size': 3});
        _reviews = reviewRes.data['items'] ?? [];
        _averageRating = (reviewRes.data['average_rating'] as num?)?.toDouble() ?? 0.0;
        _totalReviews = reviewRes.data['total'] ?? 0;
      } catch (e) {
        debugPrint('Failed to load reviews: $e');
      }
      
    } catch (e) {
      _error = 'Failed to load fruit details';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCartLoading = false;
        });
      }
    }
  }

  Future<void> _updateCart(double qty) async {
    setState(() => _isCartLoading = true);
    try {
      if (qty <= 0) {
        final res = await _api.get(ApiConstants.fruitCart);
        final items = res.data['items'] as List? ?? [];
        final cartItem = items.firstWhere((item) => item['fruit_id'] == widget.fruitId, orElse: () => null);
        if (cartItem != null) {
          await _api.delete('${ApiConstants.fruitCart}/${cartItem['id']}');
        }
      } else {
        await _api.post(ApiConstants.fruitCartAdd, data: {
          'fruit_id': widget.fruitId,
          'quantity_kg': qty,
        });
      }
      setState(() => _cartQuantity = qty);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(qty <= 0 ? 'Removed from cart' : 'Cart updated'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryGreen,
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to update cart'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      setState(() => _isCartLoading = false);
    }
  }

  Future<void> _toggleWishlist() async {
    if (_fruit == null) return;
    await LocalStorageService.toggleWishlist(_fruit!);
    final isWishlisted = await LocalStorageService.isInWishlist(widget.fruitId);
    setState(() => _isWishlisted = isWishlisted);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    }
    
    if (_error != null || _fruit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? 'Unknown error'),
              TextButton(onPressed: _loadData, child: const Text('Retry'))
            ],
          ),
        ),
      );
    }

    final available = _fruit!['availability_status'] == 'in_stock' && _fruit!['is_active'] == true;
    final price = (_fruit!['price_per_kg'] as num).toDouble();
    final baseUrl = _api.dio.options.baseUrl.replaceAll('/api/v1', '');
    final imageUrl = _fruit!['image_url'] != null ? '$baseUrl${_fruit!['image_url']}' : null;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: Icon(
                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: _isWishlisted ? Colors.red : Colors.white,
                ),
                onPressed: _toggleWishlist,
              ),
              IconButton(
                icon: const Icon(Icons.shopping_basket),
                onPressed: () => context.push('/fruits/cart'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(color: Colors.grey.shade200, child: const Icon(Icons.eco, size: 64, color: AppTheme.primaryGreen)),
                        )
                      : Container(color: Colors.grey.shade200, child: const Icon(Icons.eco, size: 64, color: AppTheme.primaryGreen)),
                  // Gradient for better icon visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.6), Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _fruit!['name'] ?? '',
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ),
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(width: 4),
                      Text('/KG', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary, height: 2)),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Rating Summary & Availability
                  Row(
                    children: [
                      if (_totalReviews > 0) ...[
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(_averageRating.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(' ($_totalReviews reviews)', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
                        const SizedBox(width: 16),
                      ],
                      if (!available)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            _fruit!['availability_status'] == 'out_of_stock' ? 'Out of Stock' : 'Unavailable',
                            style: GoogleFonts.inter(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('In Stock', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  Text('Description', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text(
                    _fruit!['description'] ?? 'No description available for this fruit.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
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
                          onPressed: () => context.push('/reviews/fruit/${widget.fruitId}'),
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
                    
                  const SizedBox(height: 80), // Padding for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Quantity Selector
              if (available)
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 20),
                        onPressed: _cartQuantity > 0 ? () => _updateCart(_cartQuantity - 1.0) : null,
                        color: AppTheme.primaryGreen,
                      ),
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: _isCartLoading 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : Text('${_cartQuantity.toInt()} kg', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        onPressed: () => _updateCart(_cartQuantity + 1.0),
                        color: AppTheme.primaryGreen,
                      ),
                    ],
                  ),
                ),
                
              const SizedBox(width: 16),
              
              // Add to Cart Button
              Expanded(
                child: ElevatedButton(
                  onPressed: available
                      ? (_cartQuantity == 0 ? () => _updateCart(1.0) : () => context.push('/fruits/cart'))
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    disabledBackgroundColor: Colors.grey.shade300,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _cartQuantity == 0 ? 'Add to Cart' : 'View Cart',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
