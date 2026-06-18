import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class AddProductScreen extends StatefulWidget {
  final String? productId; // If provided, it's edit mode
  const AddProductScreen({super.key, this.productId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _api = ApiClient();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isInitLoading = false;
  List<dynamic> _categories = [];
  
  // Form fields
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _discountPriceCtrl = TextEditingController();
  final _displayOrderCtrl = TextEditingController(text: '0');

  String? _selectedCategory;
  String _status = 'draft';
  String _availability = 'available';
  bool _isFeatured = false;
  bool _isPopular = false;
  bool _isTodaySpecial = false;

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isInitLoading = true);
    try {
      final catRes = await _api.get(ApiConstants.categories, queryParameters: {'active_only': true});
      _categories = catRes.data is List ? catRes.data : [];

      if (widget.productId != null) {
        final prodRes = await _api.get('${ApiConstants.products}/${widget.productId}');
        final p = prodRes.data;
        _nameCtrl.text = p['name'] ?? '';
        _descCtrl.text = p['description'] ?? '';
        _priceCtrl.text = p['price']?.toString() ?? '';
        _discountPriceCtrl.text = p['discount_price']?.toString() ?? '';
        _displayOrderCtrl.text = p['display_order']?.toString() ?? '0';
        _selectedCategory = p['category_id'];
        _status = p['status'] ?? 'draft';
        _availability = p['availability'] ?? 'available';
        _isFeatured = p['is_featured'] == true;
        _isPopular = p['is_popular'] == true;
        _isTodaySpecial = p['is_today_special'] == true;
        _existingImageUrl = p['image_url'];
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() => _isInitLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields and select a category.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final slugStr = _nameCtrl.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      final uniqueSlug = '$slugStr-${DateTime.now().millisecondsSinceEpoch}';
      
      final payload = {
        'name': _nameCtrl.text,
        'slug': uniqueSlug,
        'description': _descCtrl.text,
        'price': double.parse(_priceCtrl.text),
        'discount_price': _discountPriceCtrl.text.isNotEmpty ? double.parse(_discountPriceCtrl.text) : null,
        'category_id': _selectedCategory,
        'status': _status,
        'availability': _availability,
        'display_order': int.tryParse(_displayOrderCtrl.text) ?? 0,
        'is_featured': _isFeatured,
        'is_popular': _isPopular,
        'is_today_special': _isTodaySpecial,
      };

      String productId = widget.productId ?? '';
      
      if (widget.productId == null) {
        final res = await _api.post(ApiConstants.products, data: payload);
        productId = res.data['id'];
      } else {
        await _api.put('${ApiConstants.products}/$productId', data: payload);
      }

      // Upload Image if selected
      if (_selectedImage != null && _selectedImageBytes != null) {
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(_selectedImageBytes!, filename: _selectedImage!.name),
        });
        await _api.post('${ApiConstants.products}/$productId/image', data: formData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product saved successfully!')));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save product: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.productId == null ? 'Add Product' : 'Edit Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Upload
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 140, height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
                      image: _selectedImageBytes != null
                          ? DecorationImage(image: MemoryImage(_selectedImageBytes!), fit: BoxFit.cover)
                          : _existingImageUrl != null
                              ? DecorationImage(image: NetworkImage('${ApiConstants.baseUrl}$_existingImageUrl'), fit: BoxFit.cover)
                              : null,
                    ),
                    child: _selectedImageBytes == null && _existingImageUrl == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Icon(Icons.add_a_photo, color: AppTheme.primaryGreen, size: 32), SizedBox(height: 8), Text('Add Photo')],
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              _buildSectionTitle('Basic Info'),
              _buildTextField('Product Name', _nameCtrl, isRequired: true),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem<String>(value: c['id'], child: Text(c['name']))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 16),
              _buildTextField('Description', _descCtrl, maxLines: 3),
              const SizedBox(height: 24),

              _buildSectionTitle('Pricing & Inventory'),
              Row(
                children: [
                  Expanded(child: _buildTextField('Price (₹)', _priceCtrl, isNumeric: true, isRequired: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Discount Price (₹)', _discountPriceCtrl, isNumeric: true)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(value: 'published', child: Text('Published')),
                        DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _availability,
                      decoration: const InputDecoration(labelText: 'Availability', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'available', child: Text('Available')),
                        DropdownMenuItem(value: 'out_of_stock', child: Text('Out Of Stock')),
                        DropdownMenuItem(value: 'temporarily_unavailable', child: Text('Temp Unavailable')),
                      ],
                      onChanged: (v) => setState(() => _availability = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Display Order (Sort)', _displayOrderCtrl, isNumeric: true),
              const SizedBox(height: 24),

              _buildSectionTitle('Marketing Badges'),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Featured Product'),
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                      activeColor: AppTheme.primaryGreen,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Popular Item'),
                      value: _isPopular,
                      onChanged: (v) => setState(() => _isPopular = v),
                      activeColor: AppTheme.primaryGreen,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text("Today's Special"),
                      value: _isTodaySpecial,
                      onChanged: (v) => setState(() => _isTodaySpecial = v),
                      activeColor: AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : _saveProduct,
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(widget.productId == null ? 'Create Product' : 'Save Changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {bool isNumeric = false, bool isRequired = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label + (isRequired ? ' *' : ''),
        border: const OutlineInputBorder(),
      ),
      validator: isRequired ? (v) => v!.isEmpty ? 'Required field' : null : null,
    );
  }
}
