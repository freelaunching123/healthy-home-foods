import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';

class DeliverySettingsScreen extends StatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  final _charge0to5Controller = TextEditingController();
  final _charge5to10Controller = TextEditingController();
  final _charge10to15Controller = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _charge0to5Controller.dispose();
    _charge5to10Controller.dispose();
    _charge10to15Controller.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.adminSettings);
      final data = res.data;
      setState(() {
        _charge0to5Controller.text = data['delivery_charge_0_to_5_km']?.toString() ?? '0.00';
        _charge5to10Controller.text = data['delivery_charge_5_to_10_km']?.toString() ?? '';
        _charge10to15Controller.text = data['delivery_charge_10_to_15_km']?.toString() ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load settings'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showConfirmationDialog() async {
    if (!_formKey.currentState!.validate()) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to update the delivery charge settings? These changes will apply to all future orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _saveSettings();
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final payload = {
        'free_delivery_radius_km': 5.0, // Fixed as per requirements
        'delivery_charge_0_to_5_km': double.tryParse(_charge0to5Controller.text),
        'delivery_charge_5_to_10_km': double.tryParse(_charge5to10Controller.text),
        'delivery_charge_10_to_15_km': double.tryParse(_charge10to15Controller.text),
        'max_delivery_distance_km': 15.0, // Fixed as per requirements
      };

      await _api.put(ApiConstants.adminSettings, data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery charge settings updated successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update delivery settings'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validatePositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final numValue = double.tryParse(value);
    if (numValue == null) {
      return 'Must be a valid number';
    }
    if (numValue < 0) {
      return 'Cannot be negative';
    }
    return null;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Delivery Charge Settings', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [


                    // Delivery Charges Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery Charges',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            // 0 to 5 km
                            Text('0 km – 5 km (from shop)', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _charge0to5Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Delivery Charge (₹)',
                                prefixIcon: Icon(Icons.currency_rupee_outlined),
                                hintText: 'e.g. 0',
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            const SizedBox(height: 24),
                            
                            // 5 to 10
                            Text('Above 5 km – 10 km', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _charge5to10Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Delivery Charge (₹)',
                                prefixIcon: Icon(Icons.currency_rupee_outlined),
                                hintText: 'e.g. 15',
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            const SizedBox(height: 24),
                            
                            // 10 to 15
                            Text('Above 10 km – 15 km', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _charge10to15Controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Delivery Charge (₹)',
                                prefixIcon: Icon(Icons.currency_rupee_outlined),
                                hintText: 'e.g. 20',
                              ),
                              validator: _validatePositiveNumber,
                            ),
                            const SizedBox(height: 24),

                            // Max distance
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Above 15 km', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 15)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('Delivery Not Available', style: GoogleFonts.inter(color: AppTheme.error, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _showConfirmationDialog,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Save Changes',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
