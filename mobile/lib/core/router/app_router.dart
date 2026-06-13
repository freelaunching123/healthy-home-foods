import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';

// Customer screens
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/customer_login_screen.dart';
import '../../features/auth/screens/admin_login_screen.dart';
import '../../features/auth/screens/delivery_partner_login_screen.dart';
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

// Admin screens
import '../../features/admin/screens/admin_shell.dart';
import '../../features/admin/screens/admin_dashboard_screen.dart';
import '../../features/admin/screens/product_management_screen.dart';
import '../../features/admin/screens/add_product_screen.dart';
import '../../features/admin/screens/customer_management_screen.dart';
import '../../features/admin/screens/subscription_management_screen.dart';
import '../../features/admin/screens/delivery_management_screen.dart';
import '../../features/admin/screens/delivery_partner_management_screen.dart';
import '../../features/admin/screens/create_delivery_partner_screen.dart';
import '../../features/admin/screens/delivery_partner_profile_screen.dart';
import '../../features/admin/screens/reports_screen.dart';
import '../../features/admin/screens/admin_settings_screen.dart';

// Delivery boy screens
import '../../features/delivery/screens/delivery_shell.dart';
import '../../features/delivery/screens/delivery_dashboard_screen.dart';
import '../../features/delivery/screens/order_detail_screen.dart';
import '../../features/delivery/screens/route_screen.dart';
import '../../features/delivery/screens/delivery_history_screen.dart';
import '../../features/delivery/screens/delivery_profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  redirect: (context, state) async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    final isAuthRoute = state.matchedLocation == '/role-selection' ||
        state.matchedLocation == '/customer-login' ||
        state.matchedLocation == '/admin-login' ||
        state.matchedLocation == '/delivery-login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/splash';

    if (!isLoggedIn && !isAuthRoute) return '/role-selection';
    return null;
  },
  routes: [
    // Auth routes
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/role-selection', builder: (_, __) => const RoleSelectionScreen()),
    GoRoute(path: '/customer-login', builder: (_, __) => const CustomerLoginScreen()),
    GoRoute(path: '/admin-login', builder: (_, __) => const AdminLoginScreen()),
    GoRoute(path: '/delivery-login', builder: (_, __) => const DeliveryPartnerLoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

    // Customer shell with bottom nav
    StatefulShellRoute.indexedStack(
      builder: (_, __, navigationShell) => CustomerShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/subscriptions', builder: (_, __) => const SubscriptionsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/payments', builder: (_, __) => const PaymentHistoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
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
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),

    // Admin shell
    StatefulShellRoute.indexedStack(
      builder: (_, __, navigationShell) => AdminShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/products', builder: (_, __) => const ProductManagementScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/deliveries', builder: (_, __) => const DeliveryManagementScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/admin/reports', builder: (_, __) => const ReportsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/admin/products/add', builder: (_, __) => const AddProductScreen()),
    GoRoute(
      path: '/admin/products/edit/:id',
      builder: (_, state) => AddProductScreen(productId: state.pathParameters['id']),
    ),
    GoRoute(path: '/admin/customers', builder: (_, __) => const CustomerManagementScreen()),
    GoRoute(path: '/admin/subscriptions', builder: (_, __) => const SubscriptionManagementScreen()),
    GoRoute(path: '/admin/delivery-partners', builder: (_, __) => const DeliveryPartnerManagementScreen()),
    GoRoute(path: '/admin/delivery-partners/create', builder: (_, __) => const CreateDeliveryPartnerScreen()),
    GoRoute(
      path: '/admin/delivery-partners/:id',
      builder: (_, state) => DeliveryPartnerProfileScreen(
        partnerId: state.pathParameters['id']!,
        initialData: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(path: '/admin/settings', builder: (_, __) => const AdminSettingsScreen()),

    // Delivery boy shell
    StatefulShellRoute.indexedStack(
      builder: (_, __, navigationShell) => DeliveryShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery', builder: (_, __) => const DeliveryDashboardScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/route', builder: (_, __) => const RouteScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/history', builder: (_, __) => const DeliveryHistoryScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/delivery/profile', builder: (_, __) => const DeliveryProfileScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/delivery/order/:id',
      builder: (_, state) => OrderDetailScreen(assignmentId: state.pathParameters['id']!),
    ),
  ],
);
