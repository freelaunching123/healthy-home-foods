import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

// Customer screens
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/customer/screens/customer_shell.dart';
import '../../features/customer/screens/home_screen.dart';
import '../../features/customer/screens/product_detail_screen.dart';
import '../../features/customer/screens/checkout_screen.dart';
import '../../features/customer/screens/subscriptions_screen.dart';
import '../../features/customer/screens/delivery_calendar_screen.dart';
import '../../features/customer/screens/tracking_screen.dart';
import '../../features/customer/screens/payment_history_screen.dart';
import '../../features/customer/screens/profile_screen.dart';
import '../../features/customer/screens/notifications_screen.dart';
import '../../features/customer/screens/settings_screen.dart';
import '../../features/customer/screens/edit_profile_screen.dart';
import '../../features/customer/screens/my_subscription_detail_screen.dart';
import '../../features/customer/screens/delivery_history_screen.dart';
import '../../features/customer/screens/address_management_screen.dart';
import '../../features/customer/screens/wishlist_screen.dart';
import '../../features/customer/screens/reviews_screen.dart';
import '../../features/customer/screens/about_us_screen.dart';
// Fruit screens (Customer)
import '../../features/customer/screens/grocery_detail_screen.dart';
import '../../features/customer/screens/grocery_cart_screen.dart';
import '../../features/customer/screens/grocery_checkout_screen.dart';
import '../../features/customer/screens/grocery_order_history_screen.dart';
import '../../features/customer/screens/grocery_order_detail_screen.dart';
import '../../features/customer/screens/package_cart_screen.dart';
import '../../features/customer/screens/package_checkout_screen.dart';

// Admin screens
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/product_management_screen.dart';
import '../../features/admin/screens/category_management_screen.dart';
import '../../features/admin/screens/product_analytics_screen.dart';
import '../../features/admin/screens/add_product_screen.dart';
import '../../features/admin/screens/customer_management_screen.dart';
import '../../features/admin/screens/subscription_management_screen.dart';
import '../../features/admin/screens/delivery_management_screen.dart';
import '../../features/admin/screens/delivery_partner_management_screen.dart';
import '../../features/admin/screens/create_delivery_partner_screen.dart';
import '../../features/admin/screens/delivery_partner_profile_screen.dart';
import '../../features/admin/screens/reports_screen.dart';
import '../../features/admin/screens/admin_settings_screen.dart';
import '../../features/admin/screens/admin_change_password_screen.dart';
import '../../features/admin/screens/delivery_settings_screen.dart';
import '../../features/admin/screens/package_orders_screen.dart';
// Fruit screens (Admin)
import '../../features/admin/screens/grocery_management_screen.dart';
import '../../features/admin/screens/add_edit_grocery_screen.dart';
import '../../features/admin/screens/grocery_orders_screen.dart';

// Delivery boy screens
import '../../features/delivery/screens/delivery_shell.dart';
import '../../features/delivery/screens/delivery_dashboard_screen.dart';
import '../../features/delivery/screens/order_detail_screen.dart';
import '../../features/delivery/screens/route_screen.dart';
import '../../features/delivery/screens/delivery_history_screen.dart';
import '../../features/delivery/screens/delivery_profile_screen.dart';
import '../../features/delivery/screens/active_deliveries_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  redirect: (context, state) async {
    debugPrint('GoRouter redirect matching: ${state.matchedLocation}');
    final authService = AuthService();
    debugPrint('Calling isLoggedIn...');
    final isLoggedIn = await authService.isLoggedIn();
    debugPrint('isLoggedIn returned: $isLoggedIn');
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot-password' ||
        state.matchedLocation == '/splash';

    if (!isLoggedIn && !isAuthRoute) {
      debugPrint('Redirecting to /login');
      return '/login';
    }

    if (isLoggedIn && isAuthRoute && state.matchedLocation != '/splash') {
      final role = await authService.getUserRole();
      if (role == 'super_admin' || role == 'admin') {
        return '/admin';
      } else if (role == 'delivery_partner') {
        return '/delivery';
      } else {
        return '/home';
      }
    }

    debugPrint('No redirection needed');
    return null;
  },
  routes: [
    // Auth routes
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

    // Customer shell with bottom nav (5 tabs: Home, Plans, Payments, Profile)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => CustomerShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/subscriptions', builder: (_, _) => const SubscriptionsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/payments', builder: (_, _) => const PaymentHistoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        ]),
      ],
    ),

    // Customer detail routes
    GoRoute(
      path: '/product/:id',
      builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/checkout',
      builder: (_, state) => CheckoutScreen(
        productId: state.uri.queryParameters['productId'] ?? '',
        planType: state.uri.queryParameters['plan'] ?? 'weekly',
      ),
    ),
    GoRoute(
      path: '/delivery-calendar/:subId',
      builder: (_, state) => DeliveryCalendarScreen(subscriptionId: state.pathParameters['subId']!),
    ),
    GoRoute(
      path: '/tracking/:deliveryId',
      builder: (_, state) => TrackingScreen(deliveryId: state.pathParameters['deliveryId']!),
    ),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/about-us', builder: (_, _) => const AboutUsScreen()),
    GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
    GoRoute(path: '/profile/subscription', builder: (_, _) => const MySubscriptionDetailScreen()),
    GoRoute(
      path: '/profile/subscription/:id',
      builder: (_, state) => MySubscriptionDetailScreen(subscriptionId: state.pathParameters['id']),
    ),
    GoRoute(path: '/profile/delivery-history', builder: (_, _) => const CustomerDeliveryHistoryScreen()),
    GoRoute(path: '/profile/addresses', builder: (_, _) => const AddressManagementScreen()),
    GoRoute(path: '/wishlist', builder: (_, _) => const WishlistScreen()),
    GoRoute(
      path: '/reviews/:type/:id',
      builder: (_, state) => ReviewsScreen(
        type: state.pathParameters['type']!,
        id: state.pathParameters['id']!,
      ),
    ),

    // ── Fruit customer routes ──────────────────────────────────────────────────
    GoRoute(path: '/fruits', redirect: (_, _) => '/home'),
    GoRoute(path: '/fruits/cart', builder: (_, _) => const FruitCartScreen()),
    GoRoute(path: '/fruits/checkout', builder: (_, _) => const FruitCheckoutScreen()),
    GoRoute(path: '/fruits/orders', builder: (_, _) => const FruitOrderHistoryScreen()),
    GoRoute(
      path: '/fruits/orders/:id',
      builder: (_, state) => FruitOrderDetailScreen(orderId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/fruits/:id',
      builder: (_, state) => FruitDetailScreen(fruitId: state.pathParameters['id']!),
    ),
    
    // ── Package customer routes ────────────────────────────────────────────────
    GoRoute(path: '/packages', redirect: (_, _) => '/home'),
    GoRoute(path: '/packages/cart', builder: (_, _) => const PackageCartScreen()),
    GoRoute(path: '/packages/checkout', builder: (_, _) => const PackageCheckoutScreen()),

    // Admin shell (5 tabs: Dashboard, Products, Fruits, Deliveries, Reports)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AdminShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin', builder: (_, _) => const AdminDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/products', builder: (_, _) => const ProductManagementScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/fruits', builder: (_, _) => const FruitManagementScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/deliveries', builder: (_, _) => const DeliveryManagementScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/reports', builder: (_, _) => const ReportsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/admin/products/add', builder: (_, _) => const AddProductScreen()),
    GoRoute(
      path: '/admin/products/edit/:id',
      builder: (_, state) => AddProductScreen(productId: state.pathParameters['id']),
    ),
    GoRoute(path: '/admin/categories', builder: (_, _) => const CategoryManagementScreen(categoryType: 'package')),
    GoRoute(path: '/admin/grocery-categories', builder: (_, _) => const CategoryManagementScreen(categoryType: 'grocery')),
    GoRoute(path: '/admin/products/analytics', builder: (_, _) => const ProductAnalyticsScreen()),
    GoRoute(path: '/admin/customers', builder: (_, _) => const CustomerManagementScreen()),
    GoRoute(path: '/admin/subscriptions', builder: (_, _) => const SubscriptionManagementScreen()),
    GoRoute(path: '/admin/delivery-partners', builder: (_, _) => const DeliveryPartnerManagementScreen()),
    GoRoute(path: '/admin/delivery-partners/create', builder: (_, _) => const CreateDeliveryPartnerScreen()),
    GoRoute(
      path: '/admin/delivery-partners/:id',
      builder: (_, state) => DeliveryPartnerProfileScreen(
        partnerId: state.pathParameters['id']!,
        initialData: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(path: '/admin/settings', builder: (_, _) => const AdminSettingsScreen()),
    GoRoute(path: '/admin/change-password', builder: (_, _) => const AdminChangePasswordScreen()),
    GoRoute(path: '/admin/delivery-settings', builder: (_, _) => const DeliverySettingsScreen()),

    // ── Fruit admin routes ─────────────────────────────────────────────────────
    GoRoute(path: '/admin/fruits/add', builder: (_, _) => const AddEditGroceryScreen()),
    GoRoute(
      path: '/admin/fruits/edit/:id',
      builder: (_, state) => AddEditGroceryScreen(fruitId: state.pathParameters['id']),
    ),
    GoRoute(path: '/admin/fruits/orders', builder: (_, _) => const FruitOrdersScreen()),
    
    // ── Package admin routes ───────────────────────────────────────────────────
    GoRoute(path: '/admin/packages/orders', builder: (_, _) => const PackageOrdersScreen()),

    // Delivery boy shell
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => DeliveryShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery', builder: (_, _) => const DeliveryDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/route', builder: (_, _) => const RouteScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/history', builder: (_, _) => const DeliveryHistoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/profile', builder: (_, _) => const DeliveryProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/delivery/active',
      builder: (_, _) => const ActiveDeliveriesScreen(),
    ),
    GoRoute(
      path: '/delivery/order/:id',
      builder: (_, state) => OrderDetailScreen(assignmentId: state.pathParameters['id']!),
    ),
  ],
);
