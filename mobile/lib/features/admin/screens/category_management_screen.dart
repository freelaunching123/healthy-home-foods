import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _api = ApiClient();
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.categories, queryParameters: {
        'active_only': false,
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
                  Text(category == null ? 'Add Category' : 'Edit Category',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active Status'),
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
                            final payload = {
                              'name': nameCtrl.text,
                              'slug': nameCtrl.text.toLowerCase().replaceAll(' ', '-'),
                              'description': descCtrl.text,
                              'is_active': isActive,
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
                      child: Text(category == null ? 'Create' : 'Update'),
                    ),
                  ),
                  const SizedBox(height: 24),
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
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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
            const SnackBar(content: Text('Category deleted successfully')),
          );
        }
      } catch (e) {
        _loadCategories(); // refresh anyway to be safe
        if (mounted) {
          String errMsg = 'Error deleting category: $e';
          try {
            final dioErr = e as dynamic;
            if (dioErr.response?.data != null && dioErr.response.data['detail'] != null) {
              errMsg = dioErr.response.data['detail'];
            }
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _categories.length,
              itemBuilder: (ctx, i) {
                final cat = _categories[i];
                final isActive = cat['is_active'] == true;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(cat['name'] ?? ''),
                    subtitle: Text(cat['description'] ?? 'No description'),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(isActive ? 'Active' : 'Inactive',
                              style: TextStyle(color: isActive ? Colors.green : Colors.red, fontSize: 12)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
                          onPressed: () => _showCategoryForm(cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmDeleteCategory(cat),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryGreen,
        onPressed: () => _showCategoryForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
