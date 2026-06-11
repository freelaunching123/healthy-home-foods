import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderDetailScreen extends StatelessWidget {
  final String assignmentId;
  const OrderDetailScreen({super.key, required this.assignmentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(child: Text('Order Details for $assignmentId coming soon')),
    );
  }
}
