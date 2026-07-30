import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/dv_case.dart';
import '../services/case_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/case/add_hearing_sheet.dart';
import '../widgets/case/case_stepper.dart';
import '../widgets/case/constitute_arbitration_sheet.dart';
import '../widgets/case/document_preview.dart';
import '../widgets/case/issue_notice_sheet.dart';
import '../widgets/case/pass_decision_sheet.dart';
import '../widgets/case/proceedings_list.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'SUBMITTED':
      return AppColors.info;
    case 'SEEN':
      return AppColors.accent500;
    case 'NOTICE_ISSUED':
      return AppColors.warning;
    case 'ARB_CONSTITUTED':
    case 'IN_PROCEEDINGS':
      return AppColors.primary600;
    case 'DISPOSED_RECONCILED':
    case 'DISPOSED_EFFECTIVE':
      return AppColors.success;
    case 'FILED_NON_RESPONSE':
      return AppColors.danger;
    default:
      return AppColors.inkMuted;
  }
}

/// Full case detail — shared by both roles, since ~80% of this view (header,
/// stepper, party info, notice/arbitration/decision panels, documents,
/// hearings) is identical. Only the action buttons at the bottom differ by
/// role and case status.
class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.role, required this.caseId, required this.user});

  final String role;
  final int caseId;
  final Map<String, dynamic> user;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  bool _loading = true;
  String? _error;
  DvCase? _case;

  bool _actionBusy = false;
  bool _exportingNotesheet = false;
  bool _exportingFullFile = false;

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
      final dvCase = await CaseService.instance.show(role: widget.role, caseId: widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = dvCase;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load this case.";
        _loading = false;
      });
    }
  }

  Future<void> _markSeen() async {
    setState(() => _actionBusy = true);
    final result = await CaseService.instance.markSeen(widget.caseId);
    if (!mounted) return;
    setState(() => _actionBusy = false);
    if (result.isSuccess) {
      _load();
    } else {
      _showSnack(result.errorMessage ?? 'Could not mark as seen.');
    }
  }

  Future<void> _openIssueNotice() async {
    final updated = await showModalBottomSheet<DvCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IssueNoticeSheet(caseId: widget.caseId),
    );
    if (updated != null) _load();
  }

  Future<void> _openPassDecision() async {
    final updated = await showModalBottomSheet<DvCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PassDecisionSheet(caseId: widget.caseId),
    );
    if (updated != null) _load();
  }

  Future<void> _openConstituteArbitration() async {
    final updated = await showModalBottomSheet<DvCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConstituteArbitrationSheet(caseId: widget.caseId),
    );
    if (updated != null) _load();
  }

  Future<void> _openAddHearing() async {
    final updated = await showModalBottomSheet<DvCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddHearingSheet(role: widget.role, caseId: widget.caseId),
    );
    if (updated != null) _load();
  }

  Future<void> _downloadNotesheet() async {
    setState(() => _exportingNotesheet = true);
    try {
      final file = await CaseService.instance.downloadNotesheet(role: widget.role, caseId: widget.caseId);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Case Notesheet'));
    } catch (_) {
      if (mounted) _showSnack("Couldn't generate the notesheet.");
    } finally {
      if (mounted) setState(() => _exportingNotesheet = false);
    }
  }

  Future<void> _downloadFullCaseFile() async {
    setState(() => _exportingFullFile = true);
    try {
      final file = await CaseService.instance.downloadFullCaseFile(role: widget.role, caseId: widget.caseId);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Full Case File'));
    } catch (_) {
      if (mounted) _showSnack("Couldn't generate the case file.");
    } finally {
      if (mounted) setState(() => _exportingFullFile = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(
        title: Text(_case?.caseNo ?? 'Case Details'),
        actions: const [NotificationBell(), LogoutAction()],
      ),
      drawer: AppDrawer(role: widget.role, currentKey: 'cases', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null || _case == null
              ? Center(child: Text(_error ?? 'Case not found.', style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(onRefresh: _load, child: _buildBody(_case!)),
    );
  }

  Widget _buildBody(DvCase c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _headerCard(c),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Case Progress',
          child: CaseStepper(dvCase: c),
        ),
        const SizedBox(height: 16),
        _partyInfoCard(c),
        if (c.daysRemaining != null) ...[
          const SizedBox(height: 16),
          _deadlineCard(c),
        ],
        if (c.attachmentUrl != null || c.khulaDocuments.isNotEmpty || c.divorcerPhotos.isNotEmpty || c.respondentPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Documents & Photos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.attachmentUrl != null)
                  _linkRow(context, 'Divorce Deed', c.attachmentUrl!),
                if (c.khulaDocuments.isNotEmpty) ...[
                  if (c.attachmentUrl != null) const SizedBox(height: 12),
                  KhulaDocumentsDisplay(documents: c.khulaDocuments),
                ],
                if (c.divorcerPhotos.isNotEmpty || c.respondentPhotos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PartyPhotosDisplay(
                    divorcerPhotos: c.divorcerPhotos,
                    respondentPhotos: c.respondentPhotos,
                    divorcerLabel: c.divorcerLabel,
                    respondentLabel: c.respondentLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
        if (c.notice != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: '📬 Notice Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine('Notice No.', c.notice!.noticeNo),
                _infoLine('Issued', c.notice!.issueDate),
                _infoLine('Hearing', c.notice!.hearingDate ?? '—'),
              ],
            ),
          ),
        ],
        if (c.arbitration != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: '⚖️ Arbitration Council',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine("Husband's Rep", '${c.arbitration!.husbandRepName} · ${c.arbitration!.husbandRepDesignation ?? '—'}'),
                _infoLine("Wife's Rep", '${c.arbitration!.wifeRepName} · ${c.arbitration!.wifeRepDesignation ?? '—'}'),
              ],
            ),
          ),
        ],
        if (c.decision != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: '✅ Final Decision',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine('Order No.', c.decision!.orderNo ?? '—'),
                _infoLine('Date', c.decision!.decidedAt),
                _infoLine('Remarks', c.decision!.remarks ?? '—'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        ..._actionSection(c),
        if (c.canRecordHearing) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Hearings (${c.proceedings.length})',
            trailing: TextButton.icon(
              onPressed: _openAddHearing,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Hearing'),
            ),
            child: ProceedingsList(proceedings: c.proceedings),
          ),
        ],
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Documents',
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingNotesheet ? null : _downloadNotesheet,
                  icon: _exportingNotesheet
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Notesheet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingFullFile ? null : _downloadFullCaseFile,
                  icon: _exportingFullFile
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.folder_outlined, size: 16),
                  label: const Text('Full File'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCard(DvCase c) {
    final color = _statusColor(c.status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(c.isKhula ? '🏛️ Khula' : '💔 Divorce', c.isKhula ? AppColors.accent500 : AppColors.danger),
              _badge(c.statusLabel, color),
              if (c.isUrgent) _badge('🚨 Urgent', AppColors.danger),
            ],
          ),
          const SizedBox(height: 12),
          Text('${c.divorcerName} vs ${c.respondentName}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text('Received ${c.receiptDate}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
        ],
      ),
    );
  }

  Widget _partyInfoCard(DvCase c) {
    return _sectionCard(
      title: 'Party Information',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _partyColumn(c.divorcerLabel, c.divorcerName, c.divorcerCnic, c.divorcerPhone)),
          const SizedBox(width: 16),
          Expanded(child: _partyColumn(c.respondentLabel, c.respondentName, c.respondentCnic, c.respondentPhone)),
        ],
      ),
    );
  }

  Widget _partyColumn(String label, String name, String cnic, String? phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary600)),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(cnic, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
        if (phone != null && phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(phone, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
        ],
      ],
    );
  }

  Widget _deadlineCard(DvCase c) {
    final urgent = c.isUrgent;
    final color = urgent ? AppColors.danger : AppColors.accent600;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '90-Day Period: ${c.daysRemaining} days remaining${urgent ? ' — HIGH PRIORITY' : ''}',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actionSection(DvCase c) {
    final isAdlg = widget.role == 'adlg';
    final widgets = <Widget>[];

    if (isAdlg && c.status == 'SUBMITTED') {
      widgets.add(_actionButton('👁 Mark as Seen', _actionBusy ? null : _markSeen));
    } else if (isAdlg && c.status == 'SEEN') {
      widgets.add(_actionButton('📬 Issue Notice to Parties', _openIssueNotice));
    } else if (isAdlg && ['ARB_CONSTITUTED', 'IN_PROCEEDINGS'].contains(c.status)) {
      widgets.add(_actionButton('📋 Pass Final Decision', _openPassDecision));
    } else if (isAdlg && c.status == 'NOTICE_ISSUED' && c.arbitration == null) {
      widgets.add(_infoBox('Awaiting Arbitration Council constitution by the Secretary.'));
    }

    if (!isAdlg) {
      if (['NOTICE_ISSUED', 'IN_PROCEEDINGS'].contains(c.status) && c.arbitration == null) {
        widgets.add(_actionButton('⚖️ Constitute Arbitration Council', _openConstituteArbitration));
      } else if (c.status == 'SUBMITTED') {
        widgets.add(_infoBox('Awaiting ADLG review.'));
      } else if (c.status == 'SEEN') {
        widgets.add(_infoBox('Awaiting notice from ADLG.'));
      }
    }

    if (c.isDisposed) {
      widgets.add(_infoBox('Case closed — ${c.decision?.remarks?.isNotEmpty == true ? c.decision!.remarks : c.statusLabel}.'));
    }

    return widgets;
  }

  Widget _actionButton(String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onTap,
          child: _actionBusy && onTap == null
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(label),
        ),
      ),
    );
  }

  Widget _infoBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted, fontWeight: FontWeight.w500)),
    );
  }

  Widget _sectionCard({required String title, Widget? trailing, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _linkRow(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => openDocument(context, url),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 16, color: AppColors.primary600),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.primary600)),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
