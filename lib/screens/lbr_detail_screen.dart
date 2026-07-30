import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lbr_case.dart';
import '../services/lbr_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/case/document_preview.dart';
import '../widgets/lbr/lbr_certificate_sheet.dart';
import '../widgets/lbr/lbr_review_sheet.dart';
import '../widgets/logout_action.dart';
import '../widgets/notification_bell.dart';
import 'sec/lbr_wizard_screen.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'FORWARDED':
    case 'PENDING_DDLG_APPROVAL':
      return AppColors.info;
    case 'APPROVED':
    case 'REGISTERED':
      return AppColors.success;
    case 'REJECTED':
      return AppColors.danger;
    case 'RETURNED':
      return AppColors.warning;
    default:
      return AppColors.inkMuted;
  }
}

/// Full LBR case detail — shared by all three roles. Header/child/applicant/
/// documents/note-trail are identical everywhere; only the action buttons at
/// the bottom differ by role and status.
class LbrDetailScreen extends StatefulWidget {
  const LbrDetailScreen({super.key, required this.role, required this.caseId, required this.user});

  final String role;
  final int caseId;
  final Map<String, dynamic> user;

  @override
  State<LbrDetailScreen> createState() => _LbrDetailScreenState();
}

class _LbrDetailScreenState extends State<LbrDetailScreen> {
  bool _loading = true;
  String? _error;
  LbrCase? _case;
  bool _exportingNotesheet = false;

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
      final lbrCase = await LbrService.instance.show(role: widget.role, id: widget.caseId);
      if (!mounted) return;
      setState(() {
        _case = lbrCase;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load this application.";
        _loading = false;
      });
    }
  }

  Future<void> _openReview() async {
    final updated = await showModalBottomSheet<LbrCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LbrReviewSheet(role: widget.role, lbrCase: _case!),
    );
    if (updated != null) _load();
  }

  Future<void> _openCertificate() async {
    final updated = await showModalBottomSheet<LbrCase>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LbrCertificateSheet(caseId: widget.caseId),
    );
    if (updated != null) _load();
  }

  Future<void> _openResubmit() async {
    final updated = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LbrWizardScreen(existingCase: _case!)));
    if (updated != null) _load();
  }

  Future<void> _downloadNotesheet() async {
    setState(() => _exportingNotesheet = true);
    try {
      final file = await LbrService.instance.downloadNotesheet(role: widget.role, id: widget.caseId);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Birth Registration Notesheet'));
    } catch (_) {
      if (mounted) _showSnack("Couldn't generate the notesheet.");
    } finally {
      if (mounted) setState(() => _exportingNotesheet = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text(_case?.lbrId ?? 'Application Details'), actions: const [NotificationBell(), LogoutAction()]),
      drawer: AppDrawer(role: widget.role, currentKey: 'lbr', user: widget.user),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
          : _error != null || _case == null
              ? Center(child: Text(_error ?? 'Not found.', style: const TextStyle(color: AppColors.inkMuted)))
              : RefreshIndicator(onRefresh: _load, child: _buildBody(_case!)),
    );
  }

  Widget _buildBody(LbrCase c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _headerCard(c),
        if (_statusBanner(c) != null) ...[
          const SizedBox(height: 14),
          _statusBanner(c)!,
        ],
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Child',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('Name', c.childName),
              _infoLine('Gender', c.childGender),
              _infoLine('DOB', c.dob),
              if (c.ageAtApplication != null) _infoLine('Age at Application', '${c.ageAtApplication!.toStringAsFixed(1)} years'),
              _infoLine('Birth Place', c.childBirthPlace ?? '—'),
              _infoLine('Birth Type', c.childBirthType ?? '—'),
              if (c.childHospital != null && c.childHospital!.isNotEmpty) _infoLine('Hospital', c.childHospital!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Applicant',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('Name', c.applicantName),
              _infoLine('CNIC', c.applicantCnic),
              _infoLine('Relation', c.applicantRelation ?? '—'),
              _infoLine('Address', c.applicantAddress ?? '—'),
              if (c.applicantPhone != null && c.applicantPhone!.isNotEmpty) _infoLine('Phone', c.applicantPhone!),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Reason for Delay',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.delayReason, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600)),
              if (c.secretaryRemarks != null && c.secretaryRemarks!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('"${c.secretaryRemarks}"', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        if (c.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Documents (${c.documents.length})',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.documents.map((d) => _docChip(context, d)).toList(),
            ),
          ),
        ],
        if (c.adlgObservations != null && c.adlgObservations!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _observationsCard('ADLG Observations', c.adlgObservations!, c.adlgOrderNo, AppColors.info),
        ],
        if (c.ddlgObservations != null && c.ddlgObservations!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _observationsCard('DDLG Observations', c.ddlgObservations!, c.ddlgOrderNo, AppColors.accent600),
        ],
        if (c.certificate != null) ...[
          const SizedBox(height: 16),
          _sectionCard(
            title: '📜 Birth Certificate',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoLine('Certificate No.', c.certificate!.certificateNo),
                _infoLine('Date', c.certificate!.certificateDate),
                if (c.certificate!.certificateRemarks != null && c.certificate!.certificateRemarks!.isNotEmpty)
                  _infoLine('Remarks', c.certificate!.certificateRemarks!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        ..._actionSection(c),
        if (c.timeline.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionCard(title: 'Note Trail', child: _timelineList(c)),
        ],
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Notesheet',
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _exportingNotesheet ? null : _downloadNotesheet,
              icon: _exportingNotesheet
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.description_outlined, size: 16),
              label: const Text('Download Notesheet'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerCard(LbrCase c) {
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
              _badge(c.categoryLabel, AppColors.primary600),
              _badge(c.statusLabel, color),
              if (c.locked) _badge('🔒 Locked', AppColors.inkMuted),
            ],
          ),
          const SizedBox(height: 12),
          Text(c.childName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text('${c.applicantName} · ${c.applicantCnic}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
        ],
      ),
    );
  }

  Widget? _statusBanner(LbrCase c) {
    String? text;
    Color color = AppColors.info;
    if (c.status == 'PENDING_DDLG_APPROVAL') {
      text = 'ADLG forwarded this to DDLG for the final decision.';
    } else if (c.status == 'RETURNED') {
      text = 'Returned for correction. Review the remarks below and resubmit.';
      color = AppColors.warning;
    } else if (c.status == 'APPROVED') {
      text = 'Approved. Register the certificate below.';
      color = AppColors.success;
    }
    if (text == null) return null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  List<Widget> _actionSection(LbrCase c) {
    final widgets = <Widget>[];

    if (widget.role == 'adlg' && c.status == 'FORWARDED') {
      widgets.add(_actionButton('Review Decision', _openReview));
    } else if (widget.role == 'ddlg' && c.status == 'PENDING_DDLG_APPROVAL') {
      widgets.add(_actionButton('Final Decision', _openReview));
    } else if (widget.role == 'sec') {
      if (c.status == 'APPROVED') {
        widgets.add(_actionButton('📜 Register Certificate', _openCertificate));
      } else if (c.status == 'RETURNED') {
        widgets.add(_actionButton('✏️ Resubmit', _openResubmit));
      }
    }

    if (widgets.isEmpty) return const [];
    return [...widgets, const SizedBox(height: 4)];
  }

  Widget _timelineList(LbrCase c) {
    return Column(
      children: [
        for (var i = 0; i < c.timeline.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(border: i == c.timeline.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.border, width: 0.7))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.circle, size: 8, color: AppColors.primary500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(c.timeline[i].stage, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink))),
                          Text(c.timeline[i].eventDate, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
                        ],
                      ),
                      if (c.timeline[i].note != null && c.timeline[i].note!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(c.timeline[i].note!, style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted)),
                      ],
                      if (c.timeline[i].actor != null && c.timeline[i].actor!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('— ${c.timeline[i].actor}', style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _observationsCard(String title, String observations, String? orderNo, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          Text(observations, style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
          if (orderNo != null && orderNo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Order No.: $orderNo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ],
      ),
    );
  }

  Widget _docChip(BuildContext context, LbrDocument d) {
    return GestureDetector(
      onTap: () => openDocument(context, d.fileUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 160),
        decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isImageUrl(d.fileUrl) ? Icons.image_rounded : Icons.picture_as_pdf_outlined, size: 15, color: AppColors.primary500),
            const SizedBox(width: 6),
            Flexible(child: Text(d.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary600), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onTap, child: Text(label))),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
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
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
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
