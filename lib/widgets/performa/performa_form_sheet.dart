import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/performa.dart';
import '../../services/performa_service.dart';
import '../../theme/app_theme.dart';

class _FieldRow {
  _FieldRow({String label = '', this.type = 'text'}) : labelController = TextEditingController(text: label);
  final TextEditingController labelController;
  String type;
}

/// ADLG-only — create or edit a Performa (form-mode dynamic form, or
/// excel-mode template), broadcast to every secretary in the tehsil,
/// immediately live (there's no draft state on the web app this mirrors).
/// Mode is fixed once created — not editable — matching the backend, which
/// rejects changing it.
class PerformaFormSheet extends StatefulWidget {
  const PerformaFormSheet({super.key, this.existing});

  final Performa? existing;

  @override
  State<PerformaFormSheet> createState() => _PerformaFormSheetState();
}

class _PerformaFormSheetState extends State<PerformaFormSheet> {
  bool get _isEdit => widget.existing != null;

  late final _titleController = TextEditingController(text: widget.existing?.title ?? '');
  late final _descriptionController = TextEditingController(text: widget.existing?.description ?? '');
  late String _mode = widget.existing?.mode ?? 'form';
  late String _reportType = widget.existing?.reportType ?? 'onetime';
  DateTime? _deadline;
  File? _excelTemplate;
  late final List<_FieldRow> _fields = widget.existing?.fields.isNotEmpty == true
      ? widget.existing!.fields.map((f) => _FieldRow(label: f.label, type: f.type)).toList()
      : [_FieldRow()];

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final deadlineStr = widget.existing?.deadline;
    if (deadlineStr != null && deadlineStr.isNotEmpty) {
      _deadline = DateTime.tryParse(deadlineStr);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    for (final f in _fields) {
      f.labelController.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickTemplate() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv']);
    final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path != null) setState(() => _excelTemplate = File(path));
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    if (!_isEdit && _mode == 'excel' && _excelTemplate == null) {
      setState(() => _error = 'Please attach an Excel template.');
      return;
    }
    final fields = _fields.where((f) => f.labelController.text.trim().isNotEmpty).map((f) => (f.labelController.text.trim(), f.type)).toList();
    if (_mode == 'form' && fields.isEmpty) {
      setState(() => _error = 'Please add at least one field.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = _isEdit
        ? await PerformaService.instance.updatePerforma(
            id: widget.existing!.id,
            mode: _mode,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            reportType: _reportType,
            deadline: _deadline != null ? _fmt(_deadline!) : null,
            excelTemplate: _mode == 'excel' ? _excelTemplate : null,
            fields: _mode == 'form' ? fields : const [],
          )
        : await PerformaService.instance.createPerforma(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            mode: _mode,
            reportType: _reportType,
            deadline: _deadline != null ? _fmt(_deadline!) : null,
            excelTemplate: _mode == 'excel' ? _excelTemplate : null,
            fields: _mode == 'form' ? fields : const [],
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
        initialChildSize: 0.85,
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
              Text(_isEdit ? 'Edit Performa' : 'Publish Performa', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                _isEdit ? widget.existing!.title : 'Broadcast to every secretary in your tehsil.',
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 18),
              _label('Title'),
              TextField(controller: _titleController),
              const SizedBox(height: 14),
              _label('Description (optional)'),
              TextField(controller: _descriptionController, maxLines: 3),
              const SizedBox(height: 16),
              _label('Mode'),
              _isEdit
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _mode == 'excel' ? 'Excel Template' : 'In-app Form',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary700),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(child: _chip('form', 'In-app Form', _mode, (v) => setState(() => _mode = v))),
                        const SizedBox(width: 10),
                        Expanded(child: _chip('excel', 'Excel Template', _mode, (v) => setState(() => _mode = v))),
                      ],
                    ),
              const SizedBox(height: 16),
              _label('Frequency'),
              Row(
                children: [
                  Expanded(child: _chip('onetime', 'One-time', _reportType, (v) => setState(() => _reportType = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _chip('daily', 'Daily', _reportType, (v) => setState(() => _reportType = v))),
                ],
              ),
              const SizedBox(height: 16),
              _label('Deadline (optional)'),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (picked != null) setState(() => _deadline = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    _deadline != null ? _fmt(_deadline!) : 'No deadline',
                    style: TextStyle(fontSize: 13.5, color: _deadline != null ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (_mode == 'excel') ...[
                _label(_isEdit ? 'Replace Excel Template (optional)' : 'Excel Template'),
                const SizedBox(height: 8),
                if (_excelTemplate == null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(onPressed: _pickTemplate, icon: const Icon(Icons.upload_file_rounded, size: 16), label: const Text('Choose File')),
                      if (_isEdit) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.existing!.hasTemplate ? 'Leave blank to keep the current template.' : 'No template attached yet.',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: Text(_excelTemplate!.path.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted), overflow: TextOverflow.ellipsis)),
                      IconButton(onPressed: () => setState(() => _excelTemplate = null), icon: const Icon(Icons.close_rounded, size: 18)),
                    ],
                  ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: _label('Fields')),
                    TextButton.icon(
                      onPressed: () => setState(() => _fields.add(_FieldRow())),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Field'),
                    ),
                  ],
                ),
                ..._fields.asMap().entries.map((entry) {
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(controller: row.labelController, decoration: const InputDecoration(hintText: 'Field label', isDense: true)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: row.type,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'text', child: Text('Text')),
                              DropdownMenuItem(value: 'number', child: Text('Number')),
                              DropdownMenuItem(value: 'date', child: Text('Date')),
                            ],
                            onChanged: (v) => setState(() => row.type = v ?? 'text'),
                          ),
                        ),
                        if (_fields.length > 1)
                          IconButton(
                            onPressed: () => setState(() {
                              row.labelController.dispose();
                              _fields.remove(row);
                            }),
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.inkFaint),
                          ),
                      ],
                    ),
                  );
                }),
                if (_isEdit)
                  const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Removing a field also deletes any answers secretaries already gave for it.',
                      style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
                    ),
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text(_isEdit ? 'Save Changes' : 'Publish'),
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

  Widget _chip(String value, String label, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary400 : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? AppColors.primary700 : AppColors.inkMuted)),
      ),
    );
  }
}
