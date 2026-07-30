import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

/// Every tehsil in the DDLG's district — view only.
class DdlgTehsilsScreen extends StatefulWidget {
  const DdlgTehsilsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgTehsilsScreen> createState() => _DdlgTehsilsScreenState();
}

class _DdlgTehsilsScreenState extends State<DdlgTehsilsScreen> {
  bool _loading = true;
  String? _error;
  List<Tehsil> _tehsils = [];
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
      final tehsils = await DirectoryService.instance.tehsilsForDdlg();
      if (!mounted) return;
      setState(() {
        _tehsils = tehsils..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load tehsils.";
        _loading = false;
      });
    }
  }

  List<Tehsil> get _filtered {
    if (_search.trim().isEmpty) return _tehsils;
    final q = _search.toLowerCase();
    return _tehsils.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DirectoryService.instance.exportTehsils();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Tehsils Export'));
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
        title: const Text('Tehsils'),
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
      drawer: AppDrawer(role: 'ddlg', currentKey: 'tehsils', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('Every tehsil in your district — view only', style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search tehsil…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No tehsils match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map(_tile),
                    ],
                  ),
                ),
    );
  }

  Widget _tile(Tehsil t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.map_outlined, size: 18, color: AppColors.primary500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text('${t.district ?? ''} · ${t.unionCouncilsCount ?? 0} UCs', style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: (t.adlgActivated ? AppColors.success : AppColors.warning).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(
              t.adlgActivated ? 'Assigned' : 'Vacant',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: t.adlgActivated ? AppColors.success : AppColors.warning),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
