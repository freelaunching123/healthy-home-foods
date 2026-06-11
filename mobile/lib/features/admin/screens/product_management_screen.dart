import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final _api = ApiClient();
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.products, queryParameters: {'page_size': 100});
      setState(() => _products = res.data['items'] ?? []);
    } catch (e) {
      debugPrint('Error loading products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/admin/products/add'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : RefreshIndicator(
              onRefresh: _loadProducts,
              color: AppTheme.primaryGreen,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        backgroundImage: product['image_url'] != null 
                            ? NetworkImage('http://10.0.2.2:8000${product['image_url']}') 
                            : null,
                        child: product['image_url'] == null ? const Icon(Icons.eco, color: AppTheme.primaryGreen) : null,
                      ),
                      title: Text(product['name'] ?? 'Unknown'),
                      subtitle: Text('₹${product['price_per_unit']} / ${product['unit']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: AppTheme.primaryGreen),
                        onPressed: () => context.push('/admin/products/edit/${product['id']}'),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/products/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
