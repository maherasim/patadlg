import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/daily_report.dart';
import '../../models/performa.dart';
import '../../services/performa_service.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/logout_action.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/case/document_preview.dart';
import '../../widgets/performa/create_performa_sheet.dart';
import '../../widgets/performa/performa_responses_sheet.dart';

class AdlgReportsScreen extends StatefulWidget {
  const AdlgReportsScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<AdlgReportsScreen> createState() => _AdlgReportsScreenState();
}

class _AdlgReportsScreenState extends State<AdlgReportsScreen> {
  int _tab = 0;

  bool _loading = true;
  String? _error;
  List<DailyReport> _reports = [];
  String _search = '';
  bool _exporting = false;

  bool _performasLoading = true;
  List<Performa> _performas = [];
  int _totalSecretaries = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPerformas();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await ReportService.instance.indexForAdlg();
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

  Future<void> _loadPerformas() async {
    setState(() => _performasLoading = true);
    try {
      final result = await PerformaService.instance.indexForAdlg();
      if (!mounted) return;
      setState(() {
        _performas = result.items;
        _totalSecretaries = result.totalSecretaries;
        _performasLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _performasLoading = false);
    }
  }

  List<DailyReport> get _filtered {
    if (_search.trim().isEmpty) return _reports;
    final q = _search.toLowerCase();
    return _reports.where((r) {
      return (r.secretary ?? '').toLowerCase().contains(q) ||
          (r.unionCouncil ?? '').toLowerCase().contains(q) ||
          r.remarks.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openDetail(DailyReport report) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportDetailSheet(report: report),
    );
    if (updated == true) _load();
  }

  Future<void> _openManageFields() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ManageFieldsSheet(),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ReportService.instance.exportReports();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Daily Reports Export'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't generate the export. Please try again.")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openCreatePerforma() async {
    final created = await showModalBottomSheet<Performa>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreatePerformaSheet(),
    );
    if (created != null) _loadPerformas();
  }

  Future<void> _openResponses(Performa p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PerformaResponsesSheet(performa: p, totalSecretaries: _totalSecretaries),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          if (_tab == 0) IconButton(onPressed: _openManageFields, icon: const Icon(Icons.tune_rounded), tooltip: 'Manage Additional Fields'),
          if (_tab == 0)
            IconButton(
              onPressed: _exporting ? null : _export,
              icon: _exporting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
              tooltip: 'Export Excel',
            ),
          const NotificationBell(),
          const LogoutAction(),
        ],
      ),
      drawer: AppDrawer(role: 'adlg', currentKey: 'reports', user: widget.user),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(onPressed: _openCreatePerforma, icon: const Icon(Icons.add_rounded), label: const Text('Publish Performa'))
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(child: _tabPill('Daily Reports', 0)),
                const SizedBox(width: 10),
                Expanded(child: _tabPill('Performas', 1)),
              ],
            ),
          ),
          Expanded(child: _tab == 0 ? _buildDailyTab() : _buildPerformasTab()),
        ],
      ),
    );
  }

  Widget _tabPill(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary500 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary500 : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkMuted)),
      ),
    );
  }

  Widget _buildDailyTab() {
    return _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text('${_reports.length} reports across your tehsil', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                    const SizedBox(height: 12),
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: const InputDecoration(
                        hintText: 'Search secretary, UC, remarks…',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
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
              );
  }

  Widget _buildPerformasTab() {
    return _performasLoading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
        : RefreshIndicator(
            onRefresh: _loadPerformas,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
              children: [
                Text('$_totalSecretaries secretaries in your tehsil', style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted)),
                const SizedBox(height: 12),
                if (_performas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(child: Text('No performas published yet.', style: TextStyle(color: AppColors.inkFaint))),
                  )
                else
                  ..._performas.map((p) => _PerformaCard(performa: p, totalSecretaries: _totalSecretaries, onTap: () => _openResponses(p))),
              ],
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
                      '${report.unionCouncil ?? ''} · ${report.reportDate}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w500),
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

class _ReportDetailSheet extends StatefulWidget {
  const _ReportDetailSheet({required this.report});

  final DailyReport report;

  @override
  State<_ReportDetailSheet> createState() => _ReportDetailSheetState();
}

class _ReportDetailSheetState extends State<_ReportDetailSheet> {
  bool _marking = false;
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    _reviewed = widget.report.reviewed;
  }

  Future<void> _markReviewed() async {
    setState(() => _marking = true);
    final ok = await ReportService.instance.markReviewed(widget.report.id);
    if (!mounted) return;
    setState(() {
      _marking = false;
      if (ok) _reviewed = true;
    });
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
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
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 18),
            Text(report.reportDate, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              '${report.secretary ?? ''} · ${report.unionCouncil ?? ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.inkMuted),
            ),
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
                    decoration: BoxDecoration(
                      color: f.isAdlgRequired ? AppColors.primary50 : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
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
            const SizedBox(height: 24),
            if (!_reviewed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _marking ? null : _markReviewed,
                  icon: _marking
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_marking ? 'Marking…' : 'Mark Reviewed'),
                ),
              ),
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

class _ManageFieldsSheet extends StatefulWidget {
  const _ManageFieldsSheet();

  @override
  State<_ManageFieldsSheet> createState() => _ManageFieldsSheetState();
}

class _ManageFieldsSheetState extends State<_ManageFieldsSheet> {
  bool _loading = true;
  List<ReportFieldDefinition> _fields = [];
  final _labelController = TextEditingController();
  bool _adding = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final fields = await ReportService.instance.fieldsForAdlg();
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _addField() async {
    final label = _labelController.text.trim();
    if (label.isEmpty) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    final result = await ReportService.instance.addField(label);
    if (!mounted) return;
    setState(() => _adding = false);
    if (result.isSuccess) {
      _labelController.clear();
      _load();
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  Future<void> _toggle(ReportFieldDefinition field) async {
    final ok = await ReportService.instance.toggleFieldActive(field.id);
    if (ok) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manage Additional Fields', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  const Text(
                    'Fields you add here appear on every secretary\'s daily report form until deactivated.',
                    style: TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _labelController,
                          decoration: const InputDecoration(hintText: 'e.g. Vaccination Count'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _adding ? null : _addField,
                        child: _adding
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Add'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      children: _fields.isEmpty
                          ? const [Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: Text('No fields yet.', style: TextStyle(color: AppColors.inkFaint))))]
                          : _fields
                              .map((field) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            field.label,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: field.active ? AppColors.ink : AppColors.inkFaint,
                                              decoration: field.active ? null : TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => _toggle(field),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (field.active ? AppColors.success : AppColors.inkFaint).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              field.active ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: field.active ? AppColors.success : AppColors.inkFaint,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerformaCard extends StatefulWidget {
  const _PerformaCard({required this.performa, required this.totalSecretaries, required this.onTap});

  final Performa performa;
  final int totalSecretaries;
  final VoidCallback onTap;

  @override
  State<_PerformaCard> createState() => _PerformaCardState();
}

class _PerformaCardState extends State<_PerformaCard> {
  bool _downloadingTemplate = false;

  Future<void> _downloadTemplate() async {
    setState(() => _downloadingTemplate = true);
    try {
      final file = await PerformaService.instance.downloadTemplateForAdlg(widget.performa.id);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Performa Template'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't download the template.")));
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final performa = widget.performa;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onTap,
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
                child: Center(child: Text(performa.isExcelMode ? '📊' : '📝', style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(performa.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (performa.description != null && performa.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(performa.description!, style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _miniBadge(performa.isExcelMode ? 'Excel' : 'Form', AppColors.accent600),
                        const SizedBox(width: 6),
                        _miniBadge(performa.isDaily ? 'Daily' : 'One-time', AppColors.primary600),
                      ],
                    ),
                    if (performa.deadline != null) ...[
                      const SizedBox(height: 4),
                      Text('Due ${performa.deadline!.split('T').first}', style: const TextStyle(fontSize: 10, color: AppColors.inkFaint)),
                    ],
                    if (performa.isExcelMode && performa.hasTemplate) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _downloadingTemplate ? null : _downloadTemplate,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _downloadingTemplate
                                ? const SizedBox(height: 12, width: 12, child: CircularProgressIndicator(strokeWidth: 1.6))
                                : const Icon(Icons.download_rounded, size: 13, color: AppColors.primary600),
                            const SizedBox(width: 4),
                            const Text('Download blank template', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${performa.responsesCount ?? 0}/${widget.totalSecretaries}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary700)),
                  const SizedBox(height: 2),
                  const Text('responded', style: TextStyle(fontSize: 9.5, color: AppColors.inkFaint)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
