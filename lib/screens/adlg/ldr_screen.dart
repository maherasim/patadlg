import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/death_case.dart';
import '../../services/death_case_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../ldr_detail_screen.dart';

const _kStatusOptions = [
  (null, 'All Statuses'),
  ('FORWARDED', 'Forwarded'),
  ('PENDING_DDLG_APPROVAL', 'Pending DDLG Approval'),
  ('APPROVED', 'Approved'),
  ('REJECTED', 'Rejected'),
  ('RETURNED', 'Returned'),
  ('REGISTERED', 'Registered'),
];

const Map<String, Color> _kStatusTone = {
  'FORWARDED': AppColors.info,
  'PENDING_DDLG_APPROVAL': AppColors.info,
  'APPROVED': AppColors.success,
  'REJECTED': AppColors.danger,
  'RETURNED': AppColors.warning,
  'REGISTERED': AppColors.success,
};

class AdlgLdrScreen extends StatefulWidget {
  const AdlgLdrScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgLdrScreen> createState() => _AdlgLdrScreenState();
}

class _AdlgLdrScreenState extends State<AdlgLdrScreen> {
  bool _loading = true;
  String? _error;
  List<DeathCase> _cases = [];
  String _search = '';
  String? _statusFilter;
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
      final cases = await DeathCaseService.instance.indexForAdlg(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load death registration cases.";
        _loading = false;
      });
    }
  }

  List<DeathCase> get _filtered {
    if (_search.trim().isEmpty) return _cases;
    final q = _search.toLowerCase();
    return _cases.where((c) => c.deathId.toLowerCase().contains(q) || c.deceasedName.toLowerCase().contains(q) || (c.unionCouncil ?? '').toLowerCase().contains(q)).toList();
  }

  Future<void> _openDetail(DeathCase c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LdrDetailScreen(role: 'adlg', caseId: c.id, user: widget.user)));
    _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await DeathCaseService.instance.exportCases(role: 'adlg', status: _statusFilter);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Death Registration Export'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't generate the export. Please try again.")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _cases.where((c) => c.status == 'FORWARDED').length;

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Death Registration'),
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
      drawer: AppDrawer(role: 'adlg', currentKey: 'ldr', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      if (pending > 0)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.accent100, borderRadius: BorderRadius.circular(14)),
                          child: Text('$pending awaiting review', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent600)),
                        ),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search LDR-ID, deceased, UC…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _statusFilter,
                        isExpanded: true,
                        items: _kStatusOptions.map((opt) => DropdownMenuItem(value: opt.$1, child: Text(opt.$2))).toList(),
                        onChanged: (v) {
                          setState(() => _statusFilter = v);
                          _load();
                        },
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No cases match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map((c) => _LdrTile(deathCase: c, onTap: () => _openDetail(c))),
                    ],
                  ),
                ),
    );
  }
}

class _LdrTile extends StatelessWidget {
  const _LdrTile({required this.deathCase, required this.onTap});

  final DeathCase deathCase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _kStatusTone[deathCase.status] ?? AppColors.inkMuted;
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
                child: const Center(child: Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary500)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deathCase.deathId, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(deathCase.deceasedName, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (deathCase.unionCouncil != null) ...[
                      const SizedBox(height: 2),
                      Text(deathCase.unionCouncil!, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(deathCase.statusLabel, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
                  ),
                  const SizedBox(height: 4),
                  Text(deathCase.categoryLabel, style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint)),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
