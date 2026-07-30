import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/performa.dart';
import '../../services/performa_service.dart';
import '../../theme/app_theme.dart';
import '../case/document_preview.dart';

/// ADLG-only — lists every secretary's submission for one Performa, with an
/// Excel export of the full tehsil-wide completion summary.
class PerformaResponsesSheet extends StatefulWidget {
  const PerformaResponsesSheet({super.key, required this.performa, required this.totalSecretaries});

  final Performa performa;
  final int totalSecretaries;

  @override
  State<PerformaResponsesSheet> createState() => _PerformaResponsesSheetState();
}

class _PerformaResponsesSheetState extends State<PerformaResponsesSheet> {
  bool _loading = true;
  String? _error;
  List<PerformaResponse> _responses = [];
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
      final responses = await PerformaService.instance.responses(widget.performa.id);
      if (!mounted) return;
      setState(() {
        _responses = responses;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = "Couldn't load responses.";
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await PerformaService.instance.exportResponses(widget.performa.id);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Performa Responses Export'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't generate the export. Please try again.")));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.performa.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink)),
                        const SizedBox(height: 2),
                        Text('${_responses.length}/${widget.totalSecretaries} responded', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _exporting ? null : _export,
                    icon: _exporting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
                    tooltip: 'Export Excel',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.inkMuted)))
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          children: _responses.isEmpty
                              ? const [Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No responses yet.', style: TextStyle(color: AppColors.inkFaint))))]
                              : _responses.map(_responseTile).toList(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _responseTile(PerformaResponse r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.secretary ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    if (r.unionCouncil != null) Text(r.unionCouncil!, style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: const Text('✓ Submitted', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.success)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(r.responseDate.split('T').first, style: const TextStyle(fontSize: 10.5, color: AppColors.inkFaint)),
          if (r.type == 'excel' && r.fileUrl != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => openDocument(context, r.fileUrl!),
              child: const Row(
                children: [
                  Icon(Icons.download_rounded, size: 15, color: AppColors.primary600),
                  SizedBox(width: 6),
                  Text('Download filled file', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                ],
              ),
            ),
          ] else if (r.values.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: r.values.map((v) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(8)),
                  child: Text('${v.label}: ${v.value.isEmpty ? '—' : v.value}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary700)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
