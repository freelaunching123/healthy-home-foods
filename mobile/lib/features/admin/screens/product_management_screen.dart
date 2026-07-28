import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../widgets/admin_drawer.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _api = ApiClient();
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _availabilityFilter;
  String? _selectedCategoryId;
  List<dynamic> _categories = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }
  
  Future<void> _initData() async {
    await _loadCategories();
    _loadProducts();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await _api.get(ApiConstants.categories, queryParameters: {'active_only': true});
      if (mounted) setState(() => _categories = res.data ?? []);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.products, queryParameters: {
        'page_size': 100,
        'active_only': false,
        if (_searchQuery.isNotEmpty) 'search': _searchQuery,
        if (_availabilityFilter != null) 'availability': _availabilityFilter,
        if (_selectedCategoryId != null) 'category_id': _selectedCategoryId,
      });
      setState(() => _products = res.data['items'] ?? []);
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleProductActive(dynamic product) async {
    try {
      if (product['is_active'] == true) {
        await _api.delete('${ApiConstants.products}/${product['id']}');
      } else {
        await _api.post('${ApiConstants.products}/${product['id']}/restore');
      }
      _loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorHandler.getMessage(e)), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _hardDeleteProduct(dynamic product) async {
    try {
      await _api.delete('${ApiConstants.products}/${product['id']}/hard');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product permanently deleted'), backgroundColor: AppTheme.primaryGreen));
      _loadProducts();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiErrorHandler.getMessage(e)), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.scaffoldBg,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu, size: 28),
          color: AppTheme.textPrimary,
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF0F0F0), height: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryGreen),
            onPressed: () => context.push('/admin/packages/orders'),
            tooltip: 'Package Orders',
          ),
        ],
      ),
      body: Column(
        children: [

          // Filters & Search
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textLight),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                              _loadProducts();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.scaffoldBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (_searchQuery == v) _loadProducts();
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Availability', ['available', 'out_of_stock', 'temporarily_unavailable'], _availabilityFilter, (v) {
                        setState(() => _availabilityFilter = v);
                        _loadProducts();
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Category Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryTab(
                        label: 'All Categories',
                        isSelected: _selectedCategoryId == null,
                        onTap: () {
                          setState(() => _selectedCategoryId = null);
                          _loadProducts();
                        },
                      ),
                      ..._categories.map((cat) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _CategoryTab(
                              label: cat['name'],
                              isSelected: _selectedCategoryId == cat['id'],
                              onTap: () {
                                setState(() => _selectedCategoryId = cat['id']);
                                _loadProducts();
                              },
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _products.isEmpty
                        ? const Center(child: Text('No products found.'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _products.length,
                            itemBuilder: (context, index) {
                              final product = _products[index];
                              return _ProductAdminCard(
                                product: product,
                                onToggleActive: () => _toggleProductActive(product),
                                onHardDelete: () => _hardDeleteProduct(product),
                                onEdit: () => context.push('/admin/products/edit/${product['id']}').then((_) => _loadProducts()),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/products/add').then((_) => _loadProducts()),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildFilterChip(String label, List<String> options, String? currentValue, ValueChanged<String?> onChanged) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text('All $label')),
        ...options.map((opt) => PopupMenuItem(value: opt, child: Text(opt.replaceAll('_', ' ').toUpperCase()))),
      ],
      child: Chip(
        label: Text(currentValue != null ? currentValue.replaceAll('_', ' ').toUpperCase() : label),
        backgroundColor: currentValue != null ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.grey.shade100,
        labelStyle: TextStyle(color: currentValue != null ? AppTheme.primaryGreen : AppTheme.textSecondary),
        deleteIcon: currentValue != null ? const Icon(Icons.close, size: 16) : null,
        onDeleted: currentValue != null ? () => onChanged(null) : null,
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ProductAdminCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onToggleActive;
  final VoidCallback onHardDelete;
  final VoidCallback onEdit;

  const _ProductAdminCard({required this.product, required this.onToggleActive, required this.onHardDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final bool isActive = product['is_active'] == true;
    final String availability = product['availability'] ?? 'unknown';
    final mediaBaseUrl = ApiClient().mediaBaseUrl;
    
    final imgUrl = product['image_url'] != null ? '$mediaBaseUrl${product['image_url']}' : null;
    if (imgUrl != null) debugPrint('Flutter Image Render (_ProductAdminCard): $imgUrl');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isActive ? Colors.grey.shade200 : Colors.red.shade200, width: isActive ? 1 : 1.5),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.6,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imgUrl != null
                        ? Image.network(
                            imgUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product['name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product['is_featured'] == true)
                            const Icon(Icons.star, color: Colors.amber, size: 18),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${product['plan_type']?.toString().toUpperCase() ?? 'PLAN'} (${product['package_days']} Days): ₹${product['package_price']}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildBadge(availability.replaceAll('_', ' '), _getAvailabilityColor(availability)),
                          if (!isActive) _buildBadge('Soft Deleted', Colors.red),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Actions
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'deactivate') onToggleActive();
                    if (val == 'restore') onToggleActive();
                    if (val == 'hard_delete') _confirmHardDelete(context, product);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isActive)
                      const PopupMenuItem(
                        value: 'deactivate',
                        child: Text('Deactivate (Soft Delete)', style: TextStyle(color: Colors.orange)),
                      ),
                    if (!isActive)
                      const PopupMenuItem(
                        value: 'restore',
                        child: Text('Activate (Restore)', style: TextStyle(color: Colors.green)),
                      ),
                    const PopupMenuItem(
                      value: 'hard_delete',
                      child: Text('Complete Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmHardDelete(BuildContext context, dynamic product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permanent Delete', style: TextStyle(color: Colors.red)),
        content: Text('Are you sure you want to completely delete "${product['name']}" from the database? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              onHardDelete();
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Color _getAvailabilityColor(String avail) {
    if (avail == 'available') return AppTheme.primaryGreen;
    return Colors.red;
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
