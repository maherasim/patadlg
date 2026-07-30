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

/// Every ADLG across the DDLG's district's tehsils — view only.
class DdlgAdlgsScreen extends StatefulWidget {
  const DdlgAdlgsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgAdlgsScreen> createState() => _DdlgAdlgsScreenState();
}

class _DdlgAdlgsScreenState extends State<DdlgAdlgsScreen> {
  bool _loading = true;
  String? _error;
  List<DirectoryUser> _adlgs = [];
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
      final adlgs = await DirectoryService.instance.adlgsForDdlg();
      if (!mounted) return;
      setState(() {
        _adlgs = adlgs..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load ADLGs.";
        _loading = false;
      });
    }
  }

  List<DirectoryUser> get _filtered {
    if (_search.trim().isEmpty) return _adlgs;
    final q = _search.toLowerCase();
    return _adlgs.where((a) => a.name.toLowerCase().contains(q) || a.username.toLowerCase().contains(q) || (a.adlgProfile?.tehsil ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DirectoryService.instance.exportAdlgs();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'ADLGs Export'));
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
        title: const Text('ADLGs'),
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
      drawer: AppDrawer(role: 'ddlg', currentKey: 'adlgs', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text("Every ADLG across your district's tehsils — view only", style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search name, username, tehsil…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No ADLGs match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map(_tile),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(DirectoryUser a) {
    final profile = a.adlgProfile;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.groups_outlined, size: 18, color: AppColors.primary500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () => Clipboard.setData(ClipboardData(text: a.username)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('@${a.username}', style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                      const SizedBox(width: 3),
                      const Icon(Icons.copy_rounded, size: 11, color: AppColors.inkFaint),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(profile?.tehsil ?? '—', style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                    if (profile?.grade != null && profile!.grade!.isNotEmpty) ...[
                      const Text('·', style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                      Text(profile.grade!, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                    ],
                    if (a.phone != null && a.phone!.isNotEmpty) ...[
                      const Text('·', style: TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                      Text(a.phone!, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (a.active ? AppColors.success : AppColors.danger).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              a.active ? 'Active' : 'Inactive',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: a.active ? AppColors.success : AppColors.danger),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
