import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class DeliveryPartnerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> partners;
  final Function(String partnerId) onAssign;
  final bool isActionInProgress;

  const DeliveryPartnerDialog({
    super.key,
    required this.partners,
    required this.onAssign,
    this.isActionInProgress = false,
  });

  @override
  State<DeliveryPartnerDialog> createState() => _DeliveryPartnerDialogState();
}

class _DeliveryPartnerDialogState extends State<DeliveryPartnerDialog> {
  String _searchQuery = '';
  
  @override
  Widget build(BuildContext context) {
    final filteredPartners = widget.partners.where((p) {
      final name = (p['full_name'] ?? '').toString().toLowerCase();
      final empCode = (p['employee_code'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || empCode.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assign Delivery Partner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or ID...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredPartners.isEmpty
                  ? const Center(child: Text('No partners found'))
                  : ListView.builder(
                      itemCount: filteredPartners.length,
                      itemBuilder: (context, index) {
                        final partner = filteredPartners[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                              child: const Icon(Icons.local_shipping, color: AppTheme.primaryGreen),
                            ),
                            title: Text(
                              partner['full_name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${partner['employee_code']}'),
                                Text('Assigned: ${partner['assigned_count'] ?? 0}'),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: widget.isActionInProgress
                                ? const CircularProgressIndicator()
                                : ElevatedButton(
                                    onPressed: () => widget.onAssign(partner['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Assign'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
