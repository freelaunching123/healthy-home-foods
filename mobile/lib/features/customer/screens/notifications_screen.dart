import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
// Note: This will integrate with Firebase Cloud Messaging (FCM) later

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Delivery Arriving Soon',
      'body': 'Your healthy meal delivery is 10 minutes away!',
      'time': '10 mins ago',
      'type': 'delivery',
      'isRead': false,
    },
    {
      'title': 'Payment Successful',
      'body': 'Your monthly subscription has been renewed.',
      'time': '2 hours ago',
      'type': 'payment',
      'isRead': true,
    },
    {
      'title': 'New Menu Items',
      'body': 'Check out our new high-protein salad options!',
      'time': '1 day ago',
      'type': 'promo',
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All marked as read')),
              );
            },
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['isRead'] as bool;
                final type = notification['type'] as String;

                IconData iconData;
                Color iconColor;

                switch (type) {
                  case 'delivery':
                    iconData = Icons.local_shipping;
                    iconColor = AppTheme.pending;
                    break;
                  case 'payment':
                    iconData = Icons.payment;
                    iconColor = AppTheme.success;
                    break;
                  case 'promo':
                  default:
                    iconData = Icons.local_offer;
                    iconColor = AppTheme.primaryGreen;
                    break;
                }

                return Container(
                  color: isRead ? Colors.transparent : AppTheme.primaryGreen.withValues(alpha: 0.05),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: iconColor.withValues(alpha: 0.1),
                      child: Icon(iconData, color: iconColor),
                    ),
                    title: Text(
                      notification['title'],
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notification['body'],
                          style: TextStyle(
                            color: isRead ? AppTheme.textSecondary : AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          notification['time'],
                          style: const TextStyle(
                            color: AppTheme.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!isRead) {
                        setState(() {
                          _notifications[index]['isRead'] = true;
                        });
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          const Text('No notifications yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('We will let you know when there is an update', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
