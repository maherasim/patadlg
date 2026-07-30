import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/directory_user.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/directory/charges_sheet.dart';
import '../../widgets/directory/reset_password_sheet.dart';
import '../../widgets/directory/secretary_form_sheet.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

class AdlgSecretariesScreen extends StatefulWidget {
  const AdlgSecretariesScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgSecretariesScreen> createState() => _AdlgSecretariesScreenState();
}

class _AdlgSecretariesScreenState extends State<AdlgSecretariesScreen> {
  bool _loading = true;
  String? _error;
  List<DirectoryUser> _secretaries = [];
  String _search = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final secretaries = await DirectoryService.instance.secretariesForAdlg();
      if (!mounted) return;
      setState(() {
        _secretaries = secretaries..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load secretaries.";
        _loading = false;
      });
    }
  }

  List<DirectoryUser> get _filtered {
    if (_search.trim().isEmpty) return _secretaries;
    final q = _search.toLowerCase();
    return _secretaries.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.username.toLowerCase().contains(q) ||
          (s.secretaryProfile?.unionCouncil ?? '').toLowerCase().contains(q) ||
          (s.cnic ?? '').contains(q);
    }).toList();
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<DirectoryUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SecretaryFormSheet(),
    );
    if (created != null) _load();
  }

  Future<void> _openEdit(DirectoryUser s) async {
    final updated = await showModalBottomSheet<DirectoryUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SecretaryFormSheet(existing: s),
    );
    if (updated != null) _load();
  }

  Future<void> _openResetPassword(DirectoryUser s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ResetPasswordSheet(secretaryId: s.id, secretaryName: s.name),
    );
  }

  Future<void> _openCharges(DirectoryUser s) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChargesSheet(secretary: s),
    );
    _load();
  }

  Future<void> _confirmToggleActive(DirectoryUser s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.active ? 'Deactivate secretary?' : 'Reactivate secretary?'),
        content: Text(
          s.active
              ? '"${s.name}" will no longer be able to sign in. Their account and history are preserved and this can be reversed anytime.'
              : '"${s.name}" will be able to sign in again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s.active ? 'Deactivate' : 'Reactivate')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await DirectoryService.instance.toggleSecretaryActive(s.id);
    if (ok) _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DirectoryService.instance.exportSecretaries(role: 'adlg');
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Secretaries Export'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't generate the export. Please try again.")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Secretaries'),
        actions: [
          IconButton(
            onPressed: _exporting ? null : _export,
            icon: _exporting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Excel',
          ),
          const NotificationBell(),
          const LogoutAction(),
        ],
      ),
      drawer: AppDrawer(role: 'adlg', currentKey: 'secretaries', user: widget.user),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreate, icon: const Icon(Icons.add_rounded), label: const Text('New Secretary')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    children: [
                      Text('${_secretaries.length} secretaries in your tehsil', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search name, username, UC, CNIC…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No secretaries match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map((s) => _SecretaryTile(
                              secretary: s,
                              onEdit: () => _openEdit(s),
                              onResetPassword: () => _openResetPassword(s),
                              onCharges: () => _openCharges(s),
                              onToggleActive: () => _confirmToggleActive(s),
                            )),
                    ],
                  ),
                ),
    );
  }
}

class _SecretaryTile extends StatelessWidget {
  const _SecretaryTile({
    required this.secretary,
    required this.onEdit,
    required this.onResetPassword,
    required this.onCharges,
    required this.onToggleActive,
  });

  final DirectoryUser secretary;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onCharges;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final profile = secretary.secretaryProfile;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(secretary.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => Clipboard.setData(ClipboardData(text: secretary.username)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('@${secretary.username}', style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                          const SizedBox(width: 3),
                          const Icon(Icons.copy_rounded, size: 11, color: AppColors.inkFaint),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onToggleActive,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: (secretary.active ? AppColors.success : AppColors.danger).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    secretary.active ? 'Active' : 'Inactive',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: secretary.active ? AppColors.success : AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _infoChip(Icons.account_balance_rounded, profile?.unionCouncil ?? '—'),
              if (profile != null && !profile.geofenceSet) _infoChip(Icons.warning_amber_rounded, 'No geofence set', color: AppColors.warning),
              if (profile != null && profile.additionalCharges.isNotEmpty) _infoChip(Icons.add_business_rounded, '+${profile.additionalCharges.length} UC', color: AppColors.info),
              if (secretary.cnic != null && secretary.cnic!.isNotEmpty) _infoChip(Icons.badge_outlined, secretary.cnic!),
              if (secretary.phone != null && secretary.phone!.isNotEmpty) _infoChip(Icons.phone_outlined, secretary.phone!),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _actionIcon(Icons.badge_outlined, 'Charges', onCharges),
              const SizedBox(width: 6),
              _actionIcon(Icons.key_rounded, 'Reset Password', onResetPassword),
              const SizedBox(width: 6),
              _actionIcon(Icons.edit_outlined, 'Edit', onEdit),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _infoChip(IconData icon, String label, {Color? color}) {
    final c = color ?? AppColors.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(vertical: 8), textStyle: const TextStyle(fontSize: 11)),
        icon: Icon(icon, size: 14),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
