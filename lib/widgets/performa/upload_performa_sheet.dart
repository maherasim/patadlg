import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/performa.dart';
import '../../services/performa_service.dart';
import '../../theme/app_theme.dart';

/// Secretary-only — downloads the ADLG's blank template (if attached) and
/// uploads a filled copy back for an excel-mode Performa. A scanned PDF is
/// accepted too, matching the web app's own upload accept-list.
class UploadPerformaSheet extends StatefulWidget {
  const UploadPerformaSheet({super.key, required this.performa});

  final Performa performa;

  @override
  State<UploadPerformaSheet> createState() => _UploadPerformaSheetState();
}

class _UploadPerformaSheetState extends State<UploadPerformaSheet> {
  File? _file;
  bool _downloadingTemplate = false;
  bool _submitting = false;
  String? _error;

  Future<void> _downloadTemplate() async {
    setState(() => _downloadingTemplate = true);
    try {
      final file = await PerformaService.instance.downloadTemplateForSecretary(widget.performa.id);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'Performa Template'));
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't download the template.");
    } finally {
      if (mounted) setState(() => _downloadingTemplate = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv', 'pdf']);
    final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path != null) setState(() => _file = File(path));
  }

  Future<void> _submit() async {
    if (_file == null) {
      setState(() => _error = 'Please choose a file to upload.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await PerformaService.instance.respondExcel(performaId: widget.performa.id, file: _file!);

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text(widget.performa.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            if (widget.performa.description != null && widget.performa.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.performa.description!, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            ],
            const SizedBox(height: 18),
            if (widget.performa.hasTemplate)
              OutlinedButton.icon(
                onPressed: _downloadingTemplate ? null : _downloadTemplate,
                icon: _downloadingTemplate
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download blank template'),
              ),
            const SizedBox(height: 16),
            const Text('Filled File', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            if (_file == null)
              OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file_rounded, size: 16), label: const Text('Choose File'))
            else
              Row(
                children: [
                  Expanded(child: Text(_file!.path.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() => _file = null), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }
}
