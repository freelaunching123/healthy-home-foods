import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';

class DeliveryDashboardScreen extends StatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  State<DeliveryDashboardScreen> createState() => _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState extends State<DeliveryDashboardScreen> {
  final _api = ApiClient();
  List<dynamic> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.deliveriesAssigned);
      setState(() {
        _assignments = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading assignments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _assignments.isEmpty
              ? const Center(child: Text('No active deliveries'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final task = _assignments[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text('Order #${task['delivery_id']?.toString().substring(0, 8) ?? ''}'),
                        subtitle: Text(task['status'] ?? 'Pending'),
                        trailing: ElevatedButton(
                          onPressed: () => context.push('/delivery/order/${task['id']}'),
                          child: const Text('View'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
