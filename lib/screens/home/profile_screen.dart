import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/app_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  XFile? _pickedAvatar;
  Uint8List? _pickedAvatarBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _displayNameController.text = auth.displayName;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }

    setState(() {
      _pickedAvatar = file;
      _pickedAvatarBytes = bytes;
    });
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.updateMyProfile(
      displayName: _displayNameController.text.trim(),
      avatar: _pickedAvatar,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    if (!ok) {
      final error = auth.error ?? 'Update profile failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                if (_pickedAvatarBytes != null)
                  CircleAvatar(
                    radius: 46,
                    backgroundImage: MemoryImage(_pickedAvatarBytes!),
                  )
                else
                  AppAvatar(
                    radius: 46,
                    name: auth.displayName,
                    url: auth.avatarUrl,
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    onPressed: _isSaving ? null : _pickAvatar,
                    icon: const Icon(Icons.photo_camera_outlined),
                    tooltip: 'Change avatar',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _displayNameController,
              enabled: !_isSaving,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'Enter your display name',
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) {
                  return 'Display name is required';
                }
                if (text.length > 60) {
                  return 'Display name is too long';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Username: ${auth.username ?? '-'}',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
