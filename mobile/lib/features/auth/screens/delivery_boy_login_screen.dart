import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryBoyLoginScreen extends StatefulWidget {
  const DeliveryBoyLoginScreen({super.key});

  @override
  State<DeliveryBoyLoginScreen> createState() => _DeliveryBoyLoginScreenState();
}

class _DeliveryBoyLoginScreenState extends State<DeliveryBoyLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.loginWithPassword(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        role: 'delivery_boy',
      );

      if (!mounted) return;
      context.go('/delivery');
    } catch (e) {
      if (!mounted) return;
      final msg = _extractError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      try {
        final dioError = e as dynamic;
        return dioError.response?.data?['detail'] ?? 'Login failed';
      } catch (_) {}
    }
    return 'Login failed. Please try again.';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = Colors.blue.shade700;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          primary: accentColor,
          secondary: Colors.blue,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go('/role-selection'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: accentColor, width: 1.5),
                      ),
                      child: Text(
                        'Delivery Boy Login',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Logo
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'Delivery Portal',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Sign in to view your deliveries',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Phone field
                  const Text('Mobile Number', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    decoration: InputDecoration(
                      hintText: 'Enter 10-digit mobile number',
                      prefixIcon: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🇮🇳 +91', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            SizedBox(height: 24, child: VerticalDivider(thickness: 1)),
                          ],
                        ),
                      ),
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mobile number is required';
                      if (v.length != 10) return 'Enter valid 10-digit number';
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Invalid mobile number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password field
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Min 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Sign In'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
