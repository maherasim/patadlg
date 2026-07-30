import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lbr_case.dart';
import '../../services/lbr_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pk_formatters.dart';
import '../../widgets/lbr/lbr_doc_slot.dart';

/// The Secretary's 4-step Birth Registration wizard — used for both a brand
/// new application ([existingCase] null, [category] required) and a
/// resubmission after a RETURNED verdict ([existingCase] set, category is
/// then fixed/immutable and taken from the case).
class LbrWizardScreen extends StatefulWidget {
  const LbrWizardScreen({super.key, this.category, this.existingCase}) : assert(category != null || existingCase != null);

  final String? category;
  final LbrCase? existingCase;

  @override
  State<LbrWizardScreen> createState() => _LbrWizardScreenState();
}

class _LbrWizardScreenState extends State<LbrWizardScreen> {
  final _pageController = PageController();
  int _step = 0;

  late final String _category = widget.existingCase?.category ?? widget.category!;
  bool get _isResubmit => widget.existingCase != null;

  DateTime? _dob;
  String? _delayReason;
  final _delayReasonOtherController = TextEditingController();
  final _childNameController = TextEditingController();
  String _childGender = 'Male';
  final _childBirthPlaceController = TextEditingController();
  String _childBirthType = 'Hospital';
  final _childHospitalController = TextEditingController();

  final _applicantNameController = TextEditingController();
  final _applicantCnicController = TextEditingController();
  String _applicantRelation = 'Father';
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remarksController = TextEditingController();

  final Map<String, File> _docs = {};
  final List<_ExtraDoc> _extraDocs = [];

  bool _submitting = false;
  String? _error;

  static final _cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');

  @override
  void initState() {
    super.initState();
    final c = widget.existingCase;
    if (c != null) {
      _dob = DateTime.tryParse(c.dob);
      final knownReason = kLbrDelayReasons.contains(c.delayReason) ? c.delayReason : 'Other';
      _delayReason = knownReason;
      if (knownReason == 'Other') _delayReasonOtherController.text = c.delayReason;
      _childNameController.text = c.childName;
      _childGender = c.childGender;
      _childBirthPlaceController.text = c.childBirthPlace ?? '';
      _childBirthType = (c.childBirthType?.isNotEmpty ?? false) ? c.childBirthType! : 'Hospital';
      _childHospitalController.text = c.childHospital ?? '';
      _applicantNameController.text = c.applicantName;
      _applicantCnicController.text = c.applicantCnic;
      _applicantRelation = (c.applicantRelation?.isNotEmpty ?? false) ? c.applicantRelation! : 'Father';
      _fatherNameController.text = c.applicantFatherName ?? '';
      _motherNameController.text = c.applicantMotherName ?? '';
      _addressController.text = c.applicantAddress ?? '';
      _phoneController.text = c.applicantPhone ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _delayReasonOtherController.dispose();
    _childNameController.dispose();
    _childBirthPlaceController.dispose();
    _childHospitalController.dispose();
    _applicantNameController.dispose();
    _applicantCnicController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _remarksController.dispose();
    for (final d in _extraDocs) {
      d.labelController.dispose();
    }
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? get _age {
    if (_dob == null) return null;
    return DateTime.now().difference(_dob!).inDays / 365.25;
  }

  bool get _ageValid {
    final age = _age;
    if (age == null) return false;
    return _category == '1-7' ? (age >= 1 && age <= 7) : age > 7;
  }

  bool get _step1Valid {
    if (_dob == null || !_ageValid) return false;
    if (_delayReason == null) return false;
    if (_delayReason == 'Other' && _delayReasonOtherController.text.trim().isEmpty) return false;
    return _childNameController.text.trim().isNotEmpty && _childBirthPlaceController.text.trim().isNotEmpty;
  }

  bool get _step2Valid {
    return _applicantNameController.text.trim().isNotEmpty &&
        _cnicRegex.hasMatch(_applicantCnicController.text.trim()) &&
        _addressController.text.trim().isNotEmpty &&
        _fatherNameController.text.trim().isNotEmpty &&
        _motherNameController.text.trim().isNotEmpty;
  }

  List<LbrDocSlotDef> get _visibleSlots => kLbrDocSlots.where((d) => d.categoryOnly == null || d.categoryOnly == _category).toList();

  String? _existingDocUrl(String key) {
    final c = widget.existingCase;
    if (c == null) return null;
    for (final doc in c.documents) {
      if (doc.docKey == key) return doc.fileUrl;
    }
    return null;
  }

  List<String> get _missingRequiredDocLabels {
    return _visibleSlots
        .where((slot) => slot.required && _docs[slot.key] == null && _existingDocUrl(slot.key) == null)
        .map((s) => s.label)
        .toList();
  }

  void _goNext() {
    if (_step == 0 && !_step1Valid) {
      setState(() => _error = 'Please complete the child and delay-reason details.');
      return;
    }
    if (_step == 1 && !_step2Valid) {
      setState(() => _error = 'Please complete the applicant details (CNIC format: 12345-1234567-1).');
      return;
    }
    if (_step == 2 && _missingRequiredDocLabels.isNotEmpty) {
      setState(() => _error = 'Missing required document: ${_missingRequiredDocLabels.first}');
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

  void _addExtraDoc() {
    setState(() => _extraDocs.add(_ExtraDoc(id: DateTime.now().millisecondsSinceEpoch.toString())));
  }

  void _removeExtraDoc(_ExtraDoc doc) {
    setState(() {
      doc.labelController.dispose();
      _extraDocs.remove(doc);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final resolvedDelayReason = _delayReason == 'Other' ? _delayReasonOtherController.text.trim() : _delayReason!;
    final extraLabels = <String, String>{
      for (final d in _extraDocs)
        if (d.file != null && d.labelController.text.trim().isNotEmpty) 'extra_${d.id}': d.labelController.text.trim(),
    };
    final extraDocsMap = <String, File>{
      for (final d in _extraDocs)
        if (d.file != null && d.labelController.text.trim().isNotEmpty) 'extra_${d.id}': d.file!,
    };

    final result = _isResubmit
        ? await LbrService.instance.resubmit(
            id: widget.existingCase!.id,
            dob: _fmt(_dob!),
            delayReason: resolvedDelayReason,
            childName: _childNameController.text.trim(),
            childGender: _childGender,
            childBirthPlace: _childBirthPlaceController.text.trim(),
            childBirthType: _childBirthType,
            childHospital: _childHospitalController.text.trim(),
            applicantName: _applicantNameController.text.trim(),
            applicantCnic: _applicantCnicController.text.trim(),
            applicantRelation: _applicantRelation,
            applicantFatherName: _fatherNameController.text.trim(),
            applicantMotherName: _motherNameController.text.trim(),
            applicantAddress: _addressController.text.trim(),
            applicantPhone: _phoneController.text.trim(),
            secretaryRemarks: _remarksController.text.trim(),
            docs: {..._docs, ...extraDocsMap},
            extraLabels: extraLabels,
          )
        : await LbrService.instance.storeCase(
            category: _category,
            dob: _fmt(_dob!),
            delayReason: resolvedDelayReason,
            childName: _childNameController.text.trim(),
            childGender: _childGender,
            childBirthPlace: _childBirthPlaceController.text.trim(),
            childBirthType: _childBirthType,
            childHospital: _childHospitalController.text.trim(),
            applicantName: _applicantNameController.text.trim(),
            applicantCnic: _applicantCnicController.text.trim(),
            applicantRelation: _applicantRelation,
            applicantFatherName: _fatherNameController.text.trim(),
            applicantMotherName: _motherNameController.text.trim(),
            applicantAddress: _addressController.text.trim(),
            applicantPhone: _phoneController.text.trim(),
            secretaryRemarks: _remarksController.text.trim(),
            docs: {..._docs, ...extraDocsMap},
            extraLabels: extraLabels,
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
    const stepTitles = ['Child & Delay', 'Applicant', 'Documents', 'Review & Submit'];

    return Scaffold(
      backgroundColor: AppColors.surfaceSubtle,
      appBar: AppBar(title: Text('${_isResubmit ? 'Resubmit' : 'New'} Application · ${stepTitles[_step]}')),
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
                _stepChildDelay(),
                _stepApplicant(),
                _stepDocuments(),
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
                            : Text(_step == 3 ? (_isResubmit ? 'Resubmit to ADLG' : 'Submit Application') : 'Next'),
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

  Widget _stepChildDelay() {
    final age = _age;
    return _pad(
      ListView(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Category: ${kLbrCategoryLabels[_category]}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary700),
            ),
          ),
          const SizedBox(height: 16),
          _dateField('Date of Birth', _dob, (d) => setState(() => _dob = d)),
          if (_dob != null && !_ageValid) ...[
            const SizedBox(height: 6),
            Text(
              _category == '1-7' ? 'Age must be between 1 and 7 years for this category.' : 'Age must be over 7 years for this category.',
              style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ] else if (age != null) ...[
            const SizedBox(height: 6),
            Text('Age at application: ${age.toStringAsFixed(1)} years', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
          ],
          const SizedBox(height: 16),
          const Text('Reason for Delay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _delayReason,
            hint: const Text('Select a reason'),
            items: kLbrDelayReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _delayReason = v),
          ),
          if (_delayReason == 'Other') ...[
            const SizedBox(height: 10),
            _field('Please specify', _delayReasonOtherController),
          ],
          const SizedBox(height: 20),
          const Text("Child's Full Name", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(controller: _childNameController),
          const SizedBox(height: 16),
          const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: ['Male', 'Female', 'Other'].map((g) {
              final selected = _childGender == g;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == 'Other' ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _childGender = g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary50 : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AppColors.primary400 : AppColors.border, width: selected ? 1.6 : 1),
                      ),
                      child: Text(g, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? AppColors.primary700 : AppColors.inkMuted)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _field('Birth Place', _childBirthPlaceController),
          const SizedBox(height: 16),
          const Text('Birth Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _childBirthType,
            items: ['Hospital', 'Home', 'Other'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _childBirthType = v ?? 'Hospital'),
          ),
          const SizedBox(height: 16),
          _field('Hospital Name (optional)', _childHospitalController),
        ],
      ),
    );
  }

  Widget _stepApplicant() {
    return _pad(
      ListView(
        children: [
          _field('Applicant Full Name', _applicantNameController),
          const SizedBox(height: 14),
          _field('Applicant CNIC', _applicantCnicController, formatters: [CnicInputFormatter()], keyboardType: TextInputType.number, hint: '36602-3534535-7'),
          const SizedBox(height: 14),
          const Text('Relation to Child', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _applicantRelation,
            items: ['Father', 'Mother', 'Guardian', 'Self'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _applicantRelation = v ?? 'Father'),
          ),
          const SizedBox(height: 14),
          _field('Address', _addressController),
          const SizedBox(height: 14),
          _field('Phone (optional)', _phoneController, formatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, hint: '0300-1234567'),
          const SizedBox(height: 20),
          _field("Father's Name", _fatherNameController),
          const SizedBox(height: 14),
          _field("Mother's Name", _motherNameController),
        ],
      ),
    );
  }

  Widget _stepDocuments() {
    return _pad(
      ListView(
        children: [
          ..._visibleSlots.map((slot) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LbrDocSlotTile(
                  label: slot.label,
                  required: slot.required,
                  allowedExtensions: slot.allowedExtensions,
                  file: _docs[slot.key],
                  existingUrl: _existingDocUrl(slot.key),
                  onChanged: (f) => setState(() {
                    if (f == null) {
                      _docs.remove(slot.key);
                    } else {
                      _docs[slot.key] = f;
                    }
                  }),
                ),
              )),
          const SizedBox(height: 6),
          ..._extraDocs.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: d.labelController,
                              decoration: const InputDecoration(hintText: 'Document label', isDense: true),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          IconButton(onPressed: () => _removeExtraDoc(d), icon: const Icon(Icons.close_rounded, size: 18), color: AppColors.inkFaint),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (d.file != null)
                        Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 15, color: AppColors.primary500),
                            const SizedBox(width: 6),
                            Expanded(child: Text(d.file!.path.split(Platform.pathSeparator).last, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted), overflow: TextOverflow.ellipsis)),
                            TextButton(onPressed: () => setState(() => d.file = null), child: const Text('Change')),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
                            final path = (result != null && result.files.isNotEmpty) ? result.files.first.path : null;
                            if (path != null) setState(() => d.file = File(path));
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 15),
                          label: const Text('Choose File'),
                        ),
                    ],
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: _addExtraDoc,
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Additional Document'),
          ),
          const SizedBox(height: 20),
          const Text('Secretary Remarks (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(controller: _remarksController, maxLines: 4),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              const template =
                  'Record of the UC has duly been checked. The child is not registered, therefore it is requested to approve this case as all legal formalities have been fulfilled. This case is fit for approval please.';
              _remarksController.text = _remarksController.text.isEmpty ? template : '${_remarksController.text}\n$template';
            },
            child: const Text('✨ Insert standard approval remarks'),
          ),
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
          _reviewRow('Category', kLbrCategoryLabels[_category] ?? _category),
          _reviewRow('Child', _childNameController.text),
          _reviewRow('DOB', _dob != null ? _fmt(_dob!) : '—'),
          _reviewRow('Age at Application', _age != null ? '${_age!.toStringAsFixed(1)} years' : '—'),
          _reviewRow('Applicant', '${_applicantNameController.text} · ${_applicantCnicController.text}'),
          _reviewRow('Documents Attached', '${_docs.length + _extraDocs.where((d) => d.file != null).length}'),
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
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12.5, color: AppColors.ink, fontWeight: FontWeight.w600))),
        ],
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

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            final picked = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime.now());
            if (picked != null) onPicked(picked);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(
              value != null ? _fmt(value) : 'Select date',
              style: TextStyle(fontSize: 13.5, color: value != null ? AppColors.ink : AppColors.inkFaint, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtraDoc {
  _ExtraDoc({required this.id});

  final String id;
  final labelController = TextEditingController();
  File? file;
}
