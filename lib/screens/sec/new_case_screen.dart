import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/case_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pk_formatters.dart';
import '../../widgets/case/document_gallery_picker.dart';
import '../../widgets/case/photo_gallery_picker.dart';

/// The Secretary's 4-step "New Case" wizard, matching the web app's flow:
/// basics -> parties -> documentation -> review & submit.
class NewCaseScreen extends StatefulWidget {
  const NewCaseScreen({super.key});

  @override
  State<NewCaseScreen> createState() => _NewCaseScreenState();
}

class _NewCaseScreenState extends State<NewCaseScreen> {
  final _pageController = PageController();
  int _step = 0;

  String _type = 'divorce';
  final _caseNoController = TextEditingController();
  DateTime _receiptDate = DateTime.now();
  final _addressController = TextEditingController();

  final _divorcerNameController = TextEditingController();
  final _divorcerCnicController = TextEditingController();
  final _divorcerPhoneController = TextEditingController();
  final _respondentNameController = TextEditingController();
  final _respondentCnicController = TextEditingController();
  final _respondentPhoneController = TextEditingController();
  DateTime? _marriageDate;
  final _nikahRegistrarController = TextEditingController();
  final _mahrAmountController = TextEditingController();
  final _childrenCountController = TextEditingController();

  File? _attachment;
  List<File> _khulaDocuments = [];
  List<File> _divorcerPhotos = [];
  List<File> _respondentPhotos = [];
  final _remarksController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _caseNoController.dispose();
    _addressController.dispose();
    _divorcerNameController.dispose();
    _divorcerCnicController.dispose();
    _divorcerPhoneController.dispose();
    _respondentNameController.dispose();
    _respondentCnicController.dispose();
    _respondentPhoneController.dispose();
    _nikahRegistrarController.dispose();
    _mahrAmountController.dispose();
    _childrenCountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool get _step1Valid => _caseNoController.text.trim().isNotEmpty;
  bool get _step2Valid =>
      _divorcerNameController.text.trim().isNotEmpty &&
      _divorcerCnicController.text.trim().isNotEmpty &&
      _respondentNameController.text.trim().isNotEmpty &&
      _respondentCnicController.text.trim().isNotEmpty;

  void _goNext() {
    if (_step == 0 && !_step1Valid) {
      setState(() => _error = 'Please enter a case number.');
      return;
    }
    if (_step == 1 && !_step2Valid) {
      setState(() => _error = "Please add both parties' name and CNIC.");
      return;
    }
    setState(() => _error = null);
    if (_step < 3) {
      setState(() => _step++);
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
    if (path != null) setState(() => _attachment = File(path));
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await CaseService.instance.storeCase(
      caseNo: _caseNoController.text.trim(),
      type: _type,
      receiptDate: _fmt(_receiptDate),
      address: _addressController.text.trim(),
      divorcerName: _divorcerNameController.text.trim(),
      divorcerCnic: _divorcerCnicController.text.trim(),
      divorcerPhone: _divorcerPhoneController.text.trim(),
      respondentName: _respondentNameController.text.trim(),
      respondentCnic: _respondentCnicController.text.trim(),
      respondentPhone: _respondentPhoneController.text.trim(),
      marriageDate: _marriageDate != null ? _fmt(_marriageDate!) : null,
      nikahRegistrar: _nikahRegistrarController.text.trim(),
      mahrAmount: _mahrAmountController.text.trim(),
      childrenCount: _childrenCountController.text.trim(),
      remarks: _remarksController.text.trim(),
      attachment: _type == 'divorce' ? _attachment : null,
      khulaDocuments: _type == 'khula' ? _khulaDocuments : const [],
      divorcerPhotos: _divorcerPhotos,
      respondentPhotos: _respondentPhotos,
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
    const stepTitles = ['Case Basics', 'Party Info', 'Documentation', 'Review & Submit'];

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text('New Case · ${stepTitles[_step]}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: List.generate(4, (i) {
                final active = i <= _step;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                    decoration: BoxDecoration(color: active ? AppColors.primary500 : AppColors.border, borderRadius: BorderRadius.circular(4)),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _stepBasics(),
                _stepParties(),
                _stepDocumentation(),
                _stepReview(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(child: OutlinedButton(onPressed: _submitting ? null : _goBack, child: const Text('Back'))),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : (_step == 3 ? _submit : _goNext),
                        child: _submitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                            : Text(_step == 3 ? 'Submit Case' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pad(Widget child) => Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), child: child);

  Widget _stepBasics() {
    return _pad(
      ListView(
        children: [
          const Text('Case Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _typeChip('divorce', '💔 Divorce')),
              const SizedBox(width: 10),
              Expanded(child: _typeChip('khula', '🏛️ Khula')),
            ],
          ),
          const SizedBox(height: 18),
          _field('Case Number', _caseNoController, hint: 'DV-2026-001'),
          const SizedBox(height: 16),
          _dateField('Receipt Date', _receiptDate, (d) => setState(() => _receiptDate = d)),
          const SizedBox(height: 16),
          _field('Address (optional)', _addressController),
        ],
      ),
    );
  }

  Widget _stepParties() {
    final divorcerLabel = _type == 'khula' ? 'Divorcer (Wife)' : 'Divorcer (Husband)';
    final respondentLabel = _type == 'khula' ? 'Respondent (Husband)' : 'Respondent (Wife)';

    return _pad(
      ListView(
        children: [
          Text(divorcerLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
          const SizedBox(height: 10),
          _field('Full Name', _divorcerNameController),
          const SizedBox(height: 10),
          _field('CNIC', _divorcerCnicController, formatters: [CnicInputFormatter()], keyboardType: TextInputType.number, hint: '12345-1234567-1'),
          const SizedBox(height: 10),
          _field('Phone (optional)', _divorcerPhoneController, formatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, hint: '0300-1234567'),
          const SizedBox(height: 22),
          Text(respondentLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.accent600)),
          const SizedBox(height: 10),
          _field('Full Name', _respondentNameController),
          const SizedBox(height: 10),
          _field('CNIC', _respondentCnicController, formatters: [CnicInputFormatter()], keyboardType: TextInputType.number, hint: '12345-1234567-1'),
          const SizedBox(height: 10),
          _field('Phone (optional)', _respondentPhoneController, formatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, hint: '0300-1234567'),
          const SizedBox(height: 22),
          const Text('Marriage Details (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 10),
          _dateField('Marriage Date', _marriageDate, (d) => setState(() => _marriageDate = d), optional: true),
          const SizedBox(height: 10),
          _field('Nikah Registrar', _nikahRegistrarController),
          const SizedBox(height: 10),
          _field('Mehr Amount', _mahrAmountController),
          const SizedBox(height: 10),
          _field('Children', _childrenCountController),
        ],
      ),
    );
  }

  Widget _stepDocumentation() {
    return _pad(
      ListView(
        children: [
          if (_type == 'divorce') ...[
            const Text('Divorce Deed', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            if (_attachment == null)
              OutlinedButton.icon(
                onPressed: _pickAttachment,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('Choose File'),
              )
            else
              Row(
                children: [
                  Expanded(child: Text(_attachment!.path.split('/').last, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted), overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() => _attachment = null), icon: const Icon(Icons.close_rounded, size: 18)),
                ],
              ),
            const SizedBox(height: 20),
          ] else ...[
            DocumentGalleryPicker(
              label: 'Court Decree',
              hint: 'Up to ~4 photos or PDFs of the decree',
              files: _khulaDocuments,
              onChanged: (files) => setState(() => _khulaDocuments = files),
            ),
            const SizedBox(height: 20),
          ],
          PhotoGalleryPicker(
            label: 'Divorcer Photos (optional)',
            hint: 'A few photos of the divorcer',
            files: _divorcerPhotos,
            onChanged: (files) => setState(() => _divorcerPhotos = files),
          ),
          const SizedBox(height: 20),
          PhotoGalleryPicker(
            label: 'Respondent Photos (optional)',
            hint: 'A few photos of the respondent',
            files: _respondentPhotos,
            onChanged: (files) => setState(() => _respondentPhotos = files),
          ),
          const SizedBox(height: 20),
          _field('Remarks (optional)', _remarksController, maxLines: 3),
        ],
      ),
    );
  }

  Widget _stepReview() {
    return _pad(
      ListView(
        children: [
          const Text('Review before submitting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 14),
          _reviewRow('Case Number', _caseNoController.text),
          _reviewRow('Type', _type == 'khula' ? 'Khula' : 'Divorce'),
          _reviewRow('Receipt Date', _fmt(_receiptDate)),
          _reviewRow('Divorcer', '${_divorcerNameController.text} · ${_divorcerCnicController.text}'),
          _reviewRow('Respondent', '${_respondentNameController.text} · ${_respondentCnicController.text}'),
          _reviewRow('Attachment', _type == 'divorce' ? (_attachment != null ? '1 file' : 'None') : '${_khulaDocuments.length} file(s)'),
          _reviewRow('Divorcer Photos', '${_divorcerPhotos.length}'),
          _reviewRow('Respondent Photos', '${_respondentPhotos.length}'),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary50 : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary400 : AppColors.border, width: selected ? 1.6 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? AppColors.primary700 : AppColors.inkMuted)),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, int maxLines = 1, List<TextInputFormatter>? formatters, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          inputFormatters: formatters,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked, {bool optional = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(1950),
              lastDate: DateTime(2100),
            );
            if (picked != null) onPicked(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(
              value != null ? _fmt(value) : (optional ? 'Not set' : 'Select date'),
              style: TextStyle(fontSize: 13.5, color: value != null ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
