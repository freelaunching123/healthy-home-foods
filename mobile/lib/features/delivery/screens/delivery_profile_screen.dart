import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';

class DeliveryProfileScreen extends StatelessWidget {
  const DeliveryProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) context.go('/role-selection');
            },
          ),
        ],
      ),
      body: const Center(child: Text('Delivery Boy Profile coming soon')),
    );
  }
}
