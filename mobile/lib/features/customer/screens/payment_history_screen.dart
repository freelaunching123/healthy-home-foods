import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _api = ApiClient();
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      // Mock API call to get payment history
      // Replace with actual endpoint if available
      // final res = await _api.get(ApiConstants.paymentHistory);
      
      // Mocking data for now
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _payments = [
          {
            'id': 'pay_12345',
            'amount': 2500.0,
            'status': 'captured',
            'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
            'description': 'Monthly Subscription - Healthy Meal',
          },
          {
            'id': 'pay_12346',
            'amount': 850.0,
            'status': 'failed',
            'created_at': DateTime.now().subtract(const Duration(days: 15)).toIso8601String(),
            'description': 'Weekly Subscription - Vegan Meal',
          },
        ];
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _payments.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  color: AppTheme.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _payments.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      final isSuccess = payment['status'] == 'captured';
                      
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: isSuccess ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                            child: Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: isSuccess ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                          title: Text('₹${payment['amount'].toString()}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(payment['description'] ?? 'Payment', style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(payment['created_at'])),
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          trailing: Text(
                            (payment['status'] as String).toUpperCase(),
                            style: TextStyle(
                              color: isSuccess ? AppTheme.success : AppTheme.error,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('No payments found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Your transaction history will appear here', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
