import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/daily_report.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/case/document_preview.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';

/// Every daily report across the district — strictly read-only for DDLG
/// (no "mark reviewed" action, no Performa tab; the web app doesn't give
/// DDLG any Performa visibility at all).
class DdlgReportsScreen extends StatefulWidget {
  const DdlgReportsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<DdlgReportsScreen> createState() => _DdlgReportsScreenState();
}

class _DdlgReportsScreenState extends State<DdlgReportsScreen> {
  bool _loading = true;
  String? _error;
  List<DailyReport> _reports = [];
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
      final reports = await ReportService.instance.indexForDdlg();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load reports.";
        _loading = false;
      });
    }
  }

  List<DailyReport> get _filtered {
    if (_search.trim().isEmpty) return _reports;
    final q = _search.toLowerCase();
    return _reports.where((r) {
      return (r.secretary ?? '').toLowerCase().contains(q) ||
          (r.unionCouncil ?? '').toLowerCase().contains(q) ||
          (r.tehsil ?? '').toLowerCase().contains(q) ||
          r.remarks.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openDetail(DailyReport report) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDetailSheet(report: report),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ReportService.instance.exportReportsForDdlg();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Daily Reports Export'));
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
        title: const Text('Daily Reports'),
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
      drawer: AppDrawer(role: 'ddlg', currentKey: 'reports', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    children: [
                      Text('Every report across your district — view only', style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(hintText: 'Search secretary, UC, tehsil, remarks…', prefixIcon: Icon(Icons.search_rounded, size: 20)),
                      ),
                      const SizedBox(height: 14),
                      if (_filtered.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: Text('No reports match.', style: TextStyle(color: AppColors.inkFaint))),
                        )
                      else
                        ..._filtered.map((r) => _ReportTile(report: r, onTap: () => _openDetail(r))),
                    ],
                  ),
                ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.onTap});

  final DailyReport report;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.secretary ?? '—', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${report.tehsil ?? ''} · ${report.unionCouncil ?? ''} · ${report.reportDate}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (report.reviewed ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  report.reviewed ? 'Reviewed' : 'Pending',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: report.reviewed ? AppColors.success : AppColors.warning),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _ReportDetailSheet extends StatelessWidget {
  const _ReportDetailSheet({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text(report.reportDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text('${report.secretary ?? ''} · ${report.tehsil ?? ''} · ${report.unionCouncil ?? ''}', style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                _statBox('Nikah', report.nikahCount),
                _statBox('Birth', report.birthCount),
                _statBox('Death', report.deathCount),
                _statBox('Complaints', report.complaintCount),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Remarks', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(report.remarks.isEmpty ? '—' : report.remarks, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.5)),
            if (report.customFields.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('Additional Fields', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: report.customFields.map((f) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: f.isAdlgRequired ? AppColors.primary50 : AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${f.label}: ${f.value.isEmpty ? '—' : f.value}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: f.isAdlgRequired ? AppColors.primary700 : AppColors.inkMuted),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (report.attachmentUrl != null) ...[
              const SizedBox(height: 18),
              const Text('Attachment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => openDocument(context, report.attachmentUrl!),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_file_rounded, size: 15, color: AppColors.primary600),
                    SizedBox(width: 6),
                    Text('Open attachment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary600)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
