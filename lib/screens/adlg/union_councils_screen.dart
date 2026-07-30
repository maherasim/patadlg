import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/directory/union_council_form_sheet.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

class AdlgUnionCouncilsScreen extends StatefulWidget {
  const AdlgUnionCouncilsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgUnionCouncilsScreen> createState() => _AdlgUnionCouncilsScreenState();
}

class _AdlgUnionCouncilsScreenState extends State<AdlgUnionCouncilsScreen> {
  bool _loading = true;
  String? _error;
  List<UnionCouncil> _ucs = [];
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
      final ucs = await DirectoryService.instance.unionCouncilsForAdlg();
      if (!mounted) return;
      setState(() {
        _ucs = ucs..sort((a, b) => a.name.compareTo(b.name));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load union councils.";
        _loading = false;
      });
    }
  }

  List<UnionCouncil> get _filtered {
    if (_search.trim().isEmpty) return _ucs;
    final q = _search.toLowerCase();
    return _ucs.where((u) => u.name.toLowerCase().contains(q) || (u.code ?? '').toLowerCase().contains(q) || (u.secretary ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<UnionCouncil>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UnionCouncilFormSheet(),
    );
    if (created != null) _load();
  }

  Future<void> _openEdit(UnionCouncil uc) async {
    final updated = await showModalBottomSheet<UnionCouncil>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UnionCouncilFormSheet(existing: uc),
    );
    if (updated != null) _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DirectoryService.instance.exportUnionCouncils(role: 'adlg');
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Union Councils Export'));
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
        title: const Text('Union Councils'),
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
      drawer: AppDrawer(role: 'adlg', currentKey: 'union-councils', user: widget.user),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openCreate, icon: const Icon(Icons.add_rounded), label: const Text('New UC')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
                    children: [
                      Text('${_ucs.length} union councils in your tehsil', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search name, code, secretary…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No union councils match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map((uc) => _UcTile(uc: uc, onTap: () => _openEdit(uc))),
                    ],
                  ),
                ),
    );
  }
}

class _UcTile extends StatelessWidget {
  const _UcTile({required this.uc, required this.onTap});

  final UnionCouncil uc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primary500.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.account_balance_rounded, size: 18, color: AppColors.primary500),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (uc.ucNo != null) ...[
                          Text('#${uc.ucNo}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkFaint)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(child: Text(uc.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (uc.isVacant)
                          _badge('Vacant', AppColors.warning)
                        else
                          Expanded(child: Text(uc.secretary!, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _badge(uc.hasGeofence ? 'Geofence · ${uc.geofenceRadius}m' : 'Geofence not set', uc.hasGeofence ? AppColors.success : AppColors.inkFaint),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
