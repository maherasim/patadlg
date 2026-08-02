import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/location_tracking_service.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';
import 'login_screen.dart';

/// Settings — shared across all three roles (mirrors sec/adlg/ddlg
/// Profile.jsx, which only differ in role label and which profile fields
/// they show). Avatar upload, self-service change password, sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.role, required this.user});

  final String role;
  final Map<String, dynamic> user;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _user = widget.user;
  bool _uploadingAvatar = false;

  String get _roleLabel {
    if (widget.role == 'adlg') return 'Assistant Director Local Government';
    if (widget.role == 'ddlg') return 'Deputy Director Local Government';
    return 'Secretary Union Council';
  }

  Map? get _profile {
    if (widget.role == 'adlg') return _user['adlg_profile'] as Map?;
    if (widget.role == 'ddlg') return _user['ddlg_profile'] as Map?;
    return _user['secretary_profile'] as Map?;
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    final result = await ProfileService.instance.uploadAvatar(File(picked.path));
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (result.isSuccess && result.user != null) {
      setState(() => _user = result.user!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorMessage ?? "Couldn't upload photo.")));
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text("You'll need to sign in again to continue."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign Out')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await LocationTrackingService.instance.stop();
    await NotificationService.instance.unregisterToken();
    await AuthService.instance.logout();

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [NotificationBell(), LogoutAction()],
      ),
      drawer: AppDrawer(role: widget.role, currentKey: 'profile', user: widget.user),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _ProfileCard(
            role: widget.role,
            user: _user,
            profile: _profile,
            roleLabel: _roleLabel,
            uploadingAvatar: _uploadingAvatar,
            onPickAvatar: _pickAvatar,
            onLogout: _handleLogout,
          ),
          const SizedBox(height: 16),
          const _ChangePasswordCard(),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.role,
    required this.user,
    required this.profile,
    required this.roleLabel,
    required this.uploadingAvatar,
    required this.onPickAvatar,
    required this.onLogout,
  });

  final String role;
  final Map<String, dynamic> user;
  final Map? profile;
  final String roleLabel;
  final bool uploadingAvatar;
  final VoidCallback onPickAvatar;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user['avatar_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: uploadingAvatar ? null : onPickAvatar,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary50,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 30, color: AppColors.primary500) : null,
                    ),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle),
                      child: uploadingAvatar
                          ? const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user['name'] as String? ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(roleLabel, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 4),
          if (role == 'adlg') _row('Tehsil', profile?['tehsil'] as String?),
          if (role == 'ddlg') _row('District', profile?['district'] as String?),
          if (role == 'sec') _row('Union Council', profile?['union_council'] as String?),
          if (role == 'adlg' || role == 'ddlg') _row('Grade', profile?['grade'] as String?),
          _row('Email', user['email'] as String?),
          _row('Username', user['username'] as String?),
          _row('Phone', user['phone'] as String?),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
              child: const Text('Sign Out'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
          Flexible(
            child: Text(
              (value == null || value.isEmpty) ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordCard extends StatefulWidget {
  const _ChangePasswordCard();

  @override
  State<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends State<_ChangePasswordCard> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_currentController.text.isEmpty) {
      setState(() => _error = 'Enter your current password.');
      return;
    }
    if (_newController.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _success = false;
    });

    final result = await ProfileService.instance.changePassword(
      currentPassword: _currentController.text,
      password: _newController.text,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    _currentController.clear();
    _newController.clear();
    _confirmController.clear();
    setState(() {
      _submitting = false;
      _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Change Password', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 14),
          _label('Current Password'),
          _passwordField(_currentController, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
          const SizedBox(height: 12),
          _label('New Password'),
          _passwordField(_newController, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 12),
          _label('Confirm New Password'),
          _passwordField(_confirmController, _obscureConfirm, () => setState(() => _obscureConfirm = !_obscureConfirm)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
          if (_success) ...[
            const SizedBox(height: 12),
            const Text('✅ Password updated.', style: TextStyle(color: AppColors.success, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Update Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
      );

  Widget _passwordField(TextEditingController controller, bool obscure, VoidCallback onToggle) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20, color: AppColors.inkMuted),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
