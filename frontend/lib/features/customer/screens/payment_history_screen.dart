import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error_handler.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<dynamic> _payments = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  bool _isLoadingSummary = true;
  String? _downloadingPaymentId;
  late TabController _tabController;

  static const _statusFilters = [
    {'label': 'All', 'value': null},
    {'label': 'Success', 'value': 'success'},
    {'label': 'Pending', 'value': 'pending'},
    {'label': 'Failed', 'value': 'failed'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusFilters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadPayments();
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _currentStatus => _statusFilters[_tabController.index]['value'];

  Future<void> _loadAll() async {
    await Future.wait([_loadPayments(), _loadSummary()]);
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      final params = _currentStatus != null ? {'status': _currentStatus} : null;
      final res = await _api.get(ApiConstants.paymentHistory, queryParameters: params);
      setState(() {
        _payments = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading payments: $e');
      setState(() => _payments = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final res = await _api.get(ApiConstants.paymentSummary);
      setState(() => _summary = res.data is Map ? Map<String, dynamic>.from(res.data) : null);
    } catch (e) {
      debugPrint('Error loading payment summary: $e');
    } finally {
      setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _downloadInvoice(String paymentId) async {
    setState(() => _downloadingPaymentId = paymentId);
    try {
      final response = await _api.dio.get(
        ApiConstants.paymentInvoice(paymentId),
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/invoice_$paymentId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not open file: ${result.message}'), backgroundColor: AppTheme.error),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error downloading invoice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download invoice: ${ApiErrorHandler.getMessage(e)}'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _downloadingPaymentId = null);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success': return AppTheme.success;
      case 'pending': return AppTheme.warning;
      case 'failed': return AppTheme.error;
      case 'refunded': return AppTheme.info;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success': return Icons.check_circle_rounded;
      case 'pending': return Icons.pending_rounded;
      case 'failed': return Icons.cancel_rounded;
      case 'refunded': return Icons.replay_rounded;
      default: return Icons.help_outline;
    }
  }

  IconData _methodIcon(String? method) {
    switch ((method ?? '').toLowerCase()) {
      case 'card': return Icons.credit_card;
      case 'upi': return Icons.qr_code;
      case 'netbanking': return Icons.account_balance;
      case 'wallet': return Icons.account_balance_wallet;
      default: return Icons.payment;
    }
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso;
    }
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '₹0.00';
    final num val = amount is num ? amount : num.tryParse(amount.toString()) ?? 0;
    return '₹${val.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Payment History'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: _statusFilters.map((f) => Tab(text: f['label'] as String)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Summary Card
          _buildSummaryCard(),

          // Payment List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _statusFilters.map((_) => _buildPaymentList()).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_isLoadingSummary) {
      return Container(
        height: 80,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen, strokeWidth: 2)),
      );
    }
    if (_summary == null) return const SizedBox.shrink();

    final total = _summary!['total_transactions'] ?? 0;
    final spent = _summary!['total_amount_spent'] ?? 0.0;
    final lastDate = _summary!['last_payment_date'] as String?;
    final activeCost = _summary!['active_subscription_cost'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryGreen, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryStat(
              'Total\nTransactions',
              '$total',
              Icons.receipt_outlined,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryStat(
              'Total\nSpent',
              _formatAmount(spent),
              Icons.currency_rupee,
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.3)),
          Expanded(
            child: _buildSummaryStat(
              'Last\nPayment',
              lastDate != null
                  ? DateFormat('MMM dd').format(DateTime.parse(lastDate).toLocal())
                  : '—',
              Icons.calendar_today_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.8)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPaymentList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
    }
    if (_payments.isEmpty) return _buildEmptyState();

    return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        itemCount: _payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _buildPaymentCard(_payments[index]),
      );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final id = payment['id'] as String;
    final status = (payment['status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);
    final statusIcon = _statusIcon(status);
    final method = payment['payment_method'] as String?;
    final isSuccess = status == 'success';
    final isDownloading = _downloadingPaymentId == id;

    final dateStr = _formatDateTime(payment['paid_at'] as String? ?? payment['created_at'] as String?);
    final amount = payment['total_amount'] ?? payment['amount'];
    final gst = payment['gst_amount'] ?? 0.0;
    final shortId = id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

    return InkWell(
      onTap: () => _showPaymentDetail(payment),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status Icon
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, size: 22, color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment['subscription_name'] ?? 'Subscription Payment',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TXN: $shortId',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                // Amount
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatAmount(amount),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? AppTheme.textPrimary : statusColor,
                      ),
                    ),
                    if ((gst as num) > 0)
                      Text(
                        'incl. GST ${_formatAmount(gst)}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(_methodIcon(method), size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  (method ?? 'Razorpay').toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 13, color: AppTheme.textLight),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                if (isSuccess) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: isDownloading
                        ? const Padding(
                            padding: EdgeInsets.all(4),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.download_for_offline_outlined, size: 22, color: AppTheme.primaryGreen),
                            onPressed: () => _downloadInvoice(id),
                            tooltip: 'Download Invoice',
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentDetail(Map<String, dynamic> payment) {
    final id = payment['id'] as String;
    final status = (payment['status'] ?? 'pending').toString();
    final statusColor = _statusColor(status);
    final isSuccess = status == 'success';
    final isDownloading = _downloadingPaymentId == id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Row(
              children: [
                const Text('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Detail Rows
            _detailRow('Transaction ID', id, mono: true),
            _detailRow('Item / Plan', payment['subscription_name'] ?? '—'),
            _detailRow('Payment Method', (payment['payment_method'] ?? 'Razorpay').toString().toUpperCase()),
            const Divider(height: 24),
            _detailRow('Base Amount', _formatAmount(payment['amount'])),
            if ((payment['gst_amount'] as num? ?? 0) > 0)
              _detailRow('GST', _formatAmount(payment['gst_amount'])),
            if ((payment['delivery_charge'] as num? ?? 0) > 0)
              _detailRow('Delivery Charge', _formatAmount(payment['delivery_charge'])),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Text('Total Paid', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    _formatAmount(payment['total_amount'] ?? payment['amount']),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
            ),
            const Divider(height: 8),
            _detailRow(
              'Date & Time',
              _formatDateTime(payment['paid_at'] as String? ?? payment['created_at'] as String?),
            ),
            if (payment['gateway_payment_id'] != null)
              _detailRow('Gateway ID', payment['gateway_payment_id'], mono: true),
            const SizedBox(height: 20),
            if (isSuccess)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isDownloading ? null : () => _downloadInvoice(id),
                  icon: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(isDownloading ? 'Downloading...' : 'Download Invoice PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontFamily: mono ? 'monospace' : null,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppTheme.primaryGreen.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            const Text('No Payments Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              _currentStatus != null
                  ? 'No ${_currentStatus!} transactions found'
                  : 'Your transaction history will appear here',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
