import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class PackageCheckoutScreen extends StatefulWidget {
  const PackageCheckoutScreen({super.key});

  @override
  State<PackageCheckoutScreen> createState() => _PackageCheckoutScreenState();
}

class _PackageCheckoutScreenState extends State<PackageCheckoutScreen> {
  final _api = ApiClient();
  late Razorpay _razorpay;

  List<Map<String, dynamic>> _cartItems = [];
  double _total = 0;
  List<Map<String, dynamic>> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  double _deliveryCharge = 0;
  double? _deliveryDistance;
  bool _calculatingDelivery = false;
  String? _deliveryError;

  bool _loadingCart = true;
  bool _loadingAddresses = true;
  bool _placingOrder = false;
  bool _paymentProcessing = false;
  String? _pendingOrderId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupRazorpay();
    _loadCart();
    _loadAddresses();
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

  Future<void> _loadCart() async {
    try {
      final res = await _api.get(ApiConstants.packageCart);
      setState(() {
        _cartItems = List<Map<String, dynamic>>.from(res.data['items'] as List);
        _total = (res.data['total_amount'] as num).toDouble();
        _loadingCart = false;
      });
    } catch (_) {
      setState(() => _loadingCart = false);
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final res = await _api.get(ApiConstants.userAddresses);
      final list = List<Map<String, dynamic>>.from(res.data as List);
      setState(() {
        _addresses = list;
        _selectedAddress = list.firstWhere(
          (a) => a['is_default'] == true,
          orElse: () => list.isNotEmpty ? list.first : {},
        );
        if (_selectedAddress?.isEmpty == true) _selectedAddress = null;
        _loadingAddresses = false;
      });
      if (_selectedAddress != null) {
        _calculateDeliveryCharge();
      }
    } catch (_) {
      setState(() => _loadingAddresses = false);
    }
  }

  Future<void> _calculateDeliveryCharge() async {
    if (_selectedAddress == null) return;
    setState(() {
      _calculatingDelivery = true;
      _deliveryError = null;
    });
    try {
      final res = await _api.post(
        ApiConstants.deliveryCalculateCharge,
        data: {
          'address_id': _selectedAddress!['id'],
          'order_type': 'package',
        },
      );
      setState(() {
        _deliveryCharge = (res.data['delivery_charge'] as num).toDouble();
        _deliveryDistance = (res.data['distance_km'] as num).toDouble();
        _calculatingDelivery = false;
      });
    } catch (e) {
      setState(() {
        _calculatingDelivery = false;
        _deliveryError = 'Delivery unavailable for this location';
        _deliveryCharge = 0;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your cart is empty'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() { _placingOrder = true; _error = null; });
    try {
      // Create the order which also creates Razorpay order
      final orderRes = await _api.post(ApiConstants.packageOrdersCheckout, data: {
        'address_id': _selectedAddress!['id'],
      });
      final orderData = orderRes.data;
      
      _pendingOrderId = orderData['gateway_order_id']; // For reference if needed
      
      final options = {
        'key': orderData['razorpay_key_id'],
        'amount': (orderData['total_amount'] * 100).toInt(), // Razorpay expects paise
        'currency': 'INR',
        'name': 'Healthy Home Foods',
        'description': 'Package Subscription Order ${orderData['order_number']}',
        'order_id': orderData['gateway_order_id'],
        'prefill': {
          'contact': '',
          'email': '',
        },
        'theme': {'color': '#2E7D32'},
      };

      setState(() { _placingOrder = false; _paymentProcessing = true; });
      _razorpay.open(options);
    } catch (e) {
      setState(() { _placingOrder = false; _error = 'Order placement failed. Please try again.'; });
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _paymentProcessing = false);
    if (_pendingOrderId == null) return;

    try {
      await _api.post(
        ApiConstants.packageOrdersVerify,
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
    setState(() => _paymentProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    setState(() => _paymentProcessing = false);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Subscription Active!', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 22)),
              const SizedBox(height: 8),
              Text(
                'Your healthy meals subscription is confirmed. 🥗',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  ctx.pop();
                  context.go('/subscriptions');
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                child: const Text('View My Subscriptions'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  ctx.pop();
                  context.go('/home');
                },
                child: Text('Continue Shopping', style: GoogleFonts.inter(color: AppTheme.primaryGreen)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = _loadingCart || _loadingAddresses;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Checkout', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Delivery Address
                  _SectionHeader(icon: Icons.location_on_rounded, title: 'Delivery Address'),
                  const SizedBox(height: 10),
                  _addresses.isEmpty
                      ? _AddressEmpty(onAdd: () => context.push('/profile/addresses'))
                      : _AddressPicker(
                          addresses: _addresses,
                          selected: _selectedAddress,
                          onSelect: (a) {
                            setState(() => _selectedAddress = a);
                            _calculateDeliveryCharge();
                          },
                        ),

                  const SizedBox(height: 24),

                  // Order Summary
                  _SectionHeader(icon: Icons.receipt_long_rounded, title: 'Order Summary'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        ..._cartItems.asMap().entries.map((entry) {
                          final i = entry.key;
                          final item = entry.value;
                          final qty = (item['quantity'] as num).toInt();
                          final price = (item['unit_price'] as num).toDouble();
                          final subtotal = (item['subtotal'] as num).toDouble();
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['product_name'] as String,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '$qty × ₹${price.toStringAsFixed(0)}',
                                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      '₹${subtotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.primaryGreen, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              if (i < _cartItems.length - 1)
                                Divider(height: 1, color: Colors.grey.shade100),
                            ],
                          );
                        }),
                        Divider(color: Colors.grey.shade200, height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Text('Items Total', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                              const Spacer(),
                              Text(
                                '₹${_total.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Text('Delivery Charge', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                              if (_calculatingDelivery)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8.0),
                                  child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                ),
                              if (_deliveryDistance != null)
                                Text(' (${_deliveryDistance!.toStringAsFixed(1)} km)', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                              const Spacer(),
                              Text(
                                _calculatingDelivery ? '...' : '₹${_deliveryCharge.toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        if (_deliveryError != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(
                              _deliveryError!,
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w500),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade200, height: 1),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Text('Total Amount', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                              const Spacer(),
                              Text(
                                '₹${(_total + _deliveryCharge).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.primaryGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment methods info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, size: 18, color: AppTheme.primaryGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Secure payment via Razorpay · UPI · Cards · Net Banking',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Confirm button
                  ElevatedButton(
                    onPressed: (_placingOrder || _paymentProcessing || _cartItems.isEmpty || _calculatingDelivery || _deliveryError != null) ? null : _placeOrder,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _placingOrder || _paymentProcessing
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.payment_rounded, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Confirm & Pay ₹${(_total + _deliveryCharge).toStringAsFixed(2)}',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                            ],
                          ),
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _AddressPicker extends StatelessWidget {
  final List<Map<String, dynamic>> addresses;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;

  const _AddressPicker({required this.addresses, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: addresses.map((addr) {
        final isSelected = selected != null && addr['id'] == selected!['id'];
        return GestureDetector(
          onTap: () => onSelect(addr),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (addr['label'] != null)
                        Text(addr['label'] as String,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(
                        '${addr['address_line1']}, ${addr['city']}, ${addr['pincode']}',
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (addr['is_default'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Default', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.primaryGreen)),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AddressEmpty extends StatelessWidget {
  final VoidCallback onAdd;
  const _AddressEmpty({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(child: Text('No delivery address saved.', style: GoogleFonts.inter(fontSize: 13))),
          TextButton(
            onPressed: onAdd,
            child: Text('Add', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
