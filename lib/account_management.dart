import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login.dart';

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
  final _dateOfBirthController = TextEditingController();
  final _imagePicker = ImagePicker();

  String? _selectedGender;
  DateTime? _selectedDateOfBirth;
  String? _profileUrl;
  Uint8List? _newImageBytes;
  String? _newImageExtension;

  String _originalName = '';
  String _originalEmail = '';
  String _originalPhone = '';
  String? _originalGender;
  DateTime? _originalDateOfBirth;

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
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('No user is currently logged in');

      final userData = await Supabase.instance.client
          .from('users')
          .select('name, email, phone_num, gender, profile, date_of_birth')
          .eq('auth_id', authUser.id)
          .maybeSingle();

      if (userData == null) throw Exception('User profile was not found');

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
        _selectedDateOfBirth = userData['date_of_birth'] == null
            ? null
            : DateTime.tryParse(userData['date_of_birth'].toString());
        _dateOfBirthController.text = _selectedDateOfBirth == null
            ? ''
            : _formatDate(_selectedDateOfBirth!);
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
    _originalDateOfBirth = _selectedDateOfBirth;
  }

  void _cancelEditing() {
    _formKey.currentState?.reset();
    setState(() {
      _nameController.text = _originalName;
      _emailController.text = _originalEmail;
      _phoneController.text = _originalPhone;
      _selectedGender = _originalGender;
      _selectedDateOfBirth = _originalDateOfBirth;
      _dateOfBirthController.text = _originalDateOfBirth == null
          ? ''
          : _formatDate(_originalDateOfBirth!);
      _newImageBytes = null;
      _newImageExtension = null;
      _isEditing = false;
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDateOfBirth() async {
    if (!_isEditing) return;
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedDateOfBirth = selected;
      _dateOfBirthController.text = _formatDate(selected);
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
      final newPhone = _phoneController.text.trim();

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'name': newName,
            'phone_num': newPhone,
            'gender': _selectedGender,
            'date_of_birth': _selectedDateOfBirth?.toIso8601String().split('T').first,
          },
        ),
      );

      final newProfileUrl = await _uploadProfileImage(authUser.id);

      await Supabase.instance.client.from('users').update({
        'name': newName,
        'phone_num': newPhone,
        'gender': _selectedGender,
        'date_of_birth': _selectedDateOfBirth?.toIso8601String().split('T').first,
        'profile': newProfileUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('auth_id', authUser.id);

      if (!mounted) return;
      setState(() {
        _profileUrl = newProfileUrl;
        _nameController.text = newName;
        _phoneController.text = newPhone;
        _newImageBytes = null;
        _newImageExtension = null;
        _isEditing = false;
        _rememberOriginalValues();
      });

      _showMessage('Profile updated successfully');
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

  Future<void> _changePassword() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    final currentEmail = authUser?.email;
    if (authUser == null || currentEmail == null) {
      _showMessage('No email account is currently logged in', isError: true);
      return;
    }

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change Password'),
        content: Text(
          'A 6-digit password reset code will be sent to $currentEmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send Code'),
          ),
        ],
      ),
    );

    if (shouldSend != true) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        currentEmail,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecoveryOtpPage(
            email: currentEmail,
            fromProfileManagement: true,
          ),
        ),
      );
      _showMessage('Password reset code sent to $currentEmail');
    } on AuthException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your account and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isSaving = true);

    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('No user is currently logged in');

      final profileFiles = await Supabase.instance.client.storage
          .from('profile-pictures')
          .list(path: authUser.id);
      if (profileFiles.isNotEmpty) {
        await Supabase.instance.client.storage
            .from('profile-pictures')
            .remove(
          profileFiles
              .map((file) => '${authUser.id}/${file.name}')
              .toList(),
        );
      }

      await Supabase.instance.client.rpc('delete_own_account');
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } on PostgrestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      _showMessage('Unable to delete account: $error', isError: true);
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
                  enabled: false,
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: _fieldDecoration(Icons.phone_outlined),
                  validator: (value) {
                    final phone = value?.trim() ?? '';
                    if (phone.isEmpty) return 'Phone number is required';
                    return !RegExp(r'^01\d{8,9}$').hasMatch(phone)
                        ? 'Enter a valid Malaysian phone number'
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
                const SizedBox(height: 16),
                _buildLabel('Date of Birth'),
                TextFormField(
                  controller: _dateOfBirthController,
                  enabled: _isEditing,
                  readOnly: true,
                  onTap: _isEditing ? _pickDateOfBirth : null,
                  decoration: _fieldDecoration(
                    Icons.cake_outlined,
                    suffix: const Icon(Icons.calendar_month_outlined),
                  ),
                  validator: (_) => _selectedDateOfBirth == null
                      ? 'Date of birth is required'
                      : null,
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
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving || _isEditing ? null : _changePassword,
            icon: const Icon(Icons.lock_reset_outlined),
            label: const Text('Change Password'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _isSaving || _isEditing ? null : _deleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Account'),
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
