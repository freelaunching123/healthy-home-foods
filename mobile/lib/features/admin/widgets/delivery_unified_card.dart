import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class DeliveryUnifiedCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onAssignTap;
  final VoidCallback onTap;

  const DeliveryUnifiedCard({
    super.key,
    required this.delivery,
    required this.onAssignTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSubscription = delivery['order_type'] == 'subscription';
    final String typeLabel = isSubscription ? 'Subscription Package' : 'Fruit Order';
    final Color typeColor = isSubscription ? AppTheme.primaryBlue : AppTheme.accentOrange;

    final bool isAssigned = delivery['delivery_partner_name'] != null;
    final String assignedName = delivery['delivery_partner_name'] ?? '';

    final String customerName = delivery['customer_name'] ?? 'Unknown';
    final String customerPhone = delivery['phone'] ?? '';
    final String address = delivery['delivery_address'] ?? 'No Address';
    final String itemSummary = delivery['item_summary'] ?? 'Items';

    final String status = delivery['status'] ?? 'pending';
    final Color statusColor = _getStatusColor(status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: typeColor),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Customer & Item info
              Text(
                customerName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(customerPhone, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                itemSummary,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Assignment Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isAssigned) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primaryGreen.withOpacity(0.2),
                          child: const Icon(Icons.person, size: 16, color: AppTheme.primaryGreen),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Assigned To', style: TextStyle(fontSize: 10, color: Colors.grey)),
                            Text(assignedName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: onAssignTap,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Change'),
                    ),
                  ] else ...[
                    const Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: AppTheme.warning),
                        SizedBox(width: 4),
                        Text('Unassigned', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: onAssignTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Assign Partner'),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return AppTheme.success;
      case 'out_for_delivery':
      case 'out':
        return AppTheme.primaryBlue;
      case 'assigned':
        return AppTheme.primaryGreen;
      case 'failed':
      case 'cancelled':
      case 'missed':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }
}
