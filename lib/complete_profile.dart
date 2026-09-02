import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home.dart';

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  static const navy = Color(0xFF3472CA);
  static const deepBlue = Color(0xFF2458A8);
  static const ice = Color(0xFFEAF4F8);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedGender;
  String _selectedLanguage = 'EN';
  Uint8List? _profileImageBytes;
  String? _profileImageExtension;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      final extension = image.name.split('.').last.toLowerCase();
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

      if (!allowedExtensions.contains(extension)) {
        _showError('Please select a JPG, PNG, or WebP image.');
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) return;
      setState(() {
        _profileImageBytes = bytes;
        _profileImageExtension = extension;
      });
    } catch (error) {
      _showError('Unable to select image: $error');
    }
  }

  Future<String?> _uploadProfileImage(String authUserId) async {
    final bytes = _profileImageBytes;
    final extension = _profileImageExtension;

    if (bytes == null || extension == null) return null;

    final storagePath = '$authUserId/avatar.$extension';
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    await Supabase.instance.client.storage
        .from('profile-pictures')
        .uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType,
      ),
    );

    return Supabase.instance.client.storage
        .from('profile-pictures')
        .getPublicUrl(storagePath);
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      _showError('Please log in before completing your profile.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profileUrl = await _uploadProfileImage(authUser.id);

      await Supabase.instance.client.from('users').insert({
        'auth_id': authUser.id,
        'name': _nameController.text.trim(),
        'gender': _selectedGender,
        'email': authUser.email,
        'phone_num': _phoneController.text.trim(),
        'language': _selectedLanguage,
        'profile': profileUrl,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile completed successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
      );
    } on PostgrestException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Unable to save profile: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Complete your profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tell us a little more before continuing',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      _buildLabel('Profile Picture (Optional)'),
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: ice,
                              backgroundImage: _profileImageBytes == null
                                  ? null
                                  : MemoryImage(_profileImageBytes!),
                              child: _profileImageBytes == null
                                  ? const Icon(
                                Icons.person_outline,
                                size: 48,
                                color: navy,
                              )
                                  : null,
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _pickProfileImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(
                                _profileImageBytes == null
                                    ? 'Choose Picture'
                                    : 'Change Picture',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: navy,
                                side: const BorderSide(color: navy),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Full Name'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _fieldDecoration(
                          hint: 'Your full name',
                          icon: Icons.person_outline,
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Gender'),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: _fieldDecoration(
                          hint: 'Select your gender',
                          icon: Icons.wc_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Male')),
                          DropdownMenuItem(value: 'F', child: Text('Female')),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) =>
                            setState(() => _selectedGender = value),
                        validator: (value) =>
                        value == null ? 'Gender is required' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Phone Number'),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDecoration(
                          hint: '01XXXXXXXXX',
                          icon: Icons.phone_outlined,
                        ),
                        validator: (value) {
                          final phone = value?.trim() ?? '';
                          if (phone.isEmpty) return 'Phone number is required';
                          if (phone.length > 11) {
                            return 'Phone number cannot exceed 11 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Language'),
                      DropdownButtonFormField<String>(
                        value: _selectedLanguage,
                        decoration: _fieldDecoration(
                          hint: 'Select language',
                          icon: Icons.language_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'EN', child: Text('English')),
                          DropdownMenuItem(
                            value: 'BM',
                            child: Text('Bahasa Melayu'),
                          ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                          if (value != null) {
                            setState(() => _selectedLanguage = value);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : const Text(
                            'Save and Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navy, deepBlue],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: ice, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.person_add_alt_1, color: navy, size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'FerryLink Penang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
          color: navy,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
      prefixIcon: Icon(icon, size: 20, color: navy),
      filled: true,
      fillColor: ice,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}