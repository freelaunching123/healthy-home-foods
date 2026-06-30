import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/local_storage_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();
  
  // -- Shared State --
  Timer? _pollingTimer;
  String _searchQuery = '';
  int _selectedTabIndex = 0; // 0 = Packages, 1 = Fruits

  // -- Packages State --
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String? _selectedCategoryId;
  bool _isLoadingPackages = true;
  
  List<dynamic> get _featuredProducts => _products.where((p) => p['is_featured'] == true || p['is_popular'] == true).toList();
  List<dynamic> get _todaySpecials => _products.where((p) => p['is_today_special'] == true).toList();

  // -- Fruits State --
  List<Map<String, dynamic>> _fruits = [];
  bool _isLoadingFruits = true;
  int _cartCount = 0;
  final Map<String, double> _quantities = {};
  
  // -- Package Cart State --
  int _packageCartCount = 0;
  final Map<String, int> _packageQuantities = {};
  
  // -- Recently Viewed State --
  List<Map<String, dynamic>> _recentlyViewedPackages = [];
  List<Map<String, dynamic>> _recentlyViewedFruits = [];

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadFruits();
    _loadCartCount();
    _loadPackageCartCount();
    _loadRecentlyViewed();
    _startPolling();
  }

  Future<void> _loadRecentlyViewed() async {
    final packages = await LocalStorageService.getRecentlyViewed('package');
    final fruits = await LocalStorageService.getRecentlyViewed('fruit');
    if (mounted) {
      setState(() {
        _recentlyViewedPackages = packages;
        _recentlyViewedFruits = fruits;
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _loadPackages(isSilent: true);
      _loadFruits(isSilent: true);
      _loadCartCount();
      _loadPackageCartCount();
    });
  }

  // ── PACKAGES LOGIC ────────────────────────────────────────────────────────

  Future<void> _loadPackages({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoadingPackages = true);
    try {
      final catRes = await _api.get(ApiConstants.categories, queryParameters: {'active_only': true, 'category_type': 'package'});
      final prodRes = await _api.get(ApiConstants.products, queryParameters: {
        'page_size': 100,
        'status': 'published',
        'active_only': true,
      });
      if (mounted) {
        setState(() {
          _categories = catRes.data is List ? catRes.data : [];
          _products = prodRes.data['items'] ?? [];

          // Reset category if no longer exists
          if (_selectedCategoryId != null) {
            if (!_categories.any((c) => c['id'] == _selectedCategoryId)) {
              _selectedCategoryId = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading packages: $e');
    } finally {
      if (!isSilent && mounted) setState(() => _isLoadingPackages = false);
    }
  }

  List<dynamic> get _filteredPackages {
    var filtered = _products;
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p['category_id'] == _selectedCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) => (p['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  // ── FRUITS LOGIC ──────────────────────────────────────────────────────────

  Future<void> _loadFruits({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoadingFruits = true);
    try {
      final res = await _api.get(ApiConstants.fruits);
      if (mounted) {
        setState(() {
          _fruits = List<Map<String, dynamic>>.from(res.data as List);
        });
      }
    } catch (e) {
      debugPrint('Error loading fruits: $e');
    } finally {
      if (!isSilent && mounted) setState(() => _isLoadingFruits = false);
    }
  }

  List<Map<String, dynamic>> get _filteredFruits {
    if (_searchQuery.isEmpty) return _fruits;
    return _fruits.where((f) => (f['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ── PACKAGE CART LOGIC ──────────────────────────────────────────────────────

  Future<void> _loadPackageCartCount() async {
    try {
      final res = await _api.get(ApiConstants.packageCart);
      final items = res.data['items'] as List? ?? [];
      final Map<String, int> newQuantities = {};
      for (var item in items) {
        if (item['product_id'] != null) {
          newQuantities[item['product_id'].toString()] = (item['quantity'] as num).toInt();
        }
      }
      if (mounted) {
        setState(() {
          _packageCartCount = items.length;
          _packageQuantities.clear();
          _packageQuantities.addAll(newQuantities);
        });
      }
    } catch (_) {}
  }

  Future<void> _addToPackageCart(Map<String, dynamic> package, int qty) async {
    if (qty <= 0) {
      await _removeFromPackageCart(package);
      return;
    }
    try {
      await _api.post(ApiConstants.packageCartAdd, data: {
        'product_id': package['id'],
        'quantity': qty,
      });
      _loadPackageCartCount();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update cart: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _removeFromPackageCart(Map<String, dynamic> package) async {
    try {
      final res = await _api.get(ApiConstants.packageCart);
      final items = res.data['items'] as List? ?? [];
      final cartItem = items.firstWhere((item) => item['product_id'] == package['id'], orElse: () => null);
      if (cartItem != null) {
        await _api.delete('${ApiConstants.packageCart}/${cartItem['id']}');
      }
      _loadPackageCartCount();
    } catch (_) {}
  }

  void _onPackageQtyChanged(Map<String, dynamic> package, int newQty) {
    final id = package['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _packageQuantities[id] = newQty < 0 ? 0 : newQty);
    if (newQty > 0) {
      _addToPackageCart(package, newQty);
    } else {
      _removeFromPackageCart(package);
    }
  }

  // ── FRUIT CART LOGIC ────────────────────────────────────────────────────────

  Future<void> _loadCartCount() async {
    try {
      final res = await _api.get(ApiConstants.fruitCart);
      final items = res.data['items'] as List? ?? [];
      final Map<String, double> newQuantities = {};
      for (var item in items) {
        if (item['fruit_id'] != null) {
          newQuantities[item['fruit_id'].toString()] = (item['quantity_kg'] as num).toDouble();
        }
      }
      if (mounted) {
        setState(() {
          _cartCount = items.length;
          _quantities.clear();
          _quantities.addAll(newQuantities);
        });
      }
    } catch (_) {}
  }

  Future<void> _addToCart(Map<String, dynamic> fruit, double qty) async {
    if (qty <= 0) {
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update cart: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _removeFromCart(Map<String, dynamic> fruit) async {
    try {
      final res = await _api.get(ApiConstants.fruitCart);
      final items = res.data['items'] as List? ?? [];
      final cartItem = items.firstWhere((item) => item['fruit_id'] == fruit['id'], orElse: () => null);
      if (cartItem != null) {
        await _api.delete('${ApiConstants.fruitCart}/${cartItem['id']}');
      }
      _loadCartCount();
    } catch (_) {}
  }

  void _onQtyChanged(Map<String, dynamic> fruit, double newQty) {
    final id = fruit['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _quantities[id] = newQty < 0 ? 0 : newQty);
    if (newQty > 0) {
      _addToCart(fruit, newQty);
    } else {
      _removeFromCart(fruit);
    }
  }

  // ── UI RENDERING ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('🥗 Healthy Home Foods', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedTabIndex == 1) // Fruit Cart
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_basket_rounded, color: AppTheme.primaryGreen),
                  onPressed: () => context.push('/fruits/cart'),
                  tooltip: 'Fruit Cart',
                ),
                if (_cartCount > 0)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                      child: Text('$_cartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            )
          else // Package Cart
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_rounded, color: AppTheme.primaryGreen),
                  onPressed: () => context.push('/packages/cart'),
                  tooltip: 'Package Cart',
                ),
                if (_packageCartCount > 0)
                  Positioned(
                    top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                      child: Text('$_packageCartCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (_selectedTabIndex == 0) await _loadPackages();
            else await _loadFruits();
          },
          color: AppTheme.primaryGreen,
          child: CustomScrollView(
            slivers: [
              // Search & Segmented Switch
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fresh meals, delivered daily', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      const SizedBox(height: 16),
                      // Segmented Switch
                      Container(
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() { _selectedTabIndex = 0; _searchQuery = ''; }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTabIndex == 0 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedTabIndex == 0 ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Packages', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedTabIndex == 0 ? AppTheme.primaryGreen : AppTheme.textLight)),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() { _selectedTabIndex = 1; _searchQuery = ''; }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _selectedTabIndex == 1 ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('Fruits', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedTabIndex == 1 ? AppTheme.primaryGreen : AppTheme.textLight)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Search Field
                      TextField(
                        key: ValueKey('search_$_selectedTabIndex'), // Force rebuild to clear visually
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: _selectedTabIndex == 0 ? 'Search healthy food packs...' : 'Search fresh fruits...',
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

              if (_selectedTabIndex == 0) ..._buildPackagesSlivers(),
              if (_selectedTabIndex == 1) ..._buildFruitsSlivers(),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ── PACKAGES UI SLIVERS ───────────────────────────────────────────────────
  
  List<Widget> _buildPackagesSlivers() {
    return [
      if (_recentlyViewedPackages.isNotEmpty && _searchQuery.isEmpty && _selectedCategoryId == null)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text("Recently Viewed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recentlyViewedPackages.length,
                  itemBuilder: (ctx, i) {
                    final product = _recentlyViewedPackages[i];
                    final productId = product['id']?.toString() ?? '';
                    return SizedBox(
                      width: 150, 
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12), 
                        child: _ProductCard(
                          product: product,
                          quantity: _packageQuantities[productId] ?? 0,
                          onQtyChanged: (newQty) => _onPackageQtyChanged(product, newQty),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
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
      if (_isLoadingPackages)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate((_, __) => _ShimmerCard(), childCount: 4),
          ),
        )
      else if (_filteredPackages.isEmpty)
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu, size: 48, color: AppTheme.textLight),
                  SizedBox(height: 12),
                  Text('No packages found', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final productId = _filteredPackages[i]['id']?.toString() ?? '';
                return _ProductCard(
                  product: _filteredPackages[i],
                  quantity: _packageQuantities[productId] ?? 0,
                  onQtyChanged: (newQty) => _onPackageQtyChanged(_filteredPackages[i], newQty),
                );
              },
              childCount: _filteredPackages.length,
            ),
          ),
        ),
    ];
  }

  // ── FRUITS UI SLIVERS ─────────────────────────────────────────────────────

  List<Widget> _buildFruitsSlivers() {
    return [
      if (_isLoadingFruits)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate((_, __) => _ShimmerCard(), childCount: 4),
          ),
        )
      else if (_filteredFruits.isEmpty)
        const SliverToBoxAdapter(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Column(
                children: [
                  Icon(Icons.local_grocery_store_outlined, size: 72, color: AppTheme.accentLight),
                  SizedBox(height: 16),
                  Text('No fruits found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 12, mainAxisSpacing: 12),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final fruitId = _filteredFruits[i]['id']?.toString() ?? '';
                return _FruitCard(
                  fruit: _filteredFruits[i],
                  quantity: _quantities[fruitId] ?? 0,
                  onQtyChanged: (newQty) => _onQtyChanged(_filteredFruits[i], newQty),
                  baseUrl: _api.dio.options.baseUrl.replaceAll('/api/v1', ''),
                );
              },
              childCount: _filteredFruits.length,
            ),
          ),
        ),
    ];
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
    );
  }
}

// ── Packages Widgets ───────────────────────────────────────────────────────

class _SpecialCard extends StatelessWidget {
  final dynamic product;
  const _SpecialCard({required this.product});
  @override
  Widget build(BuildContext context) {
    final mediaBaseUrl = ApiClient().mediaBaseUrl;
    final imgUrl = product['image_url'] != null ? '$mediaBaseUrl${product['image_url']}' : null;
    if (imgUrl != null) debugPrint('Flutter Image Render (_SpecialCard): $imgUrl');
    
    return GestureDetector(
      onTap: () => context.push('/product/${product['id']}'),
      child: Container(
        width: 280, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: imgUrl != null ? DecorationImage(image: NetworkImage(imgUrl), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken)) : null,
          color: AppTheme.primaryGreen,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(8)), child: const Text('🌟 SPECIAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
              const SizedBox(height: 8),
              Text(product['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Starts at ₹${product['package_price'] ?? 0}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
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
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppTheme.textSecondary)),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final dynamic product;
  final int quantity;
  final Function(int) onQtyChanged;
  
  const _ProductCard({required this.product, required this.quantity, required this.onQtyChanged});
  @override
  Widget build(BuildContext context) {
    final double packagePrice = double.tryParse(product['package_price']?.toString() ?? '0') ?? 0;
    final double? discountPrice = product['discount_price'] != null ? double.tryParse(product['discount_price'].toString()) : null;
    final bool isOutOfStock = product['availability'] != 'available';
    final mediaBaseUrl = ApiClient().mediaBaseUrl;
    
    final imgUrl = product['image_url'] != null ? '$mediaBaseUrl${product['image_url']}' : null;
    if (imgUrl != null) debugPrint('Flutter Image Render (_ProductCard): $imgUrl');

    return GestureDetector(
      onTap: () {
        LocalStorageService.addRecentlyViewed('package', product);
        context.push('/product/${product['id']}');
      },
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 110,
                    decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                    child: Center(
                      child: imgUrl != null
                        ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(imgUrl, fit: BoxFit.cover, width: double.infinity, height: 110, errorBuilder: (_, __, ___) => const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen)))
                        : const Icon(Icons.eco_rounded, size: 40, color: AppTheme.primaryGreen),
                    ),
                  ),
                  if (isOutOfStock)
                    Container(height: 110, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))), child: const Center(child: Text('OUT OF STOCK', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
                  if (!isOutOfStock && product['is_featured'] == true)
                    Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)), child: const Text('FEATURED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product['name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (product['description'] != null)
                        Text(product['description'], style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${product['package_days'] ?? 6} Days', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                              Row(
                                children: [
                                  if (discountPrice != null) ...[
                                    Text('₹${packagePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                    const SizedBox(width: 4),
                                    Text('₹${discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                  ] else ...[
                                    Text('₹${packagePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (isOutOfStock)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Add to Cart', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            )
                          else if (quantity == 0)
                            InkWell(
                              onTap: () => onQtyChanged(1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                              ),
                            )
                          else
                            Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () => onQtyChanged(quantity - 1),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Icon(Icons.remove, size: 14, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                  Text('$quantity', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                                  InkWell(
                                    onTap: () => onQtyChanged(quantity + 1),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Icon(Icons.add, size: 14, color: AppTheme.primaryGreen),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ── Fruits Widgets ─────────────────────────────────────────────────────────

class _FruitCard extends StatelessWidget {
  final Map<String, dynamic> fruit;
  final double quantity;
  final ValueChanged<double> onQtyChanged;
  final String baseUrl;

  const _FruitCard({required this.fruit, required this.quantity, required this.onQtyChanged, required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    final available = fruit['availability_status'] == 'in_stock' && fruit['is_active'] == true;
    final price = (fruit['price_per_kg'] as num?)?.toDouble() ?? 0;
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

    return GestureDetector(
      onTap: () {
        LocalStorageService.addRecentlyViewed('fruit', fruit);
        final fruitId = fruit['id']?.toString() ?? '';
        if (fruitId.isNotEmpty) context.push('/fruits/$fruitId');
      },
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: fullImageUrl != null
                    ? CachedNetworkImage(imageUrl: fullImageUrl, fit: BoxFit.cover, placeholder: (_, __) => Container(color: AppTheme.scaffoldBg, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (_, __, ___) => _FruitPlaceholder(name: (fruit['name'] ?? 'Fruit').toString()))
                    : _FruitPlaceholder(name: (fruit['name'] ?? 'Fruit').toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((fruit['name'] ?? 'Fruit').toString(), style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('₹${price.toStringAsFixed(0)} / KG', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                  if (!available && statusLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 9, color: statusColor, fontWeight: FontWeight.w600))),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: available
                  ? _QtyStepper(quantity: quantity, onChanged: onQtyChanged)
                  : Center(child: Text(statusLabel.isEmpty ? 'Unavailable' : statusLabel, style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textLight))),
            ),
          ],
        ),
      ),
    );
  }
}

class _FruitPlaceholder extends StatelessWidget {
  final String name;
  const _FruitPlaceholder({required this.name});
  static const _emojiMap = {'apple': '🍎', 'banana': '🍌', 'orange': '🍊', 'pomegranate': '🍎', 'papaya': '🥭', 'watermelon': '🍉', 'pineapple': '🍍', 'guava': '🍈', 'grapes': '🍇', 'mango': '🥭', 'grape': '🍇'};
  @override
  Widget build(BuildContext context) {
    final key = name.toLowerCase();
    final emoji = _emojiMap.entries.where((e) => key.contains(e.key)).map((e) => e.value).firstOrNull ?? '🍑';
    return Container(color: AppTheme.scaffoldBg, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 48))));
  }
}

class _QtyStepper extends StatelessWidget {
  final double quantity;
  final ValueChanged<double> onChanged;
  const _QtyStepper({required this.quantity, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (quantity <= 0) {
      return SizedBox(
        height: 32,
        child: ElevatedButton.icon(
          onPressed: () => onChanged(1),
          icon: const Icon(Icons.add_rounded, size: 14),
          label: Text('Add', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 32), padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      );
    }
    return Container(
      height: 32, decoration: BoxDecoration(border: Border.all(color: AppTheme.primaryGreen), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(child: GestureDetector(onTap: () => onChanged((quantity - 0.5).clamp(0, 999)), child: Container(decoration: const BoxDecoration(color: AppTheme.scaffoldBg, borderRadius: BorderRadius.horizontal(left: Radius.circular(7))), child: const Center(child: Icon(Icons.remove_rounded, size: 14, color: AppTheme.primaryGreen))))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('${quantity % 1 == 0 ? quantity.toInt() : quantity} KG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
          Expanded(child: GestureDetector(onTap: () => onChanged(quantity + 0.5), child: Container(decoration: const BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.horizontal(right: Radius.circular(7))), child: const Center(child: Icon(Icons.add_rounded, size: 14, color: Colors.white))))),
        ],
      ),
    );
  }
}
