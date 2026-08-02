import 'package:flutter/material.dart';

import '../../models/dklic_document.dart';
import '../../services/dklic_service.dart';
import '../../theme/app_theme.dart';
import '../case/document_preview.dart';

/// Mirrors the web app's DocumentDetailModal — marks the document read on
/// open, offers Download (opens/shares the file + logs a download) and,
/// when required, Acknowledge.
class DklicDetailSheet extends StatefulWidget {
  const DklicDetailSheet({super.key, required this.role, required this.document, required this.onChanged});

  final String role;
  final DklicDocument document;
  final ValueChanged<DklicDocument> onChanged;

  @override
  State<DklicDetailSheet> createState() => _DklicDetailSheetState();
}

class _DklicDetailSheetState extends State<DklicDetailSheet> {
  late DklicDocument _doc = widget.document;
  bool _downloading = false;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    if (!_doc.read) {
      DklicService.instance.markViewed(role: widget.role, documentId: _doc.id);
      _update(_doc.copyWith(read: true));
    }
  }

  void _update(DklicDocument updated) {
    setState(() => _doc = updated);
    widget.onChanged(updated);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    await DklicService.instance.markDownloaded(role: widget.role, documentId: _doc.id);
    if (!mounted) return;
    _update(_doc.copyWith(read: true, downloadCount: _doc.downloadCount + 1));
    setState(() => _downloading = false);
    if (_doc.fileUrl.isNotEmpty) openDocument(context, _doc.fileUrl);
  }

  Future<void> _acknowledge() async {
    setState(() => _acknowledging = true);
    try {
      final updated = await DklicService.instance.acknowledge(role: widget.role, documentId: _doc.id);
      if (!mounted) return;
      _update(updated);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't record acknowledgement. Try again.")));
    } finally {
      if (mounted) setState(() => _acknowledging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _doc.isUrgent ? AppColors.danger : AppColors.primary500;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text(_doc.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            Text(
              [_doc.category, if (_doc.referenceNo != null && _doc.referenceNo!.isNotEmpty) _doc.referenceNo!].join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(_doc.priority.toUpperCase(), priorityColor),
                _chip(_doc.audience, AppColors.inkMuted),
                if (_doc.ackRequired)
                  _chip(_doc.acknowledged ? 'Acknowledged' : 'Acknowledgement Required', _doc.acknowledged ? AppColors.success : AppColors.info),
              ],
            ),
            const SizedBox(height: 14),
            Text(_doc.subject, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
            if (_doc.description != null && _doc.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(_doc.description!, style: const TextStyle(fontSize: 13, color: AppColors.inkMuted, height: 1.4)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (_doc.publishedAt != null) _metaItem(Icons.calendar_today_rounded, _doc.publishedAt!.split('T').first),
                if (_doc.version != null && _doc.version!.isNotEmpty) _metaItem(Icons.tag_rounded, 'v${_doc.version}'),
                _metaItem(Icons.description_outlined, _doc.format),
                if (_doc.uploadedBy != null) _metaItem(Icons.person_outline_rounded, 'By ${_doc.uploadedBy}'),
              ],
            ),
            if (_doc.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _doc.tags
                    .map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(8)),
                          child: Text(t, style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted, fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloading ? null : _download,
                    icon: _downloading
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download'),
                  ),
                ),
                if (_doc.ackRequired) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _doc.acknowledged
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                                SizedBox(width: 6),
                                Text('Acknowledged', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.success)),
                              ],
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: _acknowledging ? null : _acknowledge,
                            icon: _acknowledging
                                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Acknowledge'),
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    );
  }

  Widget _metaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkFaint),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
      ],
    );
  }
}
