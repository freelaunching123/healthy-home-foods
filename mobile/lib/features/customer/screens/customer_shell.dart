import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class CustomerShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const CustomerShell({super.key, required this.navigationShell});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _api = ApiClient();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    try {
      final res = await _api.get(ApiConstants.notificationsUnreadCount);
      if (mounted) {
        setState(() => _unreadCount = (res.data['count'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(CustomerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh badge when switching back to notifications tab
    if (widget.navigationShell.currentIndex == 3 &&
        oldWidget.navigationShell.currentIndex != 3) {
      Future.delayed(const Duration(seconds: 1), _fetchUnreadCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: widget.navigationShell.currentIndex == 0,
                  onTap: () => widget.navigationShell.goBranch(0),
                ),
                _NavItem(
                  icon: Icons.calendar_today_rounded,
                  label: 'Plans',
                  isSelected: widget.navigationShell.currentIndex == 1,
                  onTap: () => widget.navigationShell.goBranch(1),
                ),
                _NavItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'Payments',
                  isSelected: widget.navigationShell.currentIndex == 2,
                  onTap: () => widget.navigationShell.goBranch(2),
                ),
                _NavItemBadge(
                  icon: Icons.notifications_rounded,
                  label: 'Alerts',
                  badgeCount: _unreadCount,
                  isSelected: widget.navigationShell.currentIndex == 3,
                  onTap: () {
                    widget.navigationShell.goBranch(3);
                    // Clear badge after navigating to notifications
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) setState(() => _unreadCount = 0);
                    });
                  },
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: widget.navigationShell.currentIndex == 4,
                  onTap: () => widget.navigationShell.goBranch(4),
                ),
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

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

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
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemBadge({
    required this.icon,
    required this.label,
    required this.badgeCount,
    required this.isSelected,
    required this.onTap,
  });

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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 24, color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGreen : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
