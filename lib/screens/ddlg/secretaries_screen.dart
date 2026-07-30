import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/directory_user.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

/// Every UC secretary across the DDLG's district — view only.
class DdlgSecretariesScreen extends StatefulWidget {
  const DdlgSecretariesScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgSecretariesScreen> createState() => _DdlgSecretariesScreenState();
}

class _DdlgSecretariesScreenState extends State<DdlgSecretariesScreen> {
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
      final secretaries = await DirectoryService.instance.secretariesForDdlg();
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
          (s.secretaryProfile?.tehsil ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DirectoryService.instance.exportSecretaries(role: 'ddlg');
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
      drawer: AppDrawer(role: 'ddlg', currentKey: 'secretaries', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('Every UC secretary across your district — view only', style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search name, username, UC, tehsil…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No secretaries match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map(_tile),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(DirectoryUser s) {
    final profile = s.secretaryProfile;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: s.username)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('@${s.username}', style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                      const SizedBox(width: 3),
                      const Icon(Icons.copy_rounded, size: 11, color: AppColors.inkFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile?.tehsil ?? '—'} · ${profile?.unionCouncil ?? '—'}',
                  style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (s.phone != null && s.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(s.phone!, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (s.active ? AppColors.success : AppColors.danger).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              s.active ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: s.active ? AppColors.success : AppColors.danger),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
