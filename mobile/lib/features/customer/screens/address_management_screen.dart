import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class AddressManagementScreen extends StatefulWidget {
  const AddressManagementScreen({super.key});

  @override
  State<AddressManagementScreen> createState() => _AddressManagementScreenState();
}

class _AddressManagementScreenState extends State<AddressManagementScreen> {
  final _api = ApiClient();
  List<dynamic> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.userAddresses);
      setState(() {
        _addresses = res.data is List ? res.data : [];
      });
    } catch (e) {
      debugPrint('Error loading addresses: $e');
      setState(() {
        _addresses = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setDefaultAddress(String id) async {
    try {
      await _api.patch('${ApiConstants.userAddresses}/$id/default');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default address updated'), backgroundColor: AppTheme.success),
      );
      _loadAddresses();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update default address'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _deleteAddress(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('${ApiConstants.userAddresses}/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address deleted successfully'), backgroundColor: AppTheme.success),
      );
      _loadAddresses();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete address'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showAddressForm({Map<String, dynamic>? addressToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddressFormSheet(
        addressToEdit: addressToEdit,
        onSave: () {
          Navigator.pop(context);
          _loadAddresses();
        },
      ),
    );
  }

  IconData _getAddressTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'home': return Icons.home_outlined;
      case 'work':
      case 'office': return Icons.business_outlined;
      default: return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Addresses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _addresses.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAddresses,
                  color: AppTheme.primaryGreen,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final addr = _addresses[index];
                      final id = addr['id'];
                      final isDefault = addr['is_default'] ?? false;
                      final type = addr['address_type'] ?? 'home';
                      final typeIcon = _getAddressTypeIcon(type);

                      return Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isDefault ? AppTheme.primaryGreen : Colors.grey.withValues(alpha: 0.2),
                            width: isDefault ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(typeIcon, color: AppTheme.primaryGreen),
                                  const SizedBox(width: 8),
                                  Text(
                                    (addr['label'] as String?)?.isNotEmpty == true
                                        ? addr['label']
                                        : type.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const Spacer(),
                                  if (isDefault)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'DEFAULT',
                                        style: TextStyle(
                                          color: AppTheme.primaryGreen,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    TextButton(
                                      onPressed: () => _setDefaultAddress(id),
                                      child: const Text('Set Default'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                addr['address_line1'] ?? '',
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              ),
                              if (addr['address_line2'] != null && (addr['address_line2'] as String).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  addr['address_line2'],
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                '${addr['city'] ?? ''}, ${addr['state'] ?? ''} - ${addr['pincode'] ?? ''}',
                                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                              ),
                              if (addr['landmark'] != null && (addr['landmark'] as String).isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Landmark: ${addr['landmark']}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                                ),
                              ],
                              const Divider(height: 24, thickness: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGreen),
                                    onPressed: () => _showAddressForm(addressToEdit: addr),
                                    tooltip: 'Edit Address',
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                    onPressed: () => _deleteAddress(id),
                                    tooltip: 'Delete Address',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressForm(),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_outlined, size: 80, color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No Saved Addresses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your delivery address to start receiving healthy fresh meals.',
              style: TextStyle(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final Map<String, dynamic>? addressToEdit;
  final VoidCallback onSave;

  const _AddressFormSheet({this.addressToEdit, required this.onSave});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();

  late final TextEditingController _recipientNameController;
  late final TextEditingController _recipientPhoneController;
  late final TextEditingController _labelController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _landmarkController;

  double? _latitude;
  double? _longitude;
  String _addressType = 'home';
  bool _isDefault = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.addressToEdit;
    _recipientNameController = TextEditingController(text: edit?['recipient_name'] ?? '');
    _recipientPhoneController = TextEditingController(text: edit?['recipient_phone'] ?? '');
    _labelController = TextEditingController(text: edit?['label'] ?? '');
    _line1Controller = TextEditingController(text: edit?['address_line1'] ?? '');
    _line2Controller = TextEditingController(text: edit?['address_line2'] ?? '');
    _cityController = TextEditingController(text: edit?['city'] ?? '');
    _stateController = TextEditingController(text: edit?['state'] ?? '');
    _pincodeController = TextEditingController(text: edit?['pincode'] ?? '');
    _landmarkController = TextEditingController(text: edit?['landmark'] ?? '');

    _latitude = edit?['latitude'] != null ? double.tryParse(edit!['latitude'].toString()) : null;
    _longitude = edit?['longitude'] != null ? double.tryParse(edit!['longitude'].toString()) : null;
    
    if (edit?['address_type'] != null) {
      _addressType = (edit!['address_type'] as String).toLowerCase();
      if (_addressType != 'home' && _addressType != 'work' && _addressType != 'office' && _addressType != 'other') {
        _addressType = 'other';
      } else if (_addressType == 'office') {
        _addressType = 'work'; // Align UI WORK label to office backend type
      }
    }
    
    _isDefault = edit?['is_default'] ?? false;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _labelController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your location on the map'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = {
        'recipient_name': _recipientNameController.text.trim(),
        'recipient_phone': _recipientPhoneController.text.trim(),
        'label': _labelController.text.trim().isNotEmpty ? _labelController.text.trim() : null,
        'address_type': _addressType == 'work' ? 'work' : _addressType, // maps UI WORK to work enum
        'address_line1': _line1Controller.text.trim(),
        'address_line2': _line2Controller.text.trim().isNotEmpty ? _line2Controller.text.trim() : null,
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'landmark': _landmarkController.text.trim().isNotEmpty ? _landmarkController.text.trim() : null,
        'latitude': _latitude,
        'longitude': _longitude,
        'is_default': _isDefault,
      };

      if (widget.addressToEdit != null) {
        final id = widget.addressToEdit!['id'];
        await _api.put('${ApiConstants.userAddresses}/$id', data: payload);
      } else {
        await _api.post(ApiConstants.userAddresses, data: payload);
      }

      widget.onSave();
    } catch (e) {
      debugPrint('Error saving address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save address details'), backgroundColor: AppTheme.error),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.addressToEdit != null ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Address Type Selector
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Home'),
                      selected: _addressType == 'home',
                      onSelected: (selected) {
                        if (selected) setState(() => _addressType = 'home');
                      },
                      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Office'),
                      selected: _addressType == 'work',
                      onSelected: (selected) {
                        if (selected) setState(() => _addressType = 'work');
                      },
                      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Other'),
                      selected: _addressType == 'other',
                      onSelected: (selected) {
                        if (selected) setState(() => _addressType = 'other');
                      },
                      selectedColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
                      checkmarkColor: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Recipient Name
              TextFormField(
                controller: _recipientNameController,
                decoration: InputDecoration(
                  labelText: 'Recipient Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Recipient name is required' : null,
              ),
              const SizedBox(height: 16),

              // Recipient Phone
              TextFormField(
                controller: _recipientPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Recipient Mobile Number',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Recipient mobile number is required';
                  if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(val.trim())) return 'Invalid mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Custom Label (Optional)
              TextFormField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Address Nickname (Optional, e.g. Mom\'s house)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Line 1 (Flat / House No.)
              TextFormField(
                controller: _line1Controller,
                decoration: InputDecoration(
                  labelText: 'Flat / House No. / Building Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'House/Flat details are required' : null,
              ),
              const SizedBox(height: 16),

              // Line 2 (Street / Area)
              TextFormField(
                controller: _line2Controller,
                decoration: InputDecoration(
                  labelText: 'Street Address / Area (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // City & State Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'City is required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      decoration: InputDecoration(
                        labelText: 'State',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'State is required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pincode & Landmark Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Pincode required';
                        if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) return 'Invalid Pincode';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _landmarkController,
                      decoration: InputDecoration(
                        labelText: 'Landmark (Optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Map Location Picker Button
              Card(
                elevation: 0,
                color: _latitude != null && _longitude != null
                    ? AppTheme.primaryGreen.withValues(alpha: 0.08)
                    : Colors.red.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _latitude != null && _longitude != null
                        ? AppTheme.primaryGreen
                        : Colors.red,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.map_rounded,
                    color: _latitude != null && _longitude != null ? AppTheme.primaryGreen : Colors.red,
                  ),
                  title: Text(
                    _latitude != null && _longitude != null ? 'Location Pinned' : 'Pin Location on Map',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _latitude != null && _longitude != null ? AppTheme.primaryGreen : Colors.red,
                    ),
                  ),
                  subtitle: Text(
                    _latitude != null && _longitude != null
                        ? 'Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}'
                        : 'Required: Select delivery coordinates',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final LatLng? result = await Navigator.push<LatLng>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => _MapLocationPickerDialog(
                          initialLat: _latitude,
                          initialLng: _longitude,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _latitude = result.latitude;
                        _longitude = result.longitude;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Default Toggle
              CheckboxListTile(
                value: _isDefault,
                title: const Text('Set as default delivery address', style: TextStyle(fontSize: 14)),
                onChanged: (val) => setState(() => _isDefault = val ?? false),
                activeColor: AppTheme.primaryGreen,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.addressToEdit != null ? 'Save Changes' : 'Add Address',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapLocationPickerDialog extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const _MapLocationPickerDialog({this.initialLat, this.initialLng});

  @override
  State<_MapLocationPickerDialog> createState() => _MapLocationPickerDialogState();
}

class _MapLocationPickerDialogState extends State<_MapLocationPickerDialog> {
  LatLng _selectedLatLng = const LatLng(12.9716, 77.5946); // Default Bangalore coordinates

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLatLng = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selectedLatLng),
            child: const Text('CONFIRM', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLatLng,
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: const MarkerId('selected_pos'),
                position: _selectedLatLng,
                draggable: true,
                onDragEnd: (newPosition) {
                  setState(() {
                    _selectedLatLng = newPosition;
                  });
                },
              ),
            },
            onTap: (latLng) {
              setState(() {
                _selectedLatLng = latLng;
              });
            },
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: AppTheme.primaryGreen),
                        SizedBox(width: 8),
                        Text('Selected Coordinates', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_selectedLatLng.latitude.toStringAsFixed(6)}, Lng: ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap on the map or drag the marker to pin your exact delivery spot.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
