import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _smsNotifications = true;
  bool _emailNotifications = false;

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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
          const SizedBox(height: 16),
          _buildSwitchTile(
            'Push Notifications',
            'Receive alerts for deliveries and offers',
            _pushNotifications,
            (v) => setState(() => _pushNotifications = v),
          ),
          const Divider(),
          _buildSwitchTile(
            'SMS Notifications',
            'Receive OTPs and critical alerts via SMS',
            _smsNotifications,
            (v) => setState(() => _smsNotifications = v),
          ),
          const Divider(),
          _buildSwitchTile(
            'Email Notifications',
            'Receive monthly summaries and invoices',
            _emailNotifications,
            (v) => setState(() => _emailNotifications = v),
          ),
          
          const SizedBox(height: 32),
          const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')));
            },
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_outline, color: AppTheme.error),
            title: const Text('Delete Account', style: TextStyle(color: AppTheme.error)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Account', style: TextStyle(color: AppTheme.error)),
                  content: const Text('Are you sure you want to permanently delete your account? This action cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact support to delete account')));
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
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
