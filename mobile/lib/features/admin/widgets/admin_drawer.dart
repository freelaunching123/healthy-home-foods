import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authService = AuthService();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await authService.logout();
      appRouter.go('/login');
    }
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryGreen : AppTheme.textSecondary),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppTheme.primaryGreen : AppTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedTileColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine current route for highlighting
    final String currentRoute = GoRouterState.of(context).uri.toString();

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: AppTheme.scaffoldBg,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    child: const Icon(Icons.person, size: 36, color: AppTheme.primaryGreen),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Admin User',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Text(
                    'Administrator',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            
            // Drawer Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [

                  _buildDrawerItem(
                    context: context,
                    icon: Icons.receipt_long_outlined,
                    title: 'Package Orders',
                    isSelected: currentRoute == '/admin/packages/orders',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/packages/orders') context.push('/admin/packages/orders');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.shopping_bag_outlined,
                    title: 'Grocery Orders',
                    isSelected: currentRoute == '/admin/fruits/orders',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/fruits/orders') context.push('/admin/fruits/orders');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.card_membership_outlined,
                    title: 'Manage Subscriptions',
                    isSelected: currentRoute == '/admin/subscriptions',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/subscriptions') context.push('/admin/subscriptions');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.people_outline,
                    title: 'Manage Customers',
                    isSelected: currentRoute == '/admin/customers',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/customers') context.push('/admin/customers');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.local_shipping_outlined,
                    title: 'Manage Delivery Partners',
                    isSelected: currentRoute == '/admin/delivery-partners',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/delivery-partners') context.push('/admin/delivery-partners');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.category_outlined,
                    title: 'Package Categories',
                    isSelected: currentRoute == '/admin/categories',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/categories') context.push('/admin/categories');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.local_grocery_store_outlined,
                    title: 'Grocery Categories',
                    isSelected: currentRoute == '/admin/grocery-categories',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/grocery-categories') context.push('/admin/grocery-categories');
                    },
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    isSelected: currentRoute == '/admin/settings',
                    onTap: () {
                      context.pop();
                      if (currentRoute != '/admin/settings') context.push('/admin/settings');
                    },
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Logout Button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildDrawerItem(
                context: context,
                icon: Icons.logout,
                title: 'Logout',
                onTap: () {
                  context.pop();
                  _handleLogout(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
