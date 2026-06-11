import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class CustomerShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const CustomerShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(icon: Icons.home_rounded, label: 'Home', isSelected: navigationShell.currentIndex == 0,
                    onTap: () => navigationShell.goBranch(0)),
                _NavItem(icon: Icons.calendar_today_rounded, label: 'Plans', isSelected: navigationShell.currentIndex == 1,
                    onTap: () => navigationShell.goBranch(1)),
                _NavItem(icon: Icons.receipt_long_rounded, label: 'Payments', isSelected: navigationShell.currentIndex == 2,
                    onTap: () => navigationShell.goBranch(2)),
                _NavItem(icon: Icons.notifications_rounded, label: 'Alerts', isSelected: navigationShell.currentIndex == 3,
                    onTap: () => navigationShell.goBranch(3)),
                _NavItem(icon: Icons.person_rounded, label: 'Profile', isSelected: navigationShell.currentIndex == 4,
                    onTap: () => navigationShell.goBranch(4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight,
            )),
          ],
        ),
      ),
    );
  }
}
