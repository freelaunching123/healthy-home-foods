import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/password_rules.dart';
import '../../auth/widgets/password_validation_rules_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _api = ApiClient();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _deliveryNotifications = true;
  bool _paymentNotifications = true;
  bool _promotionalNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.userProfile);
      final data = res.data;
      setState(() {
        _deliveryNotifications = data['delivery_notifications_enabled'] ?? true;
        _paymentNotifications = data['payment_notifications_enabled'] ?? true;
        _promotionalNotifications = data['promotional_notifications_enabled'] ?? true;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotification(String key, bool val, ValueChanged<bool> updateState) async {
    final originalVal = val;
    // Optimistic UI update
    updateState(val);

    try {
      await _api.put(ApiConstants.userProfile, data: {key: val});
    } catch (e) {
      // Revert if API failed
      updateState(!originalVal);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update preference'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final bool isNewPasswordValid = PasswordRules.isValid(newPasswordController.text);
            final bool passwordsMatch = newPasswordController.text.isNotEmpty && newPasswordController.text == confirmPasswordController.text;
            final bool isChangeEnabled = isNewPasswordValid && passwordsMatch && !isSubmitting;

            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Old Password'),
                        validator: (v) => v == null || v.isEmpty ? 'Old password required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: true,
                        onChanged: (val) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'New Password'),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'New password required';
                          if (!PasswordRules.isValid(v)) return 'Password does not meet rules';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      PasswordValidationRulesWidget(password: newPasswordController.text),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        onChanged: (val) => setDialogState(() {}),
                        decoration: const InputDecoration(labelText: 'Confirm New Password'),
                        validator: (v) {
                          if (v != newPasswordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isChangeEnabled
                      ? () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSubmitting = true);
                          try {
                            await _api.post(ApiConstants.changePassword, data: {
                              'old_password': oldPasswordController.text,
                              'new_password': newPasswordController.text,
                            });
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password changed successfully'), backgroundColor: AppTheme.success),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Failed to change password. Double check old password.'), backgroundColor: AppTheme.error),
                              );
                            }
                          } finally {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logoutFromAllDevices() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout from All Devices'),
        content: const Text('Are you sure you want to log out from all of your devices? You will need to log in again on this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Logout All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _api.post(ApiConstants.logoutAll);
      await _authService.logout(); // Clears storage locally
      if (mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to logout from all devices'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                const SizedBox(height: 16),
                _buildSwitchTile(
                  'Delivery Notifications',
                  'Receive alerts for order dispatch, arrival, and delivery schedules',
                  _deliveryNotifications,
                  (v) => _toggleNotification('delivery_notifications_enabled', v, (newVal) => setState(() => _deliveryNotifications = newVal)),
                ),
                const Divider(),
                _buildSwitchTile(
                  'Payment Notifications',
                  'Receive reminders for billing cycles, invoices, and transactions',
                  _paymentNotifications,
                  (v) => _toggleNotification('payment_notifications_enabled', v, (newVal) => setState(() => _paymentNotifications = newVal)),
                ),
                const Divider(),
                _buildSwitchTile(
                  'Promotional Notifications',
                  'Receive messages about discounts, deals, and new menu additions',
                  _promotionalNotifications,
                  (v) => _toggleNotification('promotional_notifications_enabled', v, (newVal) => setState(() => _promotionalNotifications = newVal)),
                ),
                
                const SizedBox(height: 32),
                const Text('Account & Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.devices_outlined, color: AppTheme.error),
                  title: const Text('Logout from All Devices', style: TextStyle(color: AppTheme.error)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.error),
                  onTap: _logoutFromAllDevices,
                ),
                
                const SizedBox(height: 32),
                const Text('Support & Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Help & Support coming soon')));
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About Us'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('About Us coming soon')));
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primaryGreen,
    );
  }
}
