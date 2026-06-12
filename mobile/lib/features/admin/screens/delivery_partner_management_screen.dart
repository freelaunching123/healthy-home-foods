import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeliveryPartnerManagementScreen extends StatelessWidget {
  const DeliveryPartnerManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Delivery Partners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/admin/delivery-partners/create'),
          ),
        ],
      ),
      body: const Center(child: Text('Delivery Partner Management coming soon')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/delivery-partners/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
