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
      final res = await _api.get(ApiConstants.userProfile);
      setState(() {
        _profile = res.data;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(String field, String value) async {
    try {
      await _api.put(ApiConstants.partnerProfile, data: {field: value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
      }
      _loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
      }
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Enter new $title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile(field, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryGreen,
                        child: Icon(Icons.person, size: 50, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profile!['full_name'] ?? 'Delivery Partner',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(_profile!['mobile_number'] ?? '', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 32),
                      
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.directions_car),
                        title: const Text('Vehicle Details'),
                        subtitle: Text('${_profile!['delivery_partner']?['vehicle_type'] ?? 'Not set'} - ${_profile!['delivery_partner']?['vehicle_number'] ?? 'Not set'}'),
                        trailing: const Icon(Icons.edit, size: 16),
                        onTap: () {
                          // Allow editing vehicle type/number
                          _showEditDialog('Vehicle Number', 'vehicle_number', _profile!['delivery_partner']?['vehicle_number'] ?? '');
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          label: const Text('Logout', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () async {
                            await AuthService().logout();
                            if (context.mounted) {
                              context.go('/login');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
