import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/admin_drawer.dart';

class FruitManagementScreen extends StatefulWidget {
  const FruitManagementScreen({super.key});

  @override
  State<FruitManagementScreen> createState() => _FruitManagementScreenState();
}

class _FruitManagementScreenState extends State<FruitManagementScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _fruits = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterAvailability;
  bool? _filterActive;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadFruits();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFruits() async {
    setState(() { _loading = true; _error = null; });
    try {
      final params = <String, dynamic>{};
      if (_searchQuery.isNotEmpty) params['search'] = _searchQuery;
      if (_filterAvailability != null) params['availability'] = _filterAvailability!;
      if (_filterActive != null) params['is_active'] = _filterActive.toString();

      final res = await _api.get(ApiConstants.adminFruits, queryParameters: params);
      setState(() {
        _fruits = List<Map<String, dynamic>>.from(res.data as List);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load fruits.'; _loading = false; });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> fruit) async {
    try {
      await _api.patch('${ApiConstants.adminFruits}/${fruit['id']}/toggle-active', data: {});
      _loadFruits();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _changeAvailability(Map<String, dynamic> fruit, String status) async {
    try {
      await _api.patch('${ApiConstants.adminFruits}/${fruit['id']}/availability', data: {'availability_status': status});
      _loadFruits();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update availability'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _deleteFruit(Map<String, dynamic> fruit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Fruit?'),
        content: Text('This will deactivate "${fruit['name']}" and hide it from customers.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.delete('${ApiConstants.adminFruits}/${fruit['id']}');
      _loadFruits();
    } catch (_) {}
  }

  void _showAvailabilitySheet(Map<String, dynamic> fruit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set Availability', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            _AvailabilityOption(
              label: 'In Stock', icon: Icons.check_circle_rounded, color: AppTheme.success,
              selected: fruit['availability_status'] == 'in_stock',
              onTap: () { ctx.pop(); _changeAvailability(fruit, 'in_stock'); },
            ),
            _AvailabilityOption(
              label: 'Out of Stock', icon: Icons.cancel_rounded, color: AppTheme.error,
              selected: fruit['availability_status'] == 'out_of_stock',
              onTap: () { ctx.pop(); _changeAvailability(fruit, 'out_of_stock'); },
            ),
            _AvailabilityOption(
              label: 'Temporarily Unavailable', icon: Icons.pause_circle_rounded, color: AppTheme.warning,
              selected: fruit['availability_status'] == 'temporarily_unavailable',
              onTap: () { ctx.pop(); _changeAvailability(fruit, 'temporarily_unavailable'); },
            ),
          ],
        ),
      ),
    );
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
            onPressed: () => context.push('/admin/fruits/orders'),
            tooltip: 'Fruit Orders',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/fruits/add');
          _loadFruits();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text('Add Fruit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Column(
        children: [
          // Page Header
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fruit Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Configure seasonal fruits, availability, and active stock.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Search + Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search fruits...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textLight),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, color: AppTheme.textLight),
                            onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); _loadFruits(); },
                          )
                        : null,
                    filled: true, fillColor: AppTheme.scaffoldBg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    setState(() => _searchQuery = v);
                    Future.delayed(const Duration(milliseconds: 400), () { if (_searchQuery == v) _loadFruits(); });
                  },
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(label: 'All', selected: _filterActive == null && _filterAvailability == null,
                        onTap: () { setState(() { _filterActive = null; _filterAvailability = null; }); _loadFruits(); }),
                      _FilterChip(label: 'Active', selected: _filterActive == true,
                        onTap: () { setState(() { _filterActive = true; _filterAvailability = null; }); _loadFruits(); }),
                      _FilterChip(label: 'Inactive', selected: _filterActive == false,
                        onTap: () { setState(() { _filterActive = false; _filterAvailability = null; }); _loadFruits(); }),
                      _FilterChip(label: 'In Stock', selected: _filterAvailability == 'in_stock',
                        onTap: () { setState(() { _filterAvailability = 'in_stock'; _filterActive = null; }); _loadFruits(); }),
                      _FilterChip(label: 'Out of Stock', selected: _filterAvailability == 'out_of_stock',
                        onTap: () { setState(() { _filterAvailability = 'out_of_stock'; _filterActive = null; }); _loadFruits(); }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Fruit list
          Expanded(
            child: _loading
                ? _buildShimmer()
                : _error != null
                    ? _buildError()
                    : _fruits.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              itemCount: _fruits.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final fruit = _fruits[i];
                                return _FruitTile(
                                  fruit: fruit,
                                  baseUrl: _api.dio.options.baseUrl.replaceAll('/api/v1', ''),
                                  onEdit: () async {
                                    await context.push('/admin/fruits/edit/${fruit['id']}');
                                    _loadFruits();
                                  },
                                  onToggleActive: () => _toggleActive(fruit),
                                  onAvailability: () => _showAvailabilitySheet(fruit),
                                  onDelete: () => _deleteFruit(fruit),
                                );
                              },
                            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) => Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade100,
      child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
    ),
  );

  Widget _buildError() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.textLight),
      const SizedBox(height: 12),
      Text(_error!, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _loadFruits, child: const Text('Retry')),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.local_grocery_store_outlined, size: 72, color: AppTheme.accentLight),
      const SizedBox(height: 16),
      Text('No fruits added yet', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Tap + to add your first fruit', style: GoogleFonts.inter(color: AppTheme.textSecondary)),
    ]),
  );
}


class _FruitTile extends StatelessWidget {
  final Map<String, dynamic> fruit;
  final String baseUrl;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onAvailability;
  final VoidCallback onDelete;

  const _FruitTile({
    required this.fruit, required this.baseUrl,
    required this.onEdit, required this.onToggleActive,
    required this.onAvailability, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = fruit['is_active'] as bool? ?? false;
    final avail = fruit['availability_status'] as String? ?? 'in_stock';
    final price = (fruit['price_per_kg'] as num).toDouble();
    final imageUrl = fruit['image_url'] as String?;

    Color availColor = AppTheme.success;
    if (avail == 'out_of_stock') availColor = AppTheme.error;
    else if (avail == 'temporarily_unavailable') availColor = AppTheme.warning;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 60, height: 60,
                child: Container(
                  color: Colors.grey.shade100,
                  child: imageUrl != null
                      ? Image.network(
                          '$baseUrl$imageUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_outlined, color: Colors.grey, size: 24),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.image_outlined, color: Colors.grey, size: 24),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(fruit['name'] as String,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Inactive', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textLight)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('₹${price.toStringAsFixed(0)} / KG',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: availColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      avail.replaceAll('_', ' ').split(' ').map((w) => '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
                      style: GoogleFonts.inter(fontSize: 10, color: availColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textLight),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                else if (value == 'availability') onAvailability();
                else if (value == 'toggle') onToggleActive();
                else if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, size: 16), const SizedBox(width: 10), Text('Edit', style: GoogleFonts.inter())])),
                PopupMenuItem(value: 'availability', child: Row(children: [const Icon(Icons.inventory_rounded, size: 16), const SizedBox(width: 10), Text('Set Availability', style: GoogleFonts.inter())])),
                PopupMenuItem(value: 'toggle', child: Row(children: [
                  Icon(isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
                  const SizedBox(width: 10),
                  Text(isActive ? 'Deactivate' : 'Activate', style: GoogleFonts.inter()),
                ])),
                PopupMenuItem(value: 'delete', child: Row(children: [
                  const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                  const SizedBox(width: 10),
                  Text('Delete', style: GoogleFonts.inter(color: AppTheme.error)),
                ])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryGreen : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : AppTheme.textSecondary,
      )),
    ),
  );
}

class _AvailabilityOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AvailabilityOption({
    required this.label, required this.icon, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: color),
    title: Text(label, style: GoogleFonts.inter(fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
    trailing: selected ? Icon(Icons.check_rounded, color: color) : null,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    tileColor: selected ? color.withValues(alpha: 0.06) : null,
  );
}
