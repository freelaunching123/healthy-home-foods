import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AddProductScreen extends StatelessWidget {
  final String? productId;
  const AddProductScreen({super.key, this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(productId == null ? 'Add Product' : 'Edit Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Text('Product Form coming soon'),
      ),
    );
  }
}
