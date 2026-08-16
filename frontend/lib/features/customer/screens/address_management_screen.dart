import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:geolocator/geolocator.dart';
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
              : ListView.separated(
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
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: 'Recipient Mobile Number',
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Recipient mobile number is required';
                  if (val.trim().length != 10) return 'Mobile number must be exactly 10 digits';
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

class _MapLocationPickerDialogState extends State<_MapLocationPickerDialog> with TickerProviderStateMixin {
  LatLng _selectedLatLng = const LatLng(9.919630, 78.094379); // Default to shop coordinates if null
  LatLng? _currentLatLng;
  double? _currentAccuracy;
  GoogleMapController? _mapController;
  
  bool _isLocating = false;
  bool _isConfirming = false;
  
  double _currentZoom = 15.0;
  
  // Real-time location stream and map animation controllers
  // Detection of map movement (idle detection)
  Timer? _mapIdleTimer;
  bool _isMapMoving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedLatLng = LatLng(widget.initialLat!, widget.initialLng!);
    }
    // Check permission and load location after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionAndLoadLocation();
    });
  }

  @override
  void dispose() {
    _mapIdleTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(destLocation, destZoom),
    );
  }

  Future<void> _checkPermissionAndLoadLocation() async {
    if (_isLocating) return;

    setState(() => _isLocating = true);
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLocating = false);
        if (mounted) {
          _showGpsOffDialog();
        }
        return;
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLocating = false);
          _showSnackbar('Location permission is required to fetch your current position.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLocating = false);
        _showSnackbar('Location permissions are permanently denied. Please enable them in settings.');
        return;
      }

      // 3. Get current location
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('Error getting last known position: $e');
      }

      if (position != null) {
        final lastKnownPoint = LatLng(position.latitude, position.longitude);
        setState(() {
          _currentLatLng = lastKnownPoint;
          _currentAccuracy = position!.accuracy;
          _selectedLatLng = lastKnownPoint;
        });
        _animatedMapMove(lastKnownPoint, 16.0);
      }

      // Query fresh position with medium accuracy & shorter timeout for faster response
      try {
        final freshPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 4),
          ),
        );
        
        final freshPoint = LatLng(freshPosition.latitude, freshPosition.longitude);
        setState(() {
          _currentLatLng = freshPoint;
          _currentAccuracy = freshPosition.accuracy;
          _selectedLatLng = freshPoint;
        });
        _animatedMapMove(freshPoint, 16.0);
      } catch (e) {
        debugPrint('Error getting fresh position: $e');
        if (_currentLatLng == null) {
          _showSnackbar('Location detection timed out. Please select location manually or verify browser GPS settings.');
        }
      }


    } catch (e) {
      debugPrint('Error getting location: $e');
      _showSnackbar('Unable to detect your current location. Please enable GPS.');
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  void _showGpsOffDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text('Please turn on your device location to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
              // Recheck after returning
              _checkPermissionAndLoadLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _getDistanceString() {
    if (_currentLatLng == null) return '--';
    final distanceInMeters = Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      _selectedLatLng.latitude,
      _selectedLatLng.longitude,
    );
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      final distanceInKm = distanceInMeters / 1000;
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }

  String _getTravelTimeString() {
    if (_currentLatLng == null) return '--';
    final distanceInMeters = Geolocator.distanceBetween(
      _currentLatLng!.latitude,
      _currentLatLng!.longitude,
      _selectedLatLng.latitude,
      _selectedLatLng.longitude,
    );
    // Assume average delivery speed is 25 km/h (approx 416 meters per minute)
    // Plus a base cooking/prep/handover buffer of 15 minutes.
    final travelMinutes = (distanceInMeters / 416) + 15;
    return '${travelMinutes.toStringAsFixed(0)} mins';
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedLatLng = position.target;
      _currentZoom = position.zoom;
      if (!_isMapMoving) {
        _isMapMoving = true;
      }
    });
  }

  void _onCameraIdle() {
    if (mounted) {
      setState(() {
        _isMapMoving = false;
      });
    }
  }

  Widget _buildCoordinateColumn({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9), // Translucent Material 3 style
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Delivery Location',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen),
                  )
                : const Icon(Icons.gps_fixed_rounded, color: AppTheme.primaryGreen),
            onPressed: _checkPermissionAndLoadLocation,
            tooltip: 'Get Current Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLatLng,
              zoom: _currentZoom,
            ),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: _currentLatLng != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
          ),

          // Static Center Pin overlay
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35), // adjust height to align pin tip
                child: DeliveryPinWidget(isMoving: _isMapMoving),
              ),
            ),
          ),

          // Floating map controls on the right side
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.38, // float above the bottom sheet
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                _AnimatedFloatingButton(
                  icon: Icons.add_rounded,
                  onPressed: () {
                    final nextZoom = (_currentZoom + 1.0).clamp(1.0, 18.0);
                    _animatedMapMove(_selectedLatLng, nextZoom);
                  },
                  tooltip: 'Zoom In',
                ),
                const SizedBox(height: 12),
                _AnimatedFloatingButton(
                  icon: Icons.remove_rounded,
                  onPressed: () {
                    final nextZoom = (_currentZoom - 1.0).clamp(1.0, 18.0);
                    _animatedMapMove(_selectedLatLng, nextZoom);
                  },
                  tooltip: 'Zoom Out',
                ),
                const SizedBox(height: 12),
                _AnimatedFloatingButton(
                  icon: Icons.my_location_rounded,
                  iconColor: AppTheme.primaryGreen,
                  isLoading: _isLocating,
                  onPressed: _checkPermissionAndLoadLocation,
                  tooltip: 'Current Location',
                ),
              ],
            ),
          ),

          // Draggable Bottom Sheet with Location Info
          DraggableScrollableSheet(
            initialChildSize: 0.32,
            minChildSize: 0.22,
            maxChildSize: 0.45,
            snap: true,
            snapSizes: const [0.22, 0.32, 0.45],
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Drag handle
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        
                        // Title
                        const Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppTheme.primaryGreen, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Delivery Location',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Coordinates
                        Row(
                          children: [
                            Expanded(
                              child: _buildCoordinateColumn(
                                label: 'LATITUDE',
                                value: _selectedLatLng.latitude.toStringAsFixed(6),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildCoordinateColumn(
                                label: 'LONGITUDE',
                                value: _selectedLatLng.longitude.toStringAsFixed(6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),



                        // Confirm Button
                        ElevatedButton(
                          onPressed: _isConfirming
                              ? null
                              : () async {
                                  setState(() => _isConfirming = true);
                                  await Future.delayed(const Duration(milliseconds: 500));
                                  if (mounted) {
                                    _showSnackbar('✓ Location Selected Successfully');
                                    Navigator.pop(context, _selectedLatLng);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
                          ),
                          child: _isConfirming
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Confirm Delivery Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Custom widget for Delivery Pin
class DeliveryPinWidget extends StatelessWidget {
  final bool isMoving;
  const DeliveryPinWidget({super.key, required this.isMoving});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, isMoving ? -12 : 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.restaurant_menu_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              CustomPaint(
                size: const Size(12, 8),
                painter: TrianglePainter(color: AppTheme.primaryGreen),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: isMoving ? 8 : 16,
          height: isMoving ? 2 : 4,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: isMoving ? 0.15 : 0.35),
            borderRadius: BorderRadius.all(Radius.elliptical(isMoving ? 4 : 8, isMoving ? 1 : 2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isMoving ? 0.1 : 0.25),
                blurRadius: isMoving ? 2 : 4,
                spreadRadius: isMoving ? 0.5 : 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom widget for animated floating buttons
class _AnimatedFloatingButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final Color? iconColor;
  final bool isLoading;

  const _AnimatedFloatingButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.iconColor,
    this.isLoading = false,
  });

  @override
  State<_AnimatedFloatingButton> createState() => _AnimatedFloatingButtonState();
}

class _AnimatedFloatingButtonState extends State<_AnimatedFloatingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : () async {
              _controller.forward().then((_) => _controller.reverse());
              widget.onPressed();
            },
            borderRadius: BorderRadius.circular(24),
            child: Tooltip(
              message: widget.tooltip ?? '',
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryGreen,
                          ),
                        )
                      : Icon(
                          widget.icon,
                          color: widget.iconColor ?? AppTheme.textPrimary,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
