import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  late TabController _tabController;
  Timer? _refreshTimer;

  static const _categories = [
    {'label': 'All', 'key': null, 'icon': Icons.notifications_outlined},
    {'label': 'Promotions', 'key': 'promo', 'icon': Icons.local_offer_outlined},
    {'label': 'Subscription', 'key': 'subscription', 'icon': Icons.restaurant_menu_outlined},
    {'label': 'Updates', 'key': 'system', 'icon': Icons.info_outline},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadNotifications();
    });
    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadNotifications(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String? get _currentCategory {
    final idx = _tabController.index;
    return _categories[idx]['key'] as String?;
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
    try {
      final category = _currentCategory;
      final res = await _api.get(
        ApiConstants.notifications,
        queryParameters: category != null ? {'category': category} : null,
      );
      if (mounted) {
        setState(() {
          _notifications = res.data is List ? res.data : [];
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (!silent && mounted) {
        setState(() => _hasError = true);
      }
    } finally {
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    if (_notifications[index]['is_read'] == true) return;
    try {
      await _api.patch('${ApiConstants.notifications}/$id/read');
      setState(() => _notifications[index]['is_read'] = true);
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.patch(ApiConstants.notificationsReadAll);
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking all read: $e');
    }
  }

  Future<void> _clearAll() async {
    final originalList = List.from(_notifications);
    setState(() => _notifications = []);
    try {
      await _api.delete('${ApiConstants.notifications}/clear-all');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications cleared'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
      setState(() => _notifications = originalList);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear notifications'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id, int index) async {
    final removed = _notifications[index];
    setState(() => _notifications.removeAt(index));
    try {
      await _api.delete('${ApiConstants.notifications}/$id');
    } catch (e) {
      // Restore on failure
      setState(() => _notifications.insert(index, removed));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _onNotificationTap(Map<String, dynamic> notification, int index) async {
    // Mark as read first
    _markAsRead(notification['id'], index);

    final actionType = notification['action_type'] as String?;
    final refId = notification['reference_id'] as String?;

    final authService = AuthService();
    final role = await authService.getUserRole();
    final isAdmin = role == 'admin' || role == 'super_admin';

    if (!mounted) return;

    switch (actionType) {
      case 'delivery':
        if (refId != null) {
          if (isAdmin) {
             context.push('/admin/deliveries');
          } else {
             context.push('/tracking/$refId');
          }
        }
        break;
      case 'subscription':
      case 'pause':
      case 'resume':
      case 'cancel':
        if (isAdmin) {
          context.push('/admin/subscriptions');
        } else {
          context.push('/profile/subscription');
        }
        break;
      case 'order':
        if (isAdmin) {
          context.push('/admin/packages/orders');
        } else {
          context.push('/profile/subscription');
        }
        break;
      case 'fruit_order':
        if (isAdmin) {
          context.push('/admin/fruits/orders');
        } else {
          context.push('/fruits/orders');
        }
        break;
      case 'payment':
        if (isAdmin) {
          context.go('/admin');
        } else {
          context.go('/payments');
        }
        break;
      case 'promo':
        if (isAdmin) {
          context.go('/admin');
        } else {
          context.go('/home');
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['is_read'] == false).length;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Notifications'),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.done_all, size: 20, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  const Text(
                    'Read All',
                    style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'Clear All',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Notifications'),
                    content: const Text('Are you sure you want to clear all notifications?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearAll();
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
            ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: _categories.map((cat) {
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat['icon'] as IconData, size: 16),
                  const SizedBox(width: 6),
                  Text(cat['label'] as String),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _hasError
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: _categories.map((_) => _buildNotificationList()).toList(),
                ),
    );
  }

  Widget _buildNotificationList() {
    if (_notifications.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          final isRead = notification['is_read'] as bool? ?? false;
          final category = (notification['category'] ?? 'system') as String;
          final id = notification['id'] as String;

          return Dismissible(
            key: Key(id),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _deleteNotification(id, index),
            background: Container(
              color: AppTheme.error,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: _buildNotificationTile(notification, index, isRead, category),
          );
        },
      );
  }

  Widget _buildNotificationTile(
    Map<String, dynamic> notification,
    int index,
    bool isRead,
    String category,
  ) {
    final iconData = _categoryIcon(category);
    final iconColor = _categoryColor(category);
    final timeAgo = _formatTime(notification['created_at'] as String?);

    return InkWell(
      onTap: () => _onNotificationTap(notification, index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : AppTheme.primaryGreen.withValues(alpha: 0.04),
          border: Border(
            left: BorderSide(
              color: isRead ? Colors.transparent : AppTheme.primaryGreen,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['body'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppTheme.textLight),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                        ),
                        const Spacer(),
                        if (_hasNavigation(notification['action_type'] as String?))
                          Row(
                            children: [
                              Text(
                                'View',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryGreen.withValues(alpha: 0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                size: 14,
                                color: AppTheme.primaryGreen.withValues(alpha: 0.8),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _hasNavigation(String? actionType) {
    return actionType != null && actionType != 'system';
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'delivery': return Icons.local_shipping_outlined;
      case 'subscription': return Icons.restaurant_menu_outlined;
      case 'payment': return Icons.payment_outlined;
      case 'promo': return Icons.local_offer_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'delivery': return AppTheme.outForDelivery;
      case 'subscription': return AppTheme.primaryGreen;
      case 'payment': return AppTheme.success;
      case 'promo': return AppTheme.warning;
      default: return AppTheme.info;
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {
      return '';
    }
  }

  Widget _buildEmptyState() {
    final category = _currentCategory;
    final label = category != null
        ? '${category[0].toUpperCase()}${category.substring(1)} notifications'
        : 'notifications';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 48,
                color: AppTheme.primaryGreen.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No $label yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll let you know when there\'s an update.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: AppTheme.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Failed to load notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Checking connection...', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
