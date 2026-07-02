import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/auth_service.dart';
import 'package:go_router/go_router.dart';

class DeliveryProfileScreen extends StatefulWidget {
  const DeliveryProfileScreen({super.key});

  @override
  State<DeliveryProfileScreen> createState() => _DeliveryProfileScreenState();
}

class _DeliveryProfileScreenState extends State<DeliveryProfileScreen> {
  final _api = ApiClient();
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.partnerProfile);
      setState(() {
        _profile = res.data;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateVehicleDetails(String type, String number) async {
    setState(() => _isLoading = true);
    try {
      await _api.put(ApiConstants.partnerProfile, data: {
        'vehicle_type': type,
        'vehicle_number': number,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle details updated successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update vehicle details'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _showEditVehicleDialog() {
    final numberController = TextEditingController(text: _profile!['delivery_partner']?['vehicle_number'] ?? '');
    String selectedType = _profile!['delivery_partner']?['vehicle_type'] ?? 'motorcycle';
    
    final vehicleTypes = ['bicycle', 'motorcycle', 'car', 'van'];
    if (!vehicleTypes.contains(selectedType)) {
      selectedType = 'motorcycle';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Vehicle Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicle Type', 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                items: vehicleTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                )).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedType = val);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Vehicle Number', 
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)
              ),
              const SizedBox(height: 6),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  hintText: 'Enter vehicle number',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateVehicleDetails(selectedType, numberController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _profile?['photo_url'];
    final imageProvider = photoUrl != null 
        ? NetworkImage('${_api.mediaBaseUrl}$photoUrl') 
        : null;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadProfile),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _profile == null
              ? const Center(child: Text('Could not load profile.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? const Icon(Icons.person, size: 50, color: AppTheme.primaryGreen)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['full_name'] ?? 'Delivery Partner',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile!['mobile_number'] ?? '',
                        style: const TextStyle(color: AppTheme.textLight, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      
                      // Account Info Box
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade100, width: 1.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Column(
                            children: [
                              _buildInfoRow(
                                Icons.badge_outlined, 
                                'Employee ID', 
                                _profile!['delivery_partner']?['employee_code'] ?? '—'
                              ),
                              const Divider(height: 1),
                              _buildInfoRow(
                                Icons.directions_car_outlined, 
                                'Vehicle Type', 
                                (_profile!['delivery_partner']?['vehicle_type'] ?? '—').toString().toUpperCase()
                              ),
                              const Divider(height: 1),
                              _buildInfoRow(
                                Icons.tag, 
                                'Vehicle Number', 
                                _profile!['delivery_partner']?['vehicle_number'] ?? '—',
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen, size: 20),
                                  onPressed: _showEditVehicleDialog,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            await AuthService().logout();
                            if (context.mounted) {
                              context.go('/role-selection');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textLight),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}
