import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/api_error_handler.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      final res = await _authService.loginWithPassword(
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      
      final String role = res['role'] ?? 'customer';
      if (role == 'super_admin' || role == 'admin') {
        context.go('/admin');
      } else if (role == 'delivery_partner') {
        context.go('/delivery');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = ApiErrorHandler.getMessage(e);
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

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = AppTheme.primaryGreen;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FBF8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Center(
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  const Center(
                    child: Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Sign in to your Healthy Home Foods account',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Phone field
                  const Text(
                    'Mobile Number',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
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
                  const Text(
                    'Password',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                  ),
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
                      return null;
                    },
                  ),
                  
                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 32),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? ", style: TextStyle(color: AppTheme.textSecondary)),
                      GestureDetector(
                        onTap: () => context.go('/register'),
                        child: const Text(
                          'Register',
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
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
