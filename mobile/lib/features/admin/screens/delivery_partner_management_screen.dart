import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/password_rules.dart';
import '../../../core/utils/api_error_handler.dart';
import '../../auth/widgets/password_validation_rules_widget.dart';

class DeliveryPartnerManagementScreen extends StatefulWidget {
  const DeliveryPartnerManagementScreen({super.key});

  @override
  State<DeliveryPartnerManagementScreen> createState() =>
      _DeliveryPartnerManagementScreenState();
}

class _DeliveryPartnerManagementScreenState
    extends State<DeliveryPartnerManagementScreen> {
  final _api = ApiClient();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _partners = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  bool? _activeFilter; // null = all, true = active, false = inactive

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _load(isSilent: true);
    });
  }

  Future<void> _load({bool isSilent = false}) async {
    if (!isSilent) setState(() => _isLoading = true);
    try {
      final res = await _api.get('/delivery-partners');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _partners = list;
        _applyFilter();
      });
    } catch (e) {
      if (!isSilent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load: ${ApiErrorHandler.getMessage(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (!isSilent && mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _partners.where((p) {
        final matchSearch = q.isEmpty ||
            (p['full_name'] ?? '').toString().toLowerCase().contains(q) ||
            (p['mobile_number'] ?? '').toString().contains(q);
        final matchStatus = _activeFilter == null ||
            (p['is_active'] as bool? ?? true) == _activeFilter;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _toggleStatus(Map<String, dynamic> partner) async {
    final newStatus = !(partner['is_active'] as bool? ?? true);
    try {
      await _api.patch(
        '/delivery-partners/${partner['id']}/status',
        data: {'is_active': newStatus},
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${partner['full_name']} ${newStatus ? 'activated' : 'deactivated'}',
            ),
            backgroundColor: newStatus ? AppTheme.success : AppTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${ApiErrorHandler.getMessage(e)}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (_) => _EditPartnerDialog(
        partner: partner,
        onSaved: _load,
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> partner) {
    showDialog(
      context: context,
      builder: (_) => _ResetPasswordDialog(partner: partner),
    );
  }

  Future<void> _deletePartner(Map<String, dynamic> partner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Delivery Partner'),
        content: const Text(
          'Are you sure you want to delete this Delivery Partner? This action will remove the account from active operations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.delete('/delivery-partners/${partner['id']}');
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery Partner deleted successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${ApiErrorHandler.getMessage(e)}'),
            backgroundColor: AppTheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('Manage Delivery Partners'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/delivery-partners/create');
          _load(); // Reload after returning from create
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Partner'),
        backgroundColor: AppTheme.primaryGreen,
      ),
      body: Column(
        children: [
          // Search + Filter bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                // Search field
                TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilter(),
                  decoration: InputDecoration(
                    hintText: 'Search by name or mobile...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilter();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryGreen,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                Row(
                  children: [
                    const Text(
                      'Filter: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'All',
                      selected: _activeFilter == null,
                      onTap: () {
                        setState(() => _activeFilter = null);
                        _applyFilter();
                      },
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Active',
                      selected: _activeFilter == true,
                      onTap: () {
                        setState(() => _activeFilter = true);
                        _applyFilter();
                      },
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Inactive',
                      selected: _activeFilter == false,
                      onTap: () {
                        setState(() => _activeFilter = false);
                        _applyFilter();
                      },
                      color: AppTheme.error,
                    ),
                    const Spacer(),
                    Text(
                      '${_filtered.length} found',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : _filtered.isEmpty
                    ? _EmptyState(
                        hasSearch: _searchController.text.isNotEmpty ||
                            _activeFilter != null,
                      )
                    : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) => _PartnerCard(
                            partner: _filtered[i],
                            onTap: () => context.push(
                              '/admin/delivery-partners/${_filtered[i]['id']}',
                              extra: _filtered[i],
                            ),
                            onEdit: () => _showEditDialog(_filtered[i]),
                            onToggleStatus: () => _toggleStatus(_filtered[i]),
                            onResetPassword: () =>
                                _showResetPasswordDialog(_filtered[i]),
                            onDelete: () => _deletePartner(_filtered[i]),
                          ),
                        ),
          ),
        ],
      ),
    );
  }
}

// ── Partner Card ──────────────────────────────────────────────────────────────

class _PartnerCard extends StatelessWidget {
  final Map<String, dynamic> partner;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  const _PartnerCard({
    required this.partner,
    required this.onTap,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onResetPassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = partner['is_active'] as bool? ?? true;
    final name = partner['full_name'] ?? 'Unknown';
    final mobile = partner['mobile_number'] ?? '';
    final age = partner['age'];
    final gender = partner['gender'] ?? '';
    final photoUrl = partner['photo_url'];
    final assignedCount = partner['assigned_count'] ?? 0;
    final totalDeliveries = partner['total_deliveries'] ?? 0;
    final rating = partner['rating'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? Colors.green.shade100
              : Colors.red.shade100,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Avatar
                  _Avatar(photoUrl: photoUrl, name: name, isActive: isActive),
                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(isActive: isActive),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 13,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mobile,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (age != null) ...[
                              const Icon(
                                Icons.cake_outlined,
                                size: 13,
                                color: AppTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$age yrs',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (gender.isNotEmpty) ...[
                              const Icon(
                                Icons.person_outline,
                                size: 13,
                                color: AppTheme.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                gender,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats row
              Row(
                children: [
                  _StatBadge(
                    icon: Icons.local_shipping_outlined,
                    label: 'Assigned',
                    value: '$assignedCount',
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 12),
                  _StatBadge(
                    icon: Icons.check_circle_outline,
                    label: 'Total',
                    value: '$totalDeliveries',
                    color: AppTheme.success,
                  ),
                  if (rating != null) ...[
                    const SizedBox(width: 12),
                    _StatBadge(
                      icon: Icons.star_outline,
                      label: 'Rating',
                      value: rating.toStringAsFixed(1),
                      color: AppTheme.warning,
                    ),
                  ],
                  const Spacer(),
                  // Action buttons
                  _ActionButton(
                    icon: Icons.lock_reset_outlined,
                    tooltip: 'Reset Password',
                    color: AppTheme.info,
                    onTap: onResetPassword,
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    color: AppTheme.primaryGreen,
                    onTap: onEdit,
                  ),
                  const SizedBox(width: 6),
                  // Toggle switch
                  GestureDetector(
                    onTap: onToggleStatus,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 48,
                      height: 28,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isActive
                            ? AppTheme.success
                            : Colors.grey.shade300,
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: isActive
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    color: AppTheme.error,
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final bool isActive;

  const _Avatar({this.photoUrl, required this.name, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
          backgroundImage: photoUrl != null
              ? NetworkImage('${ApiClient().mediaBaseUrl}$photoUrl')
              : null,
          child: photoUrl == null
              ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                )
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.success : Colors.grey.shade400,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.success.withValues(alpha: 0.1)
            : AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive ? AppTheme.success : AppTheme.error,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.people_outline_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No results found' : 'No delivery partners yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try a different name or mobile number'
                : 'Tap + to add the first delivery partner',
            style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }
}

// ── Edit Dialog ───────────────────────────────────────────────────────────────

class _EditPartnerDialog extends StatefulWidget {
  final Map<String, dynamic> partner;
  final VoidCallback onSaved;

  const _EditPartnerDialog({required this.partner, required this.onSaved});

  @override
  State<_EditPartnerDialog> createState() => _EditPartnerDialogState();
}

class _EditPartnerDialogState extends State<_EditPartnerDialog> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _ageCtrl;
  late String _gender;
  String? _photoBase64;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.partner['full_name'] ?? '');
    _mobileCtrl =
        TextEditingController(text: widget.partner['mobile_number'] ?? '');
    _ageCtrl = TextEditingController(
      text: widget.partner['age']?.toString() ?? '',
    );
    _gender = widget.partner['gender'] ?? 'Male';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _photoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final payload = <String, dynamic>{
        'full_name': _nameCtrl.text.trim(),
        'mobile_number': _mobileCtrl.text.trim(),
        'age': int.tryParse(_ageCtrl.text) ?? widget.partner['age'],
        'gender': _gender,
        if (_photoBase64 != null) 'photo_base64': _photoBase64,
      };
      await _api.put('/delivery-partners/${widget.partner['id']}',
          data: payload);
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partner updated successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Update failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_rounded, color: AppTheme.primaryGreen),
                  const SizedBox(width: 10),
                  const Text(
                    'Edit Delivery Partner',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Photo picker
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor:
                            AppTheme.primaryGreen.withValues(alpha: 0.1),
                        backgroundImage: _photoBase64 != null
                            ? MemoryImage(
                                base64Decode(
                                    _photoBase64!.split(',').last),
                              )
                            : (widget.partner['photo_url'] != null
                                ? NetworkImage(
                                    '${ApiClient().mediaBaseUrl}${widget.partner['photo_url']}',
                                  ) as ImageProvider
                                : null),
                        child: (_photoBase64 == null &&
                                widget.partner['photo_url'] == null)
                            ? Text(
                                (widget.partner['full_name'] ?? '?')[0]
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryGreen,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryGreen,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              // Mobile
              TextFormField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                validator: (v) {
                  if (v == null || v.length != 10) return 'Enter 10-digit number';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Age
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
              ),
              const SizedBox(height: 14),

              // Gender
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reset Password Dialog ─────────────────────────────────────────────────────

class _ResetPasswordDialog extends StatefulWidget {
  final Map<String, dynamic> partner;
  const _ResetPasswordDialog({required this.partner});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _api = ApiClient();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String _passwordText = '';

  @override
  void initState() {
    super.initState();
    _pwdCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordText = _pwdCtrl.text;
    });
  }

  @override
  void dispose() {
    _pwdCtrl.removeListener(_onPasswordChanged);
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!PasswordRules.isValid(_pwdCtrl.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password does not meet validation rules'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_pwdCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _api.patch(
        '/delivery-partners/${widget.partner['id']}/password',
        data: {'new_password': _pwdCtrl.text},
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.data?['detail'] ?? 'Reset failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_reset_outlined, color: AppTheme.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset Password for\n${widget.partner['full_name']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pwdCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            PasswordValidationRulesWidget(password: _passwordText),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              onChanged: (val) {
                setState(() {});
              },
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || !PasswordRules.isValid(_passwordText) || _passwordText != _confirmCtrl.text) ? null : _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.info,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Reset Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
