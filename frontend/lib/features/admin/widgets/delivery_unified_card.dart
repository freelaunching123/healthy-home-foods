import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class DeliveryUnifiedCard extends StatelessWidget {
  final Map<String, dynamic> delivery;
  final VoidCallback onAssignTap;
  final VoidCallback onTap;

  // New action callbacks
  final VoidCallback? onCancelTap;
  final VoidCallback? onNavigateTap;
  final VoidCallback? onMarkOutTap;
  final VoidCallback? onDeliveredTap;
  final VoidCallback? onFailedTap;
  final VoidCallback? onInvoiceTap;

  const DeliveryUnifiedCard({
    super.key,
    required this.delivery,
    required this.onAssignTap,
    required this.onTap,
    this.onCancelTap,
    this.onNavigateTap,
    this.onMarkOutTap,
    this.onDeliveredTap,
    this.onFailedTap,
    this.onInvoiceTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSubscription = delivery['order_type'] == 'subscription';
    final String typeLabel = isSubscription ? 'Package' : 'Grocery';
    final Color typeColor = isSubscription ? AppTheme.primaryBlue : AppTheme.accentOrange;

    final String customerName = delivery['customer_name'] ?? 'Unknown';
    final String customerPhone = delivery['phone'] ?? '';
    final String address = delivery['delivery_address'] ?? 'No Address';
    
    final double amount = (delivery['amount'] as num?)?.toDouble() ?? 0.0;
    final String deliveryTime = delivery['delivery_time'] ?? 'Morning';
    final String paymentStatus = delivery['payment_status'] ?? 'Pending';
    
    final String assignedName = delivery['delivery_partner_name'] ?? 'Unassigned';
    final bool isAssigned = delivery['delivery_partner_name'] != null;

    final String status = delivery['status'] ?? 'pending';
    final Color statusColor = _getStatusColor(status);
    
    final String rawId = (delivery['id'] ?? '').toString();
    final String displayId = rawId.length >= 8 ? rawId.substring(0, 8).toUpperCase() : rawId;

    final formatCurrency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact Content Header
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Type Badge, ID, Amount, Status Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: typeColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isSubscription ? Icons.inventory_2_outlined : Icons.shopping_bag_outlined, size: 12, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              typeLabel,
                              style: TextStyle(color: typeColor, fontWeight: FontWeight.w700, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('#$displayId', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Text(
                        formatCurrency.format(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Middle Row: Customer Name & Phone
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.phone_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(customerPhone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Bottom Row: Address & Partner
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline, size: 13, color: isAssigned ? AppTheme.primaryGreen : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        assignedName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isAssigned ? AppTheme.primaryGreen : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Action Buttons Bottom Bar (Compact)
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFFFAFAFA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _buildActionRow(status),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label, String value, {bool? isSuccess}) {
    Color valColor = AppTheme.textPrimary;
    if (isSuccess == true) valColor = AppTheme.primaryGreen;
    if (isSuccess == false) valColor = AppTheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: valColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildActionRow(String status) {
    if (status == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancelTap,
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onAssignTap,
            icon: const Icon(Icons.person_add, size: 16),
            label: const Text('Assign Partner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    } else if (status == 'assigned') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onReassignTap ?? onAssignTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Reassign'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onMarkOutTap,
            icon: const Icon(Icons.delivery_dining, size: 16),
            label: const Text('Mark Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    } else if (status == 'out_for_delivery') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onFailedTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Failed'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onDeliveredTap,
            icon: const Icon(Icons.check_circle, size: 16),
            label: const Text('Delivered'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    } else if (status == 'delivered') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onInvoiceTap,
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('Invoice'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryGreen,
              side: const BorderSide(color: AppTheme.primaryGreen),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Details'),
          ),
        ],
      );
    } else {
      // Cancelled, failed, etc.
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Details'),
          ),
        ],
      );
    }
  }

  // Alias for backward compatibility if needed
  VoidCallback get onReassignTap => onAssignTap;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return AppTheme.warning;
      case 'assigned': return Colors.teal;
      case 'out_for_delivery': return AppTheme.primaryBlue;
      case 'delivered': return AppTheme.success;
      case 'cancelled':
      case 'failed':
      case 'missed': return AppTheme.error;
      default: return Colors.grey;
    }
  }
}
