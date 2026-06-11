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
      final catRes = await _api.get(ApiConstants.categories);
      final prodRes = await _api.get(ApiConstants.products, queryParameters: {
        'page_size': 50,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
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
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) =>
      (p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🥗 Healthy Home Foods',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                const SizedBox(height: 2),
                                Text('Fresh meals, delivered daily',
                                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.search_rounded, color: AppTheme.primaryGreen),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search bar
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search healthy food packs...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Banner
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Subscribe & Save', style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('Weekly 6 deliveries | Monthly 26 deliveries',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Explore Plans',
                                style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const Text('🥗', style: TextStyle(fontSize: 60)),
                    ],
                  ),
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
                      _CategoryChip(label: 'All', isSelected: _selectedCategoryId == null,
                        onTap: () { setState(() => _selectedCategoryId = null); _loadData(); }),
                      ..._categories.map((cat) => _CategoryChip(
                        label: cat['name'] ?? '',
                        isSelected: _selectedCategoryId == cat['id'],
                        onTap: () { setState(() => _selectedCategoryId = cat['id']); _loadData(); },
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
    final price = double.tryParse(product['price_per_unit']?.toString() ?? '0') ?? 0;
    return GestureDetector(
      onTap: () => context.push('/product/${product['id']}'),
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
                        Text('₹${price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                        Text('/${product['unit'] ?? 'pack'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
