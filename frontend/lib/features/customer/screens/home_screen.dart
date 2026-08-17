import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error_handler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();
  
  final TextEditingController _searchController = TextEditingController();
  
  // -- Shared State --
  Timer? _pollingTimer;
  String _searchQuery = '';
  int _selectedTabIndex = 0; // 0 = Packages, 1 = Fruits
  int _unreadNotificationsCount = 0;

  // -- Packages State --
  List<dynamic> _categories = [];
  List<dynamic> _products = [];
  String? _selectedCategoryId;
  bool _isLoadingPackages = true;
  
  List<dynamic> get _todaySpecials => _products.where((p) => p['is_today_special'] == true).toList();

  // -- Fruits State --
  List<dynamic> _groceryCategories = [];
  String? _selectedGroceryCategoryId;
  List<Map<String, dynamic>> _fruits = [];
  bool _isLoadingFruits = true;
  int _cartCount = 0;
  double _fruitCartTotal = 0.0;
  final Map<String, double> _quantities = {};
  
  // -- Package Cart State --
  int _packageCartCount = 0;
  double _packageCartTotal = 0.0;
  final Map<String, int> _packageQuantities = {};
  
  @override
  void initState() {
    super.initState();
    _loadPackages();
    _loadFruits();
    _loadCartCount();
    _loadPackageCartCount();
    _fetchUnreadCount();
    _startPolling();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.get(ApiConstants.notificationsUnreadCount);
      if (mounted) {
        setState(() => _unreadNotificationsCount = (res.data['count'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _loadPackages(isSilent: true);
      _loadFruits(isSilent: true);
      _loadCartCount();
      _loadPackageCartCount();
      _fetchUnreadCount();
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

  Widget _buildFloatingBottomCartBar() {
    final isFruit = _selectedTabIndex == 1;
    final count = isFruit ? _cartCount : _packageCartCount;
    if (count <= 0) return const SizedBox.shrink();

    final title = isFruit ? 'Grocery Cart' : 'Package Cart';
    final targetRoute = isFruit ? '/fruits/cart' : '/packages/cart';

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await context.push(targetRoute);
              if (mounted) {
                if (isFruit) {
                  _loadCartCount();
                  _loadFruits(isSilent: true);
                } else {
                  _loadPackageCartCount();
                  _loadPackages(isSilent: true);
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'View Cart',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────


  Future<void> _loadFruits({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoadingFruits = true);
    try {
      final catRes = await _api.get(ApiConstants.categories, queryParameters: {'active_only': true, 'category_type': 'grocery'});
      final res = await _api.get(ApiConstants.fruits);
      if (mounted) {
        setState(() {
          _groceryCategories = catRes.data is List ? catRes.data : [];
          _fruits = List<Map<String, dynamic>>.from(res.data as List);
          
          if (_selectedGroceryCategoryId != null) {
            if (!_groceryCategories.any((c) => c['id'] == _selectedGroceryCategoryId)) {
              _selectedGroceryCategoryId = null;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading fruits: $e');
    } finally {
      if (!isSilent && mounted) setState(() => _isLoadingFruits = false);
    }
  }

  List<Map<String, dynamic>> get _filteredFruits {
    var filtered = _fruits;
    if (_selectedGroceryCategoryId != null) {
      filtered = filtered.where((f) => f['category_id'] == _selectedGroceryCategoryId).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((f) => (f['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  // ── PACKAGE CART LOGIC ──────────────────────────────────────────────────────

  Future<void> _loadPackageCartCount() async {
    try {
      final res = await _api.get(ApiConstants.packageCart);
      final items = res.data['items'] as List? ?? [];
      final total = (res.data['total_amount'] as num?)?.toDouble() ?? 0.0;
      final Map<String, int> newQuantities = {};
      for (var item in items) {
        if (item['product_id'] != null) {
          newQuantities[item['product_id'].toString()] = (item['quantity'] as num).toInt();
        }
      }
      if (mounted) {
        setState(() {
          _packageCartCount = items.length;
          _packageCartTotal = total;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
          ),
        );
      }
      _loadPackageCartCount();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorHandler.getMessage(e)), backgroundColor: AppTheme.error));
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
      final total = (res.data['total_amount'] as num?)?.toDouble() ?? 0.0;
      final Map<String, double> newQuantities = {};
      for (var item in items) {
        if (item['fruit_id'] != null) {
          newQuantities[item['fruit_id'].toString()] = (item['quantity_kg'] as num).toDouble();
        }
      }
      if (mounted) {
        setState(() {
          _cartCount = items.length;
          _fruitCartTotal = total;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to cart'),
            backgroundColor: AppTheme.primaryGreen,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(bottom: 90, left: 16, right: 16),
          ),
        );
      }
      _loadCartCount();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorHandler.getMessage(e)), backgroundColor: AppTheme.error));
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
    setState(() => _quantities[id] = newQty < 0 ? 0.0 : newQty);
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
        title: const Text(
          'Healthy Home Foods',
          style: TextStyle(
            color: AppTheme.primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const RingingBellIcon(color: AppTheme.primaryGreen),
                onPressed: () async {
                  await context.push('/notifications');
                  _fetchUnreadCount();
                },
                tooltip: 'Notifications',
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
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
                                  onTap: () => setState(() {
                                    _selectedTabIndex = 0;
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
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
                                  onTap: () => setState(() {
                                    _selectedTabIndex = 1;
                                    _searchController.clear();
                                    _searchQuery = '';
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1 ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: _selectedTabIndex == 1 ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text('Groceries', style: TextStyle(fontWeight: FontWeight.bold, color: _selectedTabIndex == 1 ? AppTheme.primaryGreen : AppTheme.textLight)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Search Field
                        TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: _selectedTabIndex == 0 ? 'Search healthy food packs...' : 'Search groceries...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.cancel_rounded, size: 20, color: AppTheme.textLight),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
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

            // Floating Bottom Cart Bar (Shows ONLY when customer added items)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildFloatingBottomCartBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ── PACKAGES UI SLIVERS ───────────────────────────────────────────────────
  
  List<Widget> _buildPackagesSlivers() {
    return [

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
      if (_products.isNotEmpty) ...[
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
      ],
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
                  Icon(Icons.restaurant_menu, size: 72, color: AppTheme.accentLight),
                  SizedBox(height: 16),
                  Text('No packages found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final productId = _filteredPackages[i]['id']?.toString() ?? '';
                return _ProductCard(
                  product: _filteredPackages[i],
                  quantity: _packageQuantities[productId] ?? 0,
                  onQtyChanged: (newQty) => _onPackageQtyChanged(_filteredPackages[i], newQty),
                  onRefresh: () {
                    _loadPackageCartCount();
                    _loadPackages(isSilent: true);
                  },
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
      if (_fruits.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(label: 'All', isSelected: _selectedGroceryCategoryId == null, onTap: () => setState(() => _selectedGroceryCategoryId = null)),
                ..._groceryCategories.map((cat) => _CategoryChip(
                  label: cat['name'] ?? '',
                  isSelected: _selectedGroceryCategoryId == cat['id'],
                  onTap: () => setState(() => _selectedGroceryCategoryId = cat['id']),
                )),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
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
                  Text('No groceries found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final fruitId = _filteredFruits[i]['id']?.toString() ?? '';
                return _FruitCard(
                  fruit: _filteredFruits[i],
                  quantity: _quantities[fruitId] ?? 0.0,
                  onQtyChanged: (newQty) => _onQtyChanged(_filteredFruits[i], newQty),
                  baseUrl: _api.dio.options.baseUrl.replaceAll('/api/v1', ''),
                  onRefresh: () {
                    _loadCartCount();
                    _loadFruits(isSilent: true);
                  },
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
      child: Container(
        height: 104,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      ),
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
  final VoidCallback? onRefresh;
  
  const _ProductCard({required this.product, required this.quantity, required this.onQtyChanged, this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final double packagePrice = double.tryParse(product['package_price']?.toString() ?? '0') ?? 0;
    final double? discountPrice = product['discount_price'] != null ? double.tryParse(product['discount_price'].toString()) : null;
    final bool isOutOfStock = product['availability'] != 'available';
    final mediaBaseUrl = ApiClient().mediaBaseUrl;
    
    final imgUrl = product['image_url'] != null ? '$mediaBaseUrl${product['image_url']}' : null;

    return GestureDetector(
      onTap: () async {
        await context.push('/product/${product['id']}');
        onRefresh?.call();
      },
      child: Opacity(
        opacity: isOutOfStock ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image with Package Days badge
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 105,
                      width: double.infinity,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      child: imgUrl != null
                          ? Image.network(
                              imgUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.eco_rounded, size: 36, color: AppTheme.primaryGreen),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.eco_rounded, size: 36, color: AppTheme.primaryGreen),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product['package_days'] ?? 6} Days',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Product Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['name'] ?? '',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          if (product['description'] != null)
                            Text(
                              product['description'],
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (discountPrice != null) ...[
                                Text('₹${packagePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                                const SizedBox(width: 4),
                                Text('₹${discountPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              ] else ...[
                                Text('₹${packagePrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              ],
                            ],
                          ),
                        ],
                      ),
                      
                      // Add / Qty Control
                      if (isOutOfStock)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text('Unavailable', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w700)),
                        )
                      else if (quantity == 0)
                        InkWell(
                          onTap: () => onQtyChanged(1),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => onQtyChanged(quantity - 1),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: Icon(Icons.remove, size: 14, color: AppTheme.primaryGreen),
                                ),
                              ),
                              Text('$quantity', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                              InkWell(
                                onTap: () => onQtyChanged(quantity + 1),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  child: Icon(Icons.add, size: 14, color: AppTheme.primaryGreen),
                                ),
                              ),
                            ],
                          ),
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
  final VoidCallback? onRefresh;

  const _FruitCard({required this.fruit, required this.quantity, required this.onQtyChanged, required this.baseUrl, this.onRefresh});

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
      onTap: () async {
        final fruitId = fruit['id']?.toString() ?? '';
        if (fruitId.isNotEmpty) {
          await context.push('/fruits/$fruitId');
          onRefresh?.call();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 105,
                    width: double.infinity,
                    child: Container(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      child: fullImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: fullImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              errorWidget: (_, __, ___) => const Icon(Icons.eco_rounded, size: 36, color: AppTheme.primaryGreen),
                            )
                          : const Icon(Icons.eco_rounded, size: 36, color: AppTheme.primaryGreen),
                    ),
                  ),
                ),
                if (!available && statusLabel.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (fruit['name'] ?? 'Fruit').toString(),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${price.toStringAsFixed(0)} / KG',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                        ),
                      ],
                    ),
                    
                    // Qty Control
                    available
                        ? _QtyStepper(quantity: quantity, onChanged: onQtyChanged)
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              statusLabel.isEmpty ? 'Unavailable' : statusLabel,
                              style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textLight, fontWeight: FontWeight.w600),
                            ),
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
          onPressed: () => onChanged(1.0),
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
          Expanded(child: GestureDetector(onTap: () => onChanged((quantity - 1.0).clamp(0.0, 999.0)), child: Container(decoration: const BoxDecoration(color: AppTheme.scaffoldBg, borderRadius: BorderRadius.horizontal(left: Radius.circular(7))), child: const Center(child: Icon(Icons.remove_rounded, size: 14, color: AppTheme.primaryGreen))))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('${quantity.toInt()} KG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
          Expanded(child: GestureDetector(onTap: () => onChanged(quantity + 1.0), child: Container(decoration: const BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.horizontal(right: Radius.circular(7))), child: const Center(child: Icon(Icons.add_rounded, size: 14, color: Colors.white))))),
        ],
      ),
    );
  }
}

class RingingBellIcon extends StatefulWidget {
  final Color color;
  final double size;

  const RingingBellIcon({
    super.key,
    this.color = AppTheme.primaryGreen,
    this.size = 24.0,
  });

  @override
  State<RingingBellIcon> createState() => _RingingBellIconState();
}

class _RingingBellIconState extends State<RingingBellIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Create a realistic swinging bell rotation sequence
    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -0.22).chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.22, end: 0.22).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.22, end: -0.15).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.10).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.10, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Repeat the swinging animation continuously with a brief pause in between
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _animation.value,
          origin: const Offset(0, -9), // Pivot at the top hook of the bell
          child: child,
        );
      },
      child: Icon(
        Icons.notifications_active_rounded,
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}

