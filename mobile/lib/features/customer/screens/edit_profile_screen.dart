import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  String? _gender;
  String? _profilePhotoUrl;
  String? _photoBase64;
  File? _selectedImageFile;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get(ApiConstants.userProfile);
      final data = res.data;
      setState(() {
        _nameController.text = data['full_name'] ?? '';
        _gender = data['gender'];
        _profilePhotoUrl = data['profile_photo_url'];
        if (data['dob'] != null) {
          final dobDateTime = DateTime.parse(data['dob']);
          _dobController.text = DateFormat('yyyy-MM-dd').format(dobDateTime);
        }
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load profile details'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image == null) return;

      final file = File(image.path);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Determine mime type from extension
      String mimeType = 'image/png';
      if (image.path.endsWith('.jpg') || image.path.endsWith('.jpeg')) {
        mimeType = 'image/jpeg';
      }

      setState(() {
        _selectedImageFile = file;
        _photoBase64 = 'data:$mimeType;base64,$base64String';
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'full_name': _nameController.text.trim(),
        'gender': _gender,
        'dob': _dobController.text.isNotEmpty ? _dobController.text : null,
      };

      if (_photoBase64 != null) {
        payload['photo_base64'] = _photoBase64;
      }

      await _api.put(ApiConstants.userProfile, data: payload);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppTheme.success),
        );
        context.pop(true); // Return true to indicate refresh needed
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save profile updates'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _selectedImageFile != null
        ? FileImage(_selectedImageFile!)
        : (_profilePhotoUrl != null
            ? NetworkImage(Uri.parse(_api.dio.options.baseUrl).replace(path: _profilePhotoUrl!).toString())
            : null) as ImageProvider?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Photo Editor
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: AppTheme.accentLight.withValues(alpha: 0.3),
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? const Icon(Icons.person, size: 60, color: AppTheme.primaryGreen)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _selectImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primaryGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Full Name Input
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: const Icon(Icons.wc_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      items: ['male', 'female', 'other'].map((g) {
                        return DropdownMenuItem(
                          value: g,
                          child: Text(g[0].toUpperCase() + g.substring(1)),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _gender = val),
                    ),
                    const SizedBox(height: 20),

                    // DOB Date Picker
                    TextFormField(
                      controller: _dobController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth (Optional)',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      onTap: () async {
                        final parsedDate = _dobController.text.isNotEmpty
                            ? DateTime.tryParse(_dobController.text)
                            : null;
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: parsedDate ?? DateTime.now().subtract(const Duration(days: 6570)), // Default 18 years ago
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primaryGreen,
                                  onPrimary: Colors.white,
                                  onSurface: AppTheme.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (selected != null) {
                          setState(() {
                            _dobController.text = DateFormat('yyyy-MM-dd').format(selected);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 40),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Save Profile',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
