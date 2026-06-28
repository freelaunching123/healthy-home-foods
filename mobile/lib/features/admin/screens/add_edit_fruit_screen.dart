import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class AddEditFruitScreen extends StatefulWidget {
  final String? fruitId;
  const AddEditFruitScreen({super.key, this.fruitId});

  @override
  State<AddEditFruitScreen> createState() => _AddEditFruitScreenState();
}

class _AddEditFruitScreenState extends State<AddEditFruitScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String _availability = 'in_stock';
  bool _isActive = true;
  String? _existingImageUrl;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _loading = false;
  bool _saving = false;
  bool _uploadingImage = false;
  String? _savedFruitId;
  String? _error;

  bool get _isEdit => widget.fruitId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadFruit();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFruit() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('${ApiConstants.adminFruits}/${widget.fruitId}');
      final data = res.data as Map<String, dynamic>;
      _nameCtrl.text = data['name'] as String? ?? '';
      _descCtrl.text = data['description'] as String? ?? '';
      _priceCtrl.text = (data['price_per_kg'] as num?)?.toString() ?? '';
      setState(() {
        _availability = data['availability_status'] as String? ?? 'in_stock';
        _isActive = data['is_active'] as bool? ?? true;
        _existingImageUrl = data['image_url'] as String?;
        _savedFruitId = widget.fruitId;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'price_per_kg': double.parse(_priceCtrl.text.trim()),
        'availability_status': _availability,
        'is_active': _isActive,
      };

      Map<String, dynamic> savedData;
      if (_isEdit) {
        final res = await _api.put('${ApiConstants.adminFruits}/${widget.fruitId}', data: payload);
        savedData = res.data as Map<String, dynamic>;
      } else {
        final res = await _api.post(ApiConstants.adminFruits, data: payload);
        savedData = res.data as Map<String, dynamic>;
      }
      _savedFruitId = savedData['id'] as String;

      // Upload image if picked
      if (_pickedImage != null) {
        setState(() { _saving = false; _uploadingImage = true; });
        await _uploadImage(_savedFruitId!);
        setState(() => _uploadingImage = false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Fruit updated successfully!' : 'Fruit added successfully!'),
            backgroundColor: AppTheme.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _uploadingImage = false;
        _error = 'Failed to save fruit. Please check your inputs and try again.';
      });
    }
  }

  Future<void> _uploadImage(String fruitId) async {
    if (_pickedImage == null) return;
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(_pickedImageBytes!, filename: _pickedImage!.name),
      });
      await _api.dio.post(
        '${_api.dio.options.baseUrl}${ApiConstants.adminFruits}/$fruitId/image',
        data: formData,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed, but fruit was saved.'), backgroundColor: AppTheme.warning),
        );
      }
    }
  }

  Future<void> _deleteImage() async {
    if (_savedFruitId == null && !_isEdit) return;
    final id = _savedFruitId ?? widget.fruitId!;
    try {
      await _api.delete('${ApiConstants.adminFruits}/$id/image');
      setState(() { _existingImageUrl = null; _pickedImage = null; _pickedImageBytes = null; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image removed'), backgroundColor: AppTheme.success),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final baseUrl = _api.dio.options.baseUrl.replaceAll('/api/v1', '');
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Fruit' : 'Add Fruit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: (_saving || _uploadingImage || _loading) ? null : _save,
            child: _saving || _uploadingImage
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen))
                : Text('Save', style: GoogleFonts.inter(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              width: 140, height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 2),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _pickedImageBytes != null
                                    ? kIsWeb 
                                        ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                                        : Image.file(File(_pickedImage!.path), fit: BoxFit.cover)
                                    : _existingImageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: '$baseUrl$_existingImageUrl', fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) => _imagePlaceholder(),
                                          )
                                        : _imagePlaceholder(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickImage,
                                icon: const Icon(Icons.photo_library_rounded, size: 16),
                                label: Text(_existingImageUrl != null || _pickedImage != null ? 'Replace' : 'Upload Image',
                                    style: GoogleFonts.inter(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  side: const BorderSide(color: AppTheme.primaryGreen),
                                ),
                              ),
                              if (_existingImageUrl != null || _pickedImage != null) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    if (_pickedImage != null) setState(() { _pickedImage = null; _pickedImageBytes = null; });
                                    else _deleteImage();
                                  },
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                                  label: Text('Remove', style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    side: const BorderSide(color: AppTheme.error),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_uploadingImage)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
                                const SizedBox(width: 8),
                                Text('Uploading image...', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                              ]),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Form fields
                    _formCard(children: [
                      _label('Fruit Name *'),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: _inputDecoration('e.g. Apple'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Description'),
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration('Brief description (optional)'),
                      ),
                      const SizedBox(height: 16),
                      _label('Price per KG (₹) *'),
                      TextFormField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputDecoration('e.g. 120'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Price is required';
                          final d = double.tryParse(v.trim());
                          if (d == null || d <= 0) return 'Enter a valid price greater than 0';
                          return null;
                        },
                      ),
                    ]),

                    const SizedBox(height: 16),

                    _formCard(children: [
                      _label('Availability Status'),
                      const SizedBox(height: 8),
                      ...[
                        ('in_stock', 'In Stock', AppTheme.success),
                        ('out_of_stock', 'Out of Stock', AppTheme.error),
                        ('temporarily_unavailable', 'Temporarily Unavailable', AppTheme.warning),
                      ].map((opt) => RadioListTile<String>(
                        value: opt.$1,
                        groupValue: _availability,
                        title: Text(opt.$2, style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14)),
                        activeColor: opt.$3,
                        dense: true,
                        onChanged: (v) => setState(() => _availability = v!),
                      )),
                    ]),

                    const SizedBox(height: 16),

                    _formCard(children: [
                      SwitchListTile(
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        title: Text('Active', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _isActive ? 'Visible to customers' : 'Hidden from customers',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        activeColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ]),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
                      ),
                    ],

                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: (_saving || _uploadingImage) ? null : _save,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                      child: _saving || _uploadingImage
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isEdit ? 'Update Fruit' : 'Add Fruit',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _imagePlaceholder() => Container(
    color: AppTheme.scaffoldBg,
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_photo_alternate_rounded, size: 40, color: AppTheme.textLight),
      const SizedBox(height: 4),
      Text('Tap to upload', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textLight)),
    ]),
  );

  Widget _formCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: AppTheme.scaffoldBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryGreen)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.error)),
  );
}
