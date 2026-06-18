import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  
  List<dynamic> get _featuredProducts => _products.where((p) => p['is_featured'] == true || p['is_popular'] == true).toList();
  List<dynamic> get _todaySpecials => _products.where((p) => p['is_today_special'] == true).toList();

  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final catRes = await _api.get(ApiConstants.categories, queryParameters: {'active_only': true});
      final prodRes = await _api.get(ApiConstants.products, queryParameters: {
        'page_size': 100,
        'status': 'published',
        'active_only': true,
      });
      setState(() {
        _categories = catRes.data is List ? catRes.data : [];
        _products = prodRes.data['items'] ?? [];
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredProducts {
    var filtered = _products;
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p['category_id'] == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
              // Header & Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🥗 Healthy Home Foods', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                      const SizedBox(height: 2),
                      const Text('Fresh meals, delivered daily', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search healthy food packs...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Dynamic Today's Special
              if (_todaySpecials.isNotEmpty && _searchQuery.isEmpty && _selectedCategoryId == null)
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text("Today's Special", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _todaySpecials.length,
                          itemBuilder: (ctx, i) => _SpecialCard(product: _todaySpecials[i]),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

              // Category tabs
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _CategoryChip(label: 'All', isSelected: _selectedCategoryId == null, onTap: () => setState(() => _selectedCategoryId = null)),
                      ..._categories.map((cat) => _CategoryChip(
                        label: cat['name'] ?? '',
                        isSelected: _selectedCategoryId == cat['id'],
                        onTap: () => setState(() => _selectedCategoryId = cat['id']),
                      )),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Product grid
              if (_isLoading)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    delegate: SliverChildBuilderDelegate((_, __) => _ShimmerCard(), childCount: 4),
                  ),
                )
              else if (_filteredProducts.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu, size: 48, color: AppTheme.textLight),
                      SizedBox(height: 12),
                      Text('No products found', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  )),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _ProductCard(product: _filteredProducts[i]),
                      childCount: _filteredProducts.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecialCard extends StatelessWidget {
  final dynamic product;
  const _SpecialCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/product/${product['id']}'),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: product['image_url'] != null 
              ? DecorationImage(image: NetworkImage('http://10.0.2.2:8000${product['image_url']}'), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken))
              : null,
          color: AppTheme.primaryGreen,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)),
                child: const Text('🌟 SPECIAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              Text(product['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('₹${product['price']}', style: const TextStyle(fontSize: 16, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final double price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
    final double? discountPrice = product['discount_price'] != null ? double.tryParse(product['discount_price'].toString()) : null;
    final bool isOutOfStock = product['availability'] != 'available';

    return GestureDetector(
      onTap: () => context.push('/product/${product['id']}'),
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image placeholder
              Stack(
                children: [
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: product['image_url'] != null
                        ? ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.network(
                              'http://10.0.2.2:8000${product['image_url']}',
                              fit: BoxFit.cover, width: double.infinity, height: 110,
                              errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen),
                            ),
                          )
                        : const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen),
                    ),
                  ),
                  if (isOutOfStock)
                    Container(
                      height: 110,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                      child: const Center(child: Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    ),
                  if (!isOutOfStock && product['is_featured'] == true)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                        child: const Text('FEATURED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? '', style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        children: [
                          if (discountPrice != null) ...[
                            Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                            const SizedBox(width: 4),
                            Text('₹${discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                          ] else ...[
                            Text('₹${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                          ],
                        ],
                      ),
                    ],
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

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
