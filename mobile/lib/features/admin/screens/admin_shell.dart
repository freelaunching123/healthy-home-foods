import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AdminShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AdminShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
          return;
        }
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App?'),
            content: const Text('Are you sure you want to exit the application?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes', style: TextStyle(color: AppTheme.error)),
              ),
            ],
          ),
        );
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            // Navigation Rail for tablets/desktop, or bottom nav for mobile
            if (MediaQuery.of(context).size.width > 600)
              NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(index),
                labelType: NavigationRailLabelType.all,
                selectedIconTheme: const IconThemeData(color: AppTheme.primaryGreen),
                selectedLabelTextStyle: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                destinations: const [
                  NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Dashboard')),
                  NavigationRailDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: Text('Products')),
                  NavigationRailDestination(icon: Icon(Icons.local_grocery_store_outlined), selectedIcon: Icon(Icons.local_grocery_store), label: Text('Groceries')),
                  NavigationRailDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: Text('Deliveries')),
                  NavigationRailDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: Text('Reports')),
                ],
              ),
            if (MediaQuery.of(context).size.width > 600) const VerticalDivider(thickness: 1, width: 1),
            
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: MediaQuery.of(context).size.width <= 600
            ? NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => navigationShell.goBranch(index),
                destinations: const [
                  NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryGreen), label: 'Dashboard'),
                  NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primaryGreen), label: 'Products'),
                  NavigationDestination(icon: Icon(Icons.local_grocery_store_outlined), selectedIcon: Icon(Icons.local_grocery_store, color: AppTheme.primaryGreen), label: 'Groceries'),
                  NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping, color: AppTheme.primaryGreen), label: 'Deliveries'),
                  NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primaryGreen), label: 'Reports'),
                ],
              )
            : null,
      ),
    );
  }
}
