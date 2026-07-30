import 'package:flutter/material.dart';

import '../../services/case_service.dart';
import '../../theme/app_theme.dart';

String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// ADLG-only — issues a notice to both parties once a case has been seen.
class IssueNoticeSheet extends StatefulWidget {
  const IssueNoticeSheet({super.key, required this.caseId});

  final int caseId;

  @override
  State<IssueNoticeSheet> createState() => _IssueNoticeSheetState();
}

class _IssueNoticeSheetState extends State<IssueNoticeSheet> {
  final _noticeNoController = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime? _hearingDate;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noticeNoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(DateTime initial, DateTime firstDate, ValueChanged<DateTime> onPicked) async {
    final picked = await showDatePicker(context: context, initialDate: initial, firstDate: firstDate, lastDate: DateTime(2100));
    if (picked != null) onPicked(picked);
  }

  Future<void> _submit() async {
    if (_noticeNoController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the notice reference number.');
      return;
    }
    if (_hearingDate == null) {
      setState(() => _error = 'Please pick a hearing date.');
      return;
    }
    if (_hearingDate!.isBefore(_issueDate)) {
      setState(() => _error = 'Hearing date must be on or after the issue date.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await CaseService.instance.issueNotice(
      caseId: widget.caseId,
      noticeNo: _noticeNoController.text.trim(),
      issueDate: _fmt(_issueDate),
      hearingDate: _fmt(_hearingDate!),
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
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            const Text('Issue Notice to Parties', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 18),
            const Text('Notice Reference No.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            TextField(controller: _noticeNoController),
            const SizedBox(height: 16),
            _dateField('Issue Date', _issueDate, (d) => setState(() => _issueDate = d), firstDate: DateTime(2020)),
            const SizedBox(height: 16),
            _dateField('Hearing Date', _hearingDate, (d) => setState(() => _hearingDate = d), firstDate: _issueDate),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Issue Notice'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPicked, {required DateTime firstDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickDate(value ?? firstDate, firstDate, onPicked),
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
