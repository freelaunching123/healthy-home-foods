import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delivery Settings Navigation Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_shipping_outlined, color: AppTheme.primaryGreen),
                ),
                title: Text(
                  'Delivery Settings',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Configure delivery charges for different distance ranges',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/delivery-settings'),
              ),
            ),
            const SizedBox(height: 16),

            // Change Password Navigation Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                ),
                title: Text(
                  'Change Password',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  'Update your admin account password',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/change-password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
