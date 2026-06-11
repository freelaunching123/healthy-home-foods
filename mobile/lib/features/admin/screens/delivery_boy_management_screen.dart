import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeliveryBoyManagementScreen extends StatelessWidget {
  const DeliveryBoyManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Delivery Boys'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/admin/delivery-boys/create'),
          ),
        ],
      ),
      body: const Center(child: Text('Delivery Boy Management coming soon')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/delivery-boys/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
