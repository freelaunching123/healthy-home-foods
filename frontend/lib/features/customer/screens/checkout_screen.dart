import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class CheckoutScreen extends StatefulWidget {
  final String productId;
  final String planType;
  const CheckoutScreen({super.key, required this.productId, required this.planType});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiClient();
  late Razorpay _razorpay;
  Map<String, dynamic>? _product;
  List<dynamic> _addresses = [];
  List<dynamic> _plans = [];
  String? _selectedAddressId;
  String? _selectedPlanId;
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = true;
  bool _isProcessing = false;
  double _deliveryCharge = 0;
  double _distance = 0;

  @override
  void initState() {
    super.initState();
    _setupRazorpay();
    _loadData();
  }

  void _setupRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final prodRes = await _api.get('${ApiConstants.products}/${widget.productId}');
      final addrRes = await _api.get(ApiConstants.userAddresses);
      final planRes = await _api.get(ApiConstants.subscriptionPlans);

      setState(() {
        _product = prodRes.data;
        _addresses = addrRes.data is List ? addrRes.data : [];
        _plans = planRes.data is List ? planRes.data : [];
        // Auto-select plan based on type
        for (var plan in _plans) {
          if ((plan['name'] ?? '').toString().toLowerCase().contains(widget.planType)) {
            _selectedPlanId = plan['id'];
            break;
          }
        }
        if (_addresses.isNotEmpty) _selectedAddressId = _addresses[0]['id'];
        _isLoading = false;
      });
      if (_selectedAddressId != null) {
        _calculateDeliveryCharge();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Checkout load error: $e');
    }
  }

  Future<void> _calculateDeliveryCharge() async {
    if (_selectedAddressId == null) return;
    try {
      final res = await _api.post(
        ApiConstants.deliveryCalculateCharge,
        data: {
          'address_id': _selectedAddressId,
          'order_type': 'package',
        },
      );
      setState(() {
        _deliveryCharge = (res.data['delivery_charge'] as num).toDouble();
        _distance = (res.data['distance_km'] as num).toDouble();
      });
    } catch (e) {
      setState(() {
        _deliveryCharge = 0;
        _distance = 0;
      });
    }
  }

  int get _deliveries {
    if (_selectedPlanId != null) {
      for (var p in _plans) {
        if (p['id'] == _selectedPlanId) return p['total_deliveries'] ?? 6;
      }
    }
    return widget.planType == 'weekly' ? 6 : 26;
  }

  double get _selectedPrice {
    final double basePrice = double.tryParse(_product?['package_price']?.toString() ?? '0') ?? 0;
    final double? discountPrice = _product?['discount_price'] != null ? double.tryParse(_product!['discount_price'].toString()) : null;
    return discountPrice ?? basePrice;
  }
  double get _subtotal => _selectedPrice;
  double get _total => _subtotal + _deliveryCharge;

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (day) => day.weekday != DateTime.sunday,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppTheme.primaryGreen),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _createSubscription() async {
    if (_selectedPlanId == null || _selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan and address'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    if (_distance > 15.0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Service'),
          content: const Text('There is no service beyond 15km. Please select an address within the range.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final subRes = await _api.post(ApiConstants.subscriptions, data: {
        'product_id': widget.productId,
        'plan_id': _selectedPlanId,
        'address_id': _selectedAddressId,
        'preferred_delivery_time': null,
        'auto_renew': false,
        'notes': null,
      });

      final subId = subRes.data['id'];

      // Initiate payment
      try {
        final payRes = await _api.post(ApiConstants.paymentInitiate, data: {
          'subscription_id': subId,
        });

        final payData = payRes.data;
        final keyId = payData['key_id'] as String?;
        final gatewayOrderId = payData['order_id'] as String?;

        if (keyId != null && keyId.isNotEmpty && keyId != 'mock_key') {
          final options = {
            'key': keyId,
            'amount': payData['amount'] ?? ((_total * 100).toInt()),
            'name': 'Healthy Home Foods',
            'description': 'Subscription Payment',
            'order_id': gatewayOrderId,
            'retry': {'enabled': true, 'max_count': 1},
            'send_sms_hash': true,
            'external': {
              'wallets': ['paytm']
            }
          };
          _razorpay.open(options);
        } else {
          // Fallback for mock payment when key_id is mock_key
          if (mounted) {
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
                    SizedBox(width: 10),
                    Text('Payment Successful'),
                  ],
                ),
                content: const Text(
                  'Mock Payment Successful!\nYour transaction has been processed.',
                  style: TextStyle(fontSize: 15),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }

          await _api.post(ApiConstants.paymentVerify, data: {
            'razorpay_order_id': gatewayOrderId ?? 'mock_order',
            'razorpay_payment_id': 'mock_pay_${DateTime.now().millisecondsSinceEpoch}',
            'razorpay_signature': 'mock_signature',
          });
          if (mounted) {
            _showSuccessDialog();
          }
        }
      } catch (e) {
        debugPrint('Payment error: $e');
      }
    } catch (e) {
      debugPrint('Checkout error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.success),
            ),
            const SizedBox(height: 16),
            const Text('Subscription Activated!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Your healthy meals will start soon', textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { Navigator.pop(context); context.go('/subscriptions'); },
              child: const Text('View My Plans'),
            ),
          ],
        ),
      ),
    );
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = false);
    try {
      await _api.post(
        ApiConstants.paymentVerify,
        data: {
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        },
      );
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment verification failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? "Transaction cancelled"}'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet Selected: ${response.walletName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100)),
              child: Row(
                children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.eco_rounded, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_product?['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        Text('${_product?['plan_type']?.toString().toUpperCase() ?? 'PACKAGE'} Plan • ${_product?['package_days'] ?? 6} deliveries',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  Text('₹${_selectedPrice.toStringAsFixed(0)}', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Start date
            const Text('Start Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectStartDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppTheme.primaryGreen, size: 20),
                    const SizedBox(width: 12),
                    Text('${_startDate.day}/${_startDate.month}/${_startDate.year}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Address
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (_addresses.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.edit_location_alt_rounded, size: 16, color: AppTheme.primaryGreen),
                    label: const Text('Manage', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 13)),
                    onPressed: () async {
                      await context.push('/profile/addresses');
                      _loadData();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_addresses.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, size: 36, color: AppTheme.textLight),
                    const SizedBox(height: 8),
                    const Text('No saved addresses', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Address'),
                      onPressed: () async {
                        await context.push('/profile/addresses');
                        _loadData();
                      },
                    ),
                  ],
                ),
              )
            else
              ..._addresses.map((addr) => RadioListTile(
                value: addr['id'],
                groupValue: _selectedAddressId,
                onChanged: (v) {
                  setState(() => _selectedAddressId = v);
                  _calculateDeliveryCharge();
                },
                title: Text(addr['label'] ?? addr['address_type'] ?? 'Address',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${addr['address_line1'] ?? ''}, ${addr['city'] ?? ''}',
                  style: const TextStyle(fontSize: 13)),
                activeColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              )),

            const SizedBox(height: 24),

            // Order summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Order Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  _Row('Package Price', '₹${_subtotal.toStringAsFixed(0)}'),
                  _Row('Delivery charge', _deliveryCharge > 0 ? '₹${_deliveryCharge.toStringAsFixed(0)}' : 'FREE'),
                  const Divider(),
                  _Row('Total', '₹${_total.toStringAsFixed(0)}', isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _createSubscription,
            child: _isProcessing
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text('Pay ₹${_total.toStringAsFixed(0)}'),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool isBold;
  const _Row(this.label, this.value, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? AppTheme.primaryGreen : AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
