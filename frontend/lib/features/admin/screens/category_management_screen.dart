import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  final String categoryType; // 'package' or 'grocery'
  const CategoryManagementScreen({super.key, this.categoryType = 'package'});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _api = ApiClient();
  List<dynamic> _categories = [];
  bool _isLoading = true;
  late String _currentCategoryType;

  @override
  void initState() {
    super.initState();
    _currentCategoryType = widget.categoryType;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.categories, queryParameters: {
        'active_only': false,
        'category_type': _currentCategoryType,
      });
      setState(() => _categories = res.data is List ? res.data : []);
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCategoryForm([Map<String, dynamic>? category]) async {
    final nameCtrl = TextEditingController(text: category?['name'] ?? '');
    final descCtrl = TextEditingController(text: category?['description'] ?? '');
    bool isActive = category?['is_active'] ?? true;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 24,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category == null 
                      ? (_currentCategoryType == 'grocery' ? 'Add Grocery Category' : 'Add Package Category') 
                      : (_currentCategoryType == 'grocery' ? 'Edit Grocery Category' : 'Edit Package Category'),
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Category name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Active Status', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    value: isActive,
                    activeColor: AppTheme.primaryGreen,
                    onChanged: (v) => setModalState(() => isActive = v),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          try {
                            final slugStr = nameCtrl.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
                            final payload = {
                              'name': nameCtrl.text.trim(),
                              'slug': '$slugStr-${DateTime.now().millisecondsSinceEpoch}',
                              'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              'is_active': isActive,
                              'category_type': _currentCategoryType,
                            };
                            if (category == null) {
                              await _api.post(ApiConstants.categories, data: payload);
                            } else {
                              await _api.put('${ApiConstants.categories}/${category['id']}', data: payload);
                            }
                            if (ctx.mounted) ctx.pop();
                            _loadCategories();
                          } catch (e) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: Text(category == null ? 'Save Category' : 'Update Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCategory(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Category', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${category['name']}"?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _api.delete('${ApiConstants.categories}/${category['id']}');
        _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully'), backgroundColor: AppTheme.success),
          );
        }
      } catch (e) {
        _loadCategories();
        if (mounted) {
          String errMsg = 'Error deleting category';
          try {
            final dioErr = e as dynamic;
            if (dioErr.response?.data != null && dioErr.response.data['detail'] != null) {
              errMsg = dioErr.response.data['detail'];
            }
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: AppTheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Category Management', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Selector Tab Bar for Package vs Grocery Categories
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: _TabChip(
                      label: 'Package Categories',
                      icon: Icons.inventory_2_outlined,
                      isSelected: _currentCategoryType == 'package',
                      onTap: () {
                        if (_currentCategoryType != 'package') {
                          setState(() => _currentCategoryType = 'package');
                          _loadCategories();
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: _TabChip(
                      label: 'Grocery Categories',
                      icon: Icons.local_grocery_store_outlined,
                      isSelected: _currentCategoryType == 'grocery',
                      onTap: () {
                        if (_currentCategoryType != 'grocery') {
                          setState(() => _currentCategoryType = 'grocery');
                          _loadCategories();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // Category List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _currentCategoryType == 'grocery' ? Icons.local_grocery_store_outlined : Icons.inventory_2_outlined,
                              size: 64,
                              color: AppTheme.textLight,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _currentCategoryType == 'grocery' ? 'No grocery categories found' : 'No package categories found',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            Text('Tap + to create a new category', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textLight)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (ctx, i) {
                          final cat = _categories[i];
                          final isActive = cat['is_active'] == true;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              title: Text(cat['name'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                cat['description'] != null && (cat['description'] as String).isNotEmpty
                                    ? cat['description']
                                    : 'No description',
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isActive ? 'Active' : 'Inactive',
                                      style: GoogleFonts.inter(
                                        color: isActive ? Colors.green : Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: 20),
                                    onPressed: () => _showCategoryForm(cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
                                    onPressed: () => _confirmDeleteCategory(cat),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        onPressed: () => _showCategoryForm(),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          _currentCategoryType == 'grocery' ? 'Add Grocery Category' : 'Add Package Category',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
