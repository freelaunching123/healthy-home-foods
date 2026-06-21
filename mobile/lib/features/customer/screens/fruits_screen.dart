import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class FruitsScreen extends StatefulWidget {
  const FruitsScreen({super.key});

  @override
  State<FruitsScreen> createState() => _FruitsScreenState();
}

class _FruitsScreenState extends State<FruitsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _fruits = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Map: fruit_id -> quantity (local stepper state)
  final Map<String, double> _quantities = {};
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFruits();
    _loadCartCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFruits() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.fruits,
          queryParameters: _searchQuery.isNotEmpty ? {'search': _searchQuery} : null);
      setState(() {
        _fruits = List<Map<String, dynamic>>.from(res.data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load fruits. Please try again.'; _loading = false; });
    }
  }

  Future<void> _loadCartCount() async {
    try {
      final res = await _api.get(ApiConstants.fruitCart);
      final items = res.data['items'] as List? ?? [];
      if (mounted) setState(() => _cartCount = items.length);
    } catch (_) {}
  }

  Future<void> _addToCart(Map<String, dynamic> fruit, double qty) async {
    if (qty <= 0) {
      // Remove from cart
      await _removeFromCart(fruit);
      return;
    }
    try {
      await _api.post(ApiConstants.fruitCartAdd, data: {
        'fruit_id': fruit['id'],
        'quantity_kg': qty,
      });
      _loadCartCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update cart: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _removeFromCart(Map<String, dynamic> fruit) async {
    try {
      // Get cart and find item for this fruit
      final res = await _api.get(ApiConstants.fruitCart);
      final items = res.data['items'] as List? ?? [];
      final cartItem = items.firstWhere(
        (item) => item['fruit_id'] == fruit['id'],
        orElse: () => null,
      );
      if (cartItem != null) {
        await _api.delete('${ApiConstants.fruitCart}/${cartItem['id']}');
      }
      _loadCartCount();
    } catch (_) {}
  }

  void _onQtyChanged(Map<String, dynamic> fruit, double newQty) {
    final id = fruit['id'] as String;
    setState(() => _quantities[id] = newQty < 0 ? 0 : newQty);
    if (newQty > 0) {
      _addToCart(fruit, newQty);
    } else {
      _removeFromCart(fruit);
    }
  }

  bool _isAvailable(Map<String, dynamic> fruit) =>
      fruit['availability_status'] == 'in_stock' && fruit['is_active'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Fresh Fruits', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_basket_rounded, color: AppTheme.primaryGreen),
                onPressed: () => context.push('/fruits/cart'),
                tooltip: 'My Cart',
              ),
              if (_cartCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_cartCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search fruits...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: AppTheme.textLight),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _loadFruits();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.scaffoldBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) {
                setState(() => _searchQuery = v);
                Future.delayed(const Duration(milliseconds: 400), () {
                  if (_searchQuery == v) _loadFruits();
                });
              },
            ),
          ),

          // Fruit grid
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _buildError()
                    : _fruits.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppTheme.primaryGreen,
                            onRefresh: _loadFruits,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _fruits.length,
                              itemBuilder: (ctx, i) => _FruitCard(
                                fruit: _fruits[i],
                                quantity: _quantities[_fruits[i]['id'] as String] ?? 0,
                                onQtyChanged: (newQty) => _onQtyChanged(_fruits[i], newQty),
                                baseUrl: _api.dio.options.baseUrl.replaceAll('/api/v1', ''),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.72,
        crossAxisSpacing: 12, mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.textLight),
        const SizedBox(height: 12),
        Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _loadFruits,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.local_grocery_store_outlined, size: 72, color: AppTheme.accentLight),
        const SizedBox(height: 16),
        Text('No fruits found', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        Text('Try a different search term', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
      ],
    ),
  );
}


// ── Fruit Card Widget ─────────────────────────────────────────────────────────

class _FruitCard extends StatelessWidget {
  final Map<String, dynamic> fruit;
  final double quantity;
  final ValueChanged<double> onQtyChanged;
  final String baseUrl;

  const _FruitCard({
    required this.fruit,
    required this.quantity,
    required this.onQtyChanged,
    required this.baseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final available = fruit['availability_status'] == 'in_stock' && fruit['is_active'] == true;
    final price = (fruit['price_per_kg'] as num).toDouble();
    final imageUrl = fruit['image_url'] as String?;
    final fullImageUrl = imageUrl != null ? '$baseUrl$imageUrl' : null;

    String statusLabel = '';
    Color statusColor = AppTheme.success;
    if (fruit['availability_status'] == 'out_of_stock') {
      statusLabel = 'Out of Stock';
      statusColor = AppTheme.error;
    } else if (fruit['availability_status'] == 'temporarily_unavailable') {
      statusLabel = 'Unavailable';
      statusColor = AppTheme.warning;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 1.1,
              child: fullImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: fullImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.scaffoldBg,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
                      errorWidget: (_, __, ___) => _FruitPlaceholder(name: fruit['name'] as String),
                    )
                  : _FruitPlaceholder(name: fruit['name'] as String),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fruit['name'] as String,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${price.toStringAsFixed(0)} / KG',
                  style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                if (!available && statusLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 9, color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ),

          const Spacer(),

          // Qty stepper
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: available
                ? _QtyStepper(quantity: quantity, onChanged: onQtyChanged)
                : Center(
                    child: Text(
                      statusLabel.isEmpty ? 'Unavailable' : statusLabel,
                      style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textLight),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}


class _FruitPlaceholder extends StatelessWidget {
  final String name;
  const _FruitPlaceholder({required this.name});

  static const _emojiMap = {
    'apple': '🍎', 'banana': '🍌', 'orange': '🍊', 'pomegranate': '🍎',
    'papaya': '🥭', 'watermelon': '🍉', 'pineapple': '🍍', 'guava': '🍈',
    'grapes': '🍇', 'mango': '🥭', 'grape': '🍇',
  };

  @override
  Widget build(BuildContext context) {
    final key = name.toLowerCase();
    final emoji = _emojiMap.entries
        .where((e) => key.contains(e.key))
        .map((e) => e.value)
        .firstOrNull ?? '🍑';
    return Container(
      color: AppTheme.scaffoldBg,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))),
    );
  }
}


class _QtyStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;

  const _QtyStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final hasQty = quantity > 0;
    if (!hasQty) {
      return SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          onPressed: () => onChanged(1),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: Text('Add', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 32),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
    }

    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryGreen),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Minus
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged((quantity - 0.5).clamp(0, 999)),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.scaffoldBg,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(7)),
                ),
                child: const Center(
                  child: Icon(Icons.remove_rounded, size: 14, color: AppTheme.primaryGreen),
                ),
              ),
            ),
          ),
          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${quantity % 1 == 0 ? quantity.toInt() : quantity} KG',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
          ),
          // Plus
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(quantity + 0.5),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(7)),
                ),
                child: const Center(
                  child: Icon(Icons.add_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
