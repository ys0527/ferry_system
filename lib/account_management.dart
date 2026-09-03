import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementState();
}

class _AccountManagementState extends State<AccountManagementPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedGender;
  String? _profileUrl;
  Uint8List? _newImageBytes;
  String? _newImageExtension;

  String _originalName = '';
  String _originalEmail = '';
  String _originalPhone = '';
  String? _originalGender;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  bool _isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('No user is currently logged in');

      final userData = await Supabase.instance.client
          .from('users')
          .select('name, email, phone_num, gender, profile')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (userData == null) throw Exception('User profile was not found');

      // Only a confirmed Supabase Auth email is copied into public.users.
      final authenticatedEmail = authUser.email ?? userData['email'] ?? '';
      if (authenticatedEmail.isNotEmpty &&
          userData['email'] != authenticatedEmail) {
        await Supabase.instance.client
            .from('users')
            .update({'email': authenticatedEmail})
            .eq('auth_id', authUser.id);
      }

      if (!mounted) return;
      setState(() {
        _nameController.text = userData['name'] ?? '';
        _emailController.text = authenticatedEmail;
        _phoneController.text = userData['phone_num'] ?? '';
        _selectedGender = userData['gender'];
        _profileUrl = userData['profile'];
        _isEmailVerified = authUser.emailConfirmedAt != null;
        _rememberOriginalValues();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Unable to load profile: $error', isError: true);
    }
  }

  void _rememberOriginalValues() {
    _originalName = _nameController.text;
    _originalEmail = _emailController.text;
    _originalPhone = _phoneController.text;
    _originalGender = _selectedGender;
  }

  void _cancelEditing() {
    setState(() {
      _nameController.text = _originalName;
      _emailController.text = _originalEmail;
      _phoneController.text = _originalPhone;
      _selectedGender = _originalGender;
      _newImageBytes = null;
      _newImageExtension = null;
      _isEditing = false;
    });
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
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        _showMessage('Select a JPG, PNG, or WebP image.', isError: true);
        return;
      }

      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newImageBytes = bytes;
        _newImageExtension = extension;
      });
    } catch (error) {
      _showMessage('Unable to select image: $error', isError: true);
    }
  }

  Future<String?> _uploadProfileImage(String authUserId) async {
    if (_newImageBytes == null || _newImageExtension == null) {
      return _profileUrl;
    }

    final extension = _newImageExtension!;
    final storagePath = '$authUserId/avatar.$extension';
    final contentType = extension == 'png'
        ? 'image/png'
        : extension == 'webp'
        ? 'image/webp'
        : 'image/jpeg';

    await Supabase.instance.client.storage
        .from('profile-pictures')
        .uploadBinary(
      storagePath,
      _newImageBytes!,
      fileOptions: FileOptions(
        upsert: true,
        contentType: contentType,
      ),
    );

    return Supabase.instance.client.storage
        .from('profile-pictures')
        .getPublicUrl(storagePath);
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      _showMessage('No user is currently logged in', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final newName = _nameController.text.trim();
      final newEmail = _emailController.text.trim().toLowerCase();
      final newPhone = _phoneController.text.trim();
      final emailChanged = newEmail != (authUser.email?.toLowerCase() ?? '');

      final authResponse = await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          email: emailChanged ? newEmail : null,
          data: {
            'name': newName,
            'phone_num': newPhone,
            'gender': _selectedGender,
          },
        ),
      );

      // While email confirmation is pending, this remains the old email.
      final confirmedEmail = authResponse.user?.email ?? authUser.email;
      final newProfileUrl = await _uploadProfileImage(authUser.id);

      await Supabase.instance.client.from('users').update({
        'name': newName,
        'email': confirmedEmail,
        'phone_num': newPhone,
        'gender': _selectedGender,
        'profile': newProfileUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('auth_id', authUser.id);

      if (!mounted) return;
      setState(() {
        _profileUrl = newProfileUrl;
        _nameController.text = newName;
        _emailController.text = confirmedEmail ?? newEmail;
        _phoneController.text = newPhone;
        _newImageBytes = null;
        _newImageExtension = null;
        _isEditing = false;
        _rememberOriginalValues();
      });

      if (emailChanged && confirmedEmail?.toLowerCase() != newEmail) {
        _showMessage(
          'Other changes saved. Verify $newEmail using the email sent by Supabase.',
        );
      } else {
        _showMessage('Profile updated successfully');
      }
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } on StorageException catch (error) {
      _showMessage(error.message, isError: true);
    } on PostgrestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Unable to update profile: $error', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : teal,
      ),
    );
  }

  ImageProvider<Object>? _profileImageProvider() {
    if (_newImageBytes != null) return MemoryImage(_newImageBytes!);
    if (_profileUrl != null && _profileUrl!.trim().isNotEmpty) {
      return NetworkImage(_profileUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _profileImageProvider();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Account Management'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: navy))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _isEditing ? _pickProfileImage : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: navy,
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 48,
                    )
                        : null,
                  ),
                  if (_isEditing)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: _isEditing
                ? OutlinedButton.icon(
              onPressed: _pickProfileImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Change Picture'),
            )
                : ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Full Name'),
                TextFormField(
                  controller: _nameController,
                  enabled: _isEditing,
                  decoration: _fieldDecoration(Icons.person_outline),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                _buildLabel('Email'),
                TextFormField(
                  controller: _emailController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration(
                    Icons.email_outlined,
                    suffix: Icon(
                      _isEmailVerified ? Icons.verified : Icons.warning_amber,
                      color: _isEmailVerified ? Colors.green : Colors.orange,
                    ),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Email is required';
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                        .hasMatch(email)
                        ? null
                        : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 16),
                _buildLabel('Phone Number'),
                TextFormField(
                  controller: _phoneController,
                  enabled: _isEditing,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration(Icons.phone_outlined),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Phone number is required';
                    return phone.length > 11
                        ? 'Phone number cannot exceed 11 characters'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                _buildLabel('Gender'),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: _fieldDecoration(Icons.wc_outlined),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Male')),
                    DropdownMenuItem(value: 'F', child: Text('Female')),
                  ],
                  onChanged: !_isEditing
                      ? null
                      : (value) => setState(() => _selectedGender = value),
                  validator: (value) =>
                  value == null ? 'Gender is required' : null,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : _cancelEditing,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                              : const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
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

  InputDecoration _fieldDecoration(IconData icon, {Widget? suffix}) {
    return InputDecoration(
      prefixIcon: Icon(icon, size: 20, color: navy),
      suffixIcon: suffix,
      filled: true,
      fillColor: ice,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
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