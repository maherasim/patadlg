import 'package:flutter/material.dart';

import '../../models/directory_user.dart';
import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pk_formatters.dart';

/// ADLG-only — create or edit a Secretary account. Password fields only show
/// on create (matches the web app — editing never touches the password; use
/// the separate Reset Password sheet for that).
class SecretaryFormSheet extends StatefulWidget {
  const SecretaryFormSheet({super.key, this.existing});

  final DirectoryUser? existing;

  @override
  State<SecretaryFormSheet> createState() => _SecretaryFormSheetState();
}

class _SecretaryFormSheetState extends State<SecretaryFormSheet> {
  late final _nameController = TextEditingController(text: widget.existing?.name ?? '');
  late final _fatherNameController = TextEditingController(text: widget.existing?.secretaryProfile?.fatherName ?? '');
  late final _usernameController = TextEditingController(text: widget.existing?.username ?? '');
  late final _emailController = TextEditingController(text: widget.existing?.email ?? '');
  late final _cnicController = TextEditingController(text: widget.existing?.cnic ?? '');
  late final _phoneController = TextEditingController(text: widget.existing?.phone ?? '');
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _loadingUcs = true;
  List<UnionCouncil> _ucs = [];
  int? _selectedUcId;

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _selectedUcId = widget.existing?.secretaryProfile?.unionCouncilId;
    _loadUcs();
  }

  Future<void> _loadUcs() async {
    try {
      final ucs = await DirectoryService.instance.unionCouncilsForAdlg();
      if (!mounted) return;
      setState(() {
        _ucs = ucs..sort((a, b) => a.name.compareTo(b.name));
        _loadingUcs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUcs = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedUcId == null) {
      setState(() => _error = 'Please select a union council.');
      return;
    }
    if (_nameController.text.trim().isEmpty || _usernameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a name and username.');
      return;
    }
    if (!_isEdit) {
      if (_passwordController.text.length < 6) {
        setState(() => _error = 'Password must be at least 6 characters.');
        return;
      }
      if (_passwordController.text != _passwordConfirmController.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = _isEdit
        ? await DirectoryService.instance.updateSecretary(
            id: widget.existing!.id,
            unionCouncilId: _selectedUcId!,
            name: _nameController.text.trim(),
            fatherName: _fatherNameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            cnic: _cnicController.text.trim(),
            phone: _phoneController.text.trim(),
          )
        : await DirectoryService.instance.createSecretary(
            unionCouncilId: _selectedUcId!,
            name: _nameController.text.trim(),
            fatherName: _fatherNameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            cnic: _cnicController.text.trim(),
            phone: _phoneController.text.trim(),
          );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(_isEdit ? 'Edit Secretary' : 'New Secretary', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 18),
              _label('Union Council'),
              _loadingUcs
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
                  : DropdownButtonFormField<int>(
                      initialValue: _selectedUcId,
                      isExpanded: true,
                      hint: const Text('Select union council'),
                      items: _ucs.map((uc) {
                        final suffix = (uc.secretary != null && uc.id != widget.existing?.secretaryProfile?.unionCouncilId) ? ' (currently: ${uc.secretary})' : '';
                        return DropdownMenuItem(value: uc.id, child: Text('${uc.name}$suffix', overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedUcId = v),
                    ),
              const SizedBox(height: 14),
              _label('Full Name'),
              TextField(controller: _nameController),
              const SizedBox(height: 14),
              _label("Father's Name (optional)"),
              TextField(controller: _fatherNameController),
              const SizedBox(height: 14),
              _label('Username'),
              TextField(controller: _usernameController, decoration: const InputDecoration(hintText: 'sec.uc45.burewala')),
              const SizedBox(height: 14),
              _label('Email (optional)'),
              TextField(controller: _emailController, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _label('CNIC (optional)'),
              TextField(controller: _cnicController, inputFormatters: [CnicInputFormatter()], keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '12345-1234567-1')),
              const SizedBox(height: 14),
              _label('Phone (optional)'),
              TextField(controller: _phoneController, inputFormatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: '0300-1234567')),
              if (!_isEdit) ...[
                const SizedBox(height: 14),
                _label('Password'),
                TextField(controller: _passwordController, obscureText: true),
                const SizedBox(height: 14),
                _label('Confirm Password'),
                TextField(controller: _passwordConfirmController, obscureText: true),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_isEdit ? 'Save Changes' : 'Create Secretary'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)));
}
