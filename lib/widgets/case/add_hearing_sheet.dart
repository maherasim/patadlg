import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/case_service.dart';
import '../../theme/app_theme.dart';

/// Records a hearing — shared by both roles, matching the web app's
/// AddHearingForm exactly. A party marked present requires a photo of them
/// (server enforces this too; checked here first for a faster error).
class AddHearingSheet extends StatefulWidget {
  const AddHearingSheet({super.key, required this.role, required this.caseId});

  final String role;
  final int caseId;

  @override
  State<AddHearingSheet> createState() => _AddHearingSheetState();
}

class _AddHearingSheetState extends State<AddHearingSheet> {
  DateTime _date = DateTime.now();
  final _venueController = TextEditingController(text: 'UC Office');

  bool _petitionerPresent = false;
  bool _respondentPresent = false;
  bool _petitionerBiometric = false;
  bool _respondentBiometric = false;
  File? _petitionerPhoto;
  File? _respondentPhoto;

  final _petStatementController = TextEditingController();
  final _resStatementController = TextEditingController();
  final _reconciliationController = TextEditingController();

  bool _adjourned = false;
  final _adjournReasonController = TextEditingController();
  DateTime? _nextHearingDate;

  bool _noticeIssued = false;
  final _noticeRefController = TextEditingController();
  DateTime? _noticeDate;
  final _noticeDetailsController = TextEditingController();

  final _observationController = TextEditingController();
  final _directionController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _venueController.dispose();
    _petStatementController.dispose();
    _resStatementController.dispose();
    _reconciliationController.dispose();
    _adjournReasonController.dispose();
    _noticeRefController.dispose();
    _noticeDetailsController.dispose();
    _observationController.dispose();
    _directionController.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _capturePhoto({required bool forPetitioner}) async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear, imageQuality: 75, maxWidth: 1280);
    if (photo == null) return;
    setState(() {
      if (forPetitioner) {
        _petitionerPhoto = File(photo.path);
      } else {
        _respondentPhoto = File(photo.path);
      }
    });
  }

  Future<void> _pickDate(DateTime? current, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (_petitionerPresent && _petitionerPhoto == null) {
      setState(() => _error = 'A photo of the petitioner is required when marking them present.');
      return;
    }
    if (_respondentPresent && _respondentPhoto == null) {
      setState(() => _error = 'A photo of the respondent is required when marking them present.');
      return;
    }
    if (_adjourned && _adjournReasonController.text.trim().isEmpty) {
      setState(() => _error = 'Please add a reason for the adjournment.');
      return;
    }
    if (_adjourned && _nextHearingDate == null) {
      setState(() => _error = 'Please pick the next hearing date.');
      return;
    }
    if (_noticeIssued && (_noticeRefController.text.trim().isEmpty || _noticeDate == null)) {
      setState(() => _error = 'Please add the notice reference and date.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await CaseService.instance.addProceeding(
      role: widget.role,
      caseId: widget.caseId,
      date: _fmt(_date),
      venue: _venueController.text.trim(),
      petitionerPresent: _petitionerPresent,
      respondentPresent: _respondentPresent,
      petitionerBiometric: _petitionerBiometric,
      respondentBiometric: _respondentBiometric,
      petitionerPhoto: _petitionerPhoto,
      respondentPhoto: _respondentPhoto,
      petStatement: _petStatementController.text.trim(),
      resStatement: _resStatementController.text.trim(),
      reconciliation: _reconciliationController.text.trim(),
      adjourned: _adjourned,
      adjournReason: _adjourned ? _adjournReasonController.text.trim() : null,
      nextHearingDate: _adjourned && _nextHearingDate != null ? _fmt(_nextHearingDate!) : null,
      noticeIssued: _noticeIssued,
      noticeRef: _noticeIssued ? _noticeRefController.text.trim() : null,
      noticeDate: _noticeIssued && _noticeDate != null ? _fmt(_noticeDate!) : null,
      noticeDetails: _noticeDetailsController.text.trim(),
      adlgObservation: _observationController.text.trim(),
      adlgDirection: _directionController.text.trim(),
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
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  const Text('Record Hearing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField('Hearing Date', _date, (d) => setState(() => _date = d)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Venue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                            const SizedBox(height: 8),
                            TextField(controller: _venueController),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _partyBlock(
                    title: 'Petitioner',
                    present: _petitionerPresent,
                    biometric: _petitionerBiometric,
                    photo: _petitionerPhoto,
                    onPresentChanged: (v) => setState(() => _petitionerPresent = v),
                    onBiometricChanged: (v) => setState(() => _petitionerBiometric = v),
                    onCapture: () => _capturePhoto(forPetitioner: true),
                    onRetake: () => setState(() => _petitionerPhoto = null),
                  ),
                  const SizedBox(height: 16),
                  _partyBlock(
                    title: 'Respondent',
                    present: _respondentPresent,
                    biometric: _respondentBiometric,
                    photo: _respondentPhoto,
                    onPresentChanged: (v) => setState(() => _respondentPresent = v),
                    onBiometricChanged: (v) => setState(() => _respondentBiometric = v),
                    onCapture: () => _capturePhoto(forPetitioner: false),
                    onRetake: () => setState(() => _respondentPhoto = null),
                  ),
                  const SizedBox(height: 20),
                  _textField('Petitioner Statement', _petStatementController, maxLines: 3),
                  const SizedBox(height: 12),
                  _textField('Respondent Statement', _resStatementController, maxLines: 3),
                  const SizedBox(height: 12),
                  _textField('Reconciliation Effort', _reconciliationController, maxLines: 3),
                  const SizedBox(height: 18),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Adjourned', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    value: _adjourned,
                    onChanged: (v) => setState(() => _adjourned = v),
                  ),
                  if (_adjourned) ...[
                    _textField('Reason', _adjournReasonController, maxLines: 2),
                    const SizedBox(height: 12),
                    _dateField('Next Hearing Date', _nextHearingDate, (d) => setState(() => _nextHearingDate = d)),
                  ],
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notice Issued', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                    value: _noticeIssued,
                    onChanged: (v) => setState(() => _noticeIssued = v),
                  ),
                  if (_noticeIssued) ...[
                    _textField('Notice Reference No.', _noticeRefController),
                    const SizedBox(height: 12),
                    _dateField('Notice Date', _noticeDate, (d) => setState(() => _noticeDate = d)),
                    const SizedBox(height: 12),
                    _textField('Notice Details', _noticeDetailsController, maxLines: 2),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Note / Order for This Hearing', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        const SizedBox(height: 12),
                        _textField('Note (observations)', _observationController, maxLines: 3),
                        const SizedBox(height: 12),
                        _textField('Order (any direction issued)', _directionController, maxLines: 3),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('Save Hearing'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partyBlock({
    required String title,
    required bool present,
    required bool biometric,
    required File? photo,
    required ValueChanged<bool> onPresentChanged,
    required ValueChanged<bool> onBiometricChanged,
    required VoidCallback onCapture,
    required VoidCallback onRetake,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text('Present', style: TextStyle(fontSize: 12.5)),
                  value: present,
                  onChanged: (v) => onPresentChanged(v ?? false),
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  title: const Text('Biometric', style: TextStyle(fontSize: 12.5)),
                  value: biometric,
                  onChanged: (v) => onBiometricChanged(v ?? false),
                ),
              ),
            ],
          ),
          if (present) ...[
            const SizedBox(height: 6),
            if (photo == null)
              OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Take Photo (required)'),
              )
            else
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(photo, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  TextButton(onPressed: onRetake, child: const Text('Retake')),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _textField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        TextField(controller: controller, maxLines: maxLines),
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
          onTap: () => _pickDate(value, onPicked),
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
