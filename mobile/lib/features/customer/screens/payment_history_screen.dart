import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
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
  String? _downloadingPaymentId;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.paymentHistory);
      setState(() {
        _payments = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() {
        _payments = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadInvoice(String paymentId) async {
    setState(() => _downloadingPaymentId = paymentId);
    try {
      final response = await _api.dio.get(
        '/payments/$paymentId/invoice',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/invoice_$paymentId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        await Share.shareXFiles(
          [XFile(filePath, mimeType: 'application/pdf')],
          subject: 'Payment Invoice #$paymentId',
          text: 'Here is your payment invoice from Healthy Home Foods.',
        );
      }
    } catch (e) {
      debugPrint('Error downloading invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download invoice'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _downloadingPaymentId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
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
                      final id = payment['id'];
                      final isSuccess = payment['status'] == 'success';
                      final isDownloading = _downloadingPaymentId == id;
                      
                      final dateStr = payment['paid_at'] != null
                          ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(payment['paid_at']))
                          : (payment['created_at'] != null 
                              ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(payment['created_at']))
                              : '—');

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: isSuccess ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.error.withValues(alpha: 0.1),
                            child: Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: isSuccess ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                          title: Text(
                            '₹${payment['amount']}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Method: ${(payment['payment_method'] ?? 'Razorpay').toString().toUpperCase()}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dateStr,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          trailing: isSuccess
                              ? (isDownloading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.download_for_offline_outlined, color: AppTheme.primaryGreen),
                                      onPressed: () => _downloadInvoice(id),
                                      tooltip: 'Download Invoice',
                                    ))
                              : Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (payment['status'] as String).toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
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
