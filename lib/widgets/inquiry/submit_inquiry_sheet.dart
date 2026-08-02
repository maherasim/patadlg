import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/union_council.dart';
import '../../services/directory_service.dart';
import '../../services/inquiry_service.dart';
import '../../theme/app_theme.dart';

/// Mirrors the web app's SubmitInquiryModal — subject, optional UC, remarks,
/// and a required PDF attachment. Pops the created Inquiry on success.
class SubmitInquirySheet extends StatefulWidget {
  const SubmitInquirySheet({super.key, required this.role});

  final String role;

  @override
  State<SubmitInquirySheet> createState() => _SubmitInquirySheetState();
}

class _SubmitInquirySheetState extends State<SubmitInquirySheet> {
  final _subjectController = TextEditingController();
  final _remarksController = TextEditingController();
  int? _unionCouncilId;
  File? _file;
  bool _submitting = false;
  String? _error;

  List<UnionCouncil> _unionCouncils = [];
  bool _loadingUcs = true;

  @override
  void initState() {
    super.initState();
    _loadUnionCouncils();
  }

  Future<void> _loadUnionCouncils() async {
    try {
      final ucs = widget.role == 'ddlg'
          ? await DirectoryService.instance.unionCouncilsForDdlg()
          : await DirectoryService.instance.unionCouncilsForAdlg();
      if (!mounted) return;
      setState(() {
        _unionCouncils = ucs;
        _loadingUcs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUcs = false);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf']);
    final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path != null) setState(() => _file = File(path));
  }

  Future<void> _submit() async {
    if (_subjectController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a subject.');
      return;
    }
    if (_remarksController.text.trim().isEmpty) {
      setState(() => _error = 'Please add remarks / summary.');
      return;
    }
    if (_file == null) {
      setState(() => _error = 'Please attach the inquiry PDF.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await InquiryService.instance.submit(
      role: widget.role,
      subject: _subjectController.text.trim(),
      unionCouncilId: _unionCouncilId,
      remarks: _remarksController.text.trim(),
      file: _file!,
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).pop(result.data);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text('Submit Inquiry Request', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 18),
              _label('Subject'),
              TextField(controller: _subjectController, autofocus: true),
              const SizedBox(height: 14),
              _label('Union Council (optional)'),
              _loadingUcs
                  ? const SizedBox(height: 44, child: Center(child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))))
                  : DropdownButtonFormField<int?>(
                      initialValue: _unionCouncilId,
                      isExpanded: true,
                      hint: const Text('Not specific to a UC'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Not specific to a UC')),
                        ..._unionCouncils.map((u) => DropdownMenuItem<int?>(value: u.id, child: Text(u.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _unionCouncilId = v),
                    ),
              const SizedBox(height: 14),
              _label('Remarks / Summary'),
              TextField(controller: _remarksController, maxLines: 3),
              const SizedBox(height: 14),
              _label('Inquiry File (PDF)'),
              const SizedBox(height: 8),
              if (_file == null)
                OutlinedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file_rounded, size: 16), label: const Text('Choose File'))
              else
                Row(
                  children: [
                    Expanded(child: Text(_file!.path.split('/').last, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted), overflow: TextOverflow.ellipsis)),
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
                    : const Text('Submit to Super Admin'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
      );
}
