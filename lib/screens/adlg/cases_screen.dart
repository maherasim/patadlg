import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/dv_case.dart';
import '../../services/case_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/export_download.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../case_detail_screen.dart';

const _kStatusOptions = [
  (null, 'All Statuses'),
  ('SUBMITTED', 'Submitted'),
  ('SEEN', 'Seen'),
  ('NOTICE_ISSUED', 'Notice Issued'),
  ('ARB_CONSTITUTED', 'Arbitration Constituted'),
  ('IN_PROCEEDINGS', 'In Proceedings'),
  ('DISPOSED_RECONCILED', 'Disposed — Reconciled'),
  ('DISPOSED_EFFECTIVE', 'Disposed — Effective'),
  ('FILED_NON_RESPONSE', 'Filed — Non-Response'),
];

class AdlgCasesScreen extends StatefulWidget {
  const AdlgCasesScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgCasesScreen> createState() => _AdlgCasesScreenState();
}

class _AdlgCasesScreenState extends State<AdlgCasesScreen> {
  bool _loading = true;
  String? _error;
  List<DvCase> _cases = [];
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
      final cases = await CaseService.instance.indexForAdlg(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _cases = cases;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load cases.";
        _loading = false;
      });
    }
  }

  List<DvCase> get _filtered {
    if (_search.trim().isEmpty) return _cases;
    final q = _search.toLowerCase();
    return _cases.where((c) {
      return c.caseNo.toLowerCase().contains(q) ||
          c.divorcerName.toLowerCase().contains(q) ||
          c.respondentName.toLowerCase().contains(q) ||
          (c.unionCouncil ?? '').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openDetail(DvCase c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(role: 'adlg', caseId: c.id, user: widget.user)));
    _load();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await CaseService.instance.exportCases(status: _statusFilter);
      if (mounted) await saveExportedFile(context, file);
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
        title: const Text('Cases'),
        actions: [
          IconButton(
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Export Excel',
          ),
          const NotificationBell(),
          const LogoutAction(),
        ],
      ),
      drawer: AppDrawer(role: 'adlg', currentKey: 'cases', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('${_cases.length} cases across your tehsil', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search case no., party, UC…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _statusFilter,
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
                        ..._filtered.map((c) => _CaseTile(dvCase: c, onTap: () => _openDetail(c))),
                    ],
                  ),
                ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.dvCase, required this.onTap});

  final DvCase dvCase;
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
                decoration: BoxDecoration(
                  color: (dvCase.isKhula ? AppColors.accent500 : AppColors.danger).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(dvCase.isKhula ? '🏛️' : '💔', style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dvCase.caseNo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${dvCase.divorcerName} vs ${dvCase.respondentName}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dvCase.unionCouncil != null) ...[
                      const SizedBox(height: 2),
                      Text(dvCase.unionCouncil!, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(20)),
                    child: Text(dvCase.statusLabel, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                  ),
                  if (dvCase.daysRemaining != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${dvCase.daysRemaining}d left',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dvCase.isUrgent ? AppColors.danger : AppColors.inkFaint),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}
