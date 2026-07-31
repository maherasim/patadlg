import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/death_case.dart';
import '../../services/death_case_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pk_formatters.dart';
import '../../widgets/ldr/ldr_doc_slot.dart';

/// The Secretary's 4-step Death Registration wizard — used for both a brand
/// new application ([existingCase] null, [category] required) and a
/// resubmission after a RETURNED verdict ([existingCase] set, category is
/// then fixed/immutable and taken from the case).
class LdrWizardScreen extends StatefulWidget {
  const LdrWizardScreen({super.key, this.category, this.existingCase}) : assert(category != null || existingCase != null);

  final String? category;
  final DeathCase? existingCase;

  @override
  State<LdrWizardScreen> createState() => _LdrWizardScreenState();
}

class _LdrWizardScreenState extends State<LdrWizardScreen> {
  final _pageController = PageController();
  int _step = 0;

  late final String _category = widget.existingCase?.category ?? widget.category!;
  bool get _isResubmit => widget.existingCase != null;

  DateTime? _dateOfDeath;
  String? _delayReason;
  final _delayReasonOtherController = TextEditingController();
  final _deceasedNameController = TextEditingController();
  String _deceasedGender = 'Male';
  final _deceasedCnicController = TextEditingController();
  final _causeOfDeathController = TextEditingController();
  final _placeOfDeathController = TextEditingController();
  final _burialPlaceController = TextEditingController();

  final _applicantNameController = TextEditingController();
  final _applicantCnicController = TextEditingController();
  String _applicantRelation = 'Son';
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _remarksController = TextEditingController();

  final _courtDecreeNoController = TextEditingController();
  DateTime? _courtDecreeDate;
  final _courtNameController = TextEditingController();
  final _countryOfDeathController = TextEditingController();
  final _passportNoController = TextEditingController();

  final Map<String, File> _docs = {};

  bool _submitting = false;
  String? _error;

  static final _cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
  static const _relations = ['Son', 'Daughter', 'Spouse', 'Father', 'Mother', 'Brother', 'Sister', 'Other'];

  @override
  void initState() {
    super.initState();
    final c = widget.existingCase;
    if (c != null) {
      _dateOfDeath = DateTime.tryParse(c.dateOfDeath);
      final knownReason = kLdrDelayReasons.contains(c.delayReason) ? c.delayReason : 'Other';
      _delayReason = knownReason;
      if (knownReason == 'Other') _delayReasonOtherController.text = c.delayReason;
      _deceasedNameController.text = c.deceasedName;
      _deceasedGender = c.deceasedGender;
      _deceasedCnicController.text = c.deceasedCnic ?? '';
      _causeOfDeathController.text = c.causeOfDeath ?? '';
      _placeOfDeathController.text = c.placeOfDeath ?? '';
      _burialPlaceController.text = c.burialPlace ?? '';
      _applicantNameController.text = c.applicantName;
      _applicantCnicController.text = c.applicantCnic;
      _applicantRelation = _relations.contains(c.applicantRelation) ? c.applicantRelation! : 'Son';
      _addressController.text = c.applicantAddress ?? '';
      _phoneController.text = c.applicantPhone ?? '';
      if (c.courtDecree != null) {
        _courtDecreeNoController.text = c.courtDecree!.decreeNo;
        _courtDecreeDate = DateTime.tryParse(c.courtDecree!.decreeDate);
        _courtNameController.text = c.courtDecree!.courtName;
      }
      if (c.abroad != null) {
        _countryOfDeathController.text = c.abroad!.countryOfDeath;
        _passportNoController.text = c.abroad!.passportNo;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _delayReasonOtherController.dispose();
    _deceasedNameController.dispose();
    _deceasedCnicController.dispose();
    _causeOfDeathController.dispose();
    _placeOfDeathController.dispose();
    _burialPlaceController.dispose();
    _applicantNameController.dispose();
    _applicantCnicController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _remarksController.dispose();
    _courtDecreeNoController.dispose();
    _courtNameController.dispose();
    _countryOfDeathController.dispose();
    _passportNoController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double? get _delayYears {
    if (_dateOfDeath == null) return null;
    return DateTime.now().difference(_dateOfDeath!).inDays / 365.25;
  }

  bool get _step1Valid {
    if (_dateOfDeath == null) return false;
    if (_delayReason == null) return false;
    if (_delayReason == 'Other' && _delayReasonOtherController.text.trim().isEmpty) return false;
    return _deceasedNameController.text.trim().isNotEmpty;
  }

  bool get _step2Valid {
    final baseValid = _applicantNameController.text.trim().isNotEmpty &&
        _cnicRegex.hasMatch(_applicantCnicController.text.trim()) &&
        _addressController.text.trim().isNotEmpty;
    if (!baseValid) return false;
    if (_category == '7+') {
      return _courtDecreeNoController.text.trim().isNotEmpty && _courtDecreeDate != null && _courtNameController.text.trim().isNotEmpty;
    }
    if (_category == 'ABROAD') {
      return _countryOfDeathController.text.trim().isNotEmpty && _passportNoController.text.trim().isNotEmpty;
    }
    return true;
  }

  List<LdrDocSlotDef> get _visibleSlots => kLdrDocSlots.where((d) => d.categoryOnly == null || d.categoryOnly == _category).toList();

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
      setState(() => _error = 'Please complete the death details and delay reason.');
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final resolvedDelayReason = _delayReason == 'Other' ? _delayReasonOtherController.text.trim() : _delayReason!;

    final result = _isResubmit
        ? await DeathCaseService.instance.resubmit(
            id: widget.existingCase!.id,
            category: _category,
            dateOfDeath: _fmt(_dateOfDeath!),
            delayReason: resolvedDelayReason,
            deceasedName: _deceasedNameController.text.trim(),
            deceasedGender: _deceasedGender,
            deceasedCnic: _deceasedCnicController.text.trim(),
            causeOfDeath: _causeOfDeathController.text.trim(),
            placeOfDeath: _placeOfDeathController.text.trim(),
            burialPlace: _burialPlaceController.text.trim(),
            applicantName: _applicantNameController.text.trim(),
            applicantCnic: _applicantCnicController.text.trim(),
            applicantRelation: _applicantRelation,
            applicantAddress: _addressController.text.trim(),
            applicantPhone: _phoneController.text.trim(),
            courtDecreeNo: _courtDecreeNoController.text.trim(),
            courtDecreeDate: _courtDecreeDate != null ? _fmt(_courtDecreeDate!) : null,
            courtName: _courtNameController.text.trim(),
            countryOfDeath: _countryOfDeathController.text.trim(),
            passportNo: _passportNoController.text.trim(),
            secretaryRemarks: _remarksController.text.trim(),
            docs: _docs,
          )
        : await DeathCaseService.instance.storeCase(
            category: _category,
            dateOfDeath: _fmt(_dateOfDeath!),
            delayReason: resolvedDelayReason,
            deceasedName: _deceasedNameController.text.trim(),
            deceasedGender: _deceasedGender,
            deceasedCnic: _deceasedCnicController.text.trim(),
            causeOfDeath: _causeOfDeathController.text.trim(),
            placeOfDeath: _placeOfDeathController.text.trim(),
            burialPlace: _burialPlaceController.text.trim(),
            applicantName: _applicantNameController.text.trim(),
            applicantCnic: _applicantCnicController.text.trim(),
            applicantRelation: _applicantRelation,
            applicantAddress: _addressController.text.trim(),
            applicantPhone: _phoneController.text.trim(),
            courtDecreeNo: _courtDecreeNoController.text.trim(),
            courtDecreeDate: _courtDecreeDate != null ? _fmt(_courtDecreeDate!) : null,
            courtName: _courtNameController.text.trim(),
            countryOfDeath: _countryOfDeathController.text.trim(),
            passportNo: _passportNoController.text.trim(),
            secretaryRemarks: _remarksController.text.trim(),
            docs: _docs,
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
    const stepTitles = ['Death Details', 'Applicant', 'Documents', 'Review & Submit'];

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
                _stepDeathDetails(),
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

  Widget _stepDeathDetails() {
    final delay = _delayYears;
    return _pad(
      ListView(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
            child: Text(
              'Category: ${kLdrCategoryLabels[_category]}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary700),
            ),
          ),
          const SizedBox(height: 16),
          _dateField('Date of Death', _dateOfDeath, (d) => setState(() => _dateOfDeath = d)),
          if (delay != null) ...[
            const SizedBox(height: 6),
            Text('Delay: ${delay.toStringAsFixed(1)} years', style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
          ],
          const SizedBox(height: 16),
          const Text('Reason for Delay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _delayReason,
            isExpanded: true,
            hint: const Text('Select a reason'),
            items: kLdrDelayReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setState(() => _delayReason = v),
          ),
          if (_delayReason == 'Other') ...[
            const SizedBox(height: 10),
            _field('Please specify', _delayReasonOtherController),
          ],
          const SizedBox(height: 20),
          _field("Deceased's Full Name", _deceasedNameController),
          const SizedBox(height: 16),
          const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: ['Male', 'Female', 'Other'].map((g) {
              final selected = _deceasedGender == g;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: g == 'Other' ? 0 : 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _deceasedGender = g),
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
          _field('Deceased CNIC (optional)', _deceasedCnicController, formatters: [CnicInputFormatter()], keyboardType: TextInputType.number, hint: '36602-3534535-7'),
          const SizedBox(height: 16),
          _field('Cause of Death (optional)', _causeOfDeathController),
          const SizedBox(height: 16),
          _field('Place of Death (optional)', _placeOfDeathController),
          const SizedBox(height: 16),
          _field('Burial Place (optional)', _burialPlaceController),
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
          const Text('Relation to Deceased', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _applicantRelation,
            isExpanded: true,
            items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _applicantRelation = v ?? 'Son'),
          ),
          const SizedBox(height: 14),
          _field('Address', _addressController),
          const SizedBox(height: 14),
          _field('Phone (optional)', _phoneController, formatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, hint: '0300-1234567'),
          if (_category == '7+') ...[
            const SizedBox(height: 24),
            const Text('Court Decree (Rule 13)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            _field('Court Decree No.', _courtDecreeNoController),
            const SizedBox(height: 14),
            _dateField('Court Decree Date', _courtDecreeDate, (d) => setState(() => _courtDecreeDate = d)),
            const SizedBox(height: 14),
            _field('Court Name', _courtNameController),
          ],
          if (_category == 'ABROAD') ...[
            const SizedBox(height: 24),
            const Text('Death Abroad Details (Rule 15)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 12),
            _field('Country of Death', _countryOfDeathController),
            const SizedBox(height: 14),
            _field('Passport No.', _passportNoController),
          ],
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
                child: LdrDocSlotTile(
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
          const SizedBox(height: 8),
          const Text('Secretary Remarks / Observations (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          TextField(controller: _remarksController, maxLines: 4),
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
          _reviewRow('Category', kLdrCategoryLabels[_category] ?? _category),
          _reviewRow('Deceased', _deceasedNameController.text),
          _reviewRow('Date of Death', _dateOfDeath != null ? _fmt(_dateOfDeath!) : '—'),
          _reviewRow('Delay', _delayYears != null ? '${_delayYears!.toStringAsFixed(1)} years' : '—'),
          _reviewRow('Applicant', '${_applicantNameController.text} · ${_applicantCnicController.text}'),
          _reviewRow('Documents Attached', '${_docs.length}'),
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
