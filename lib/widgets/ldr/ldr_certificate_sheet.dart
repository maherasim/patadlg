import 'package:flutter/material.dart';

import '../../services/death_case_service.dart';
import '../../theme/app_theme.dart';

String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Secretary-only — registers the death certificate once a case is APPROVED.
/// This is the terminal action; the case locks afterward.
class LdrCertificateSheet extends StatefulWidget {
  const LdrCertificateSheet({super.key, required this.caseId});

  final int caseId;

  @override
  State<LdrCertificateSheet> createState() => _LdrCertificateSheetState();
}

class _LdrCertificateSheetState extends State<LdrCertificateSheet> {
  final _certificateNoController = TextEditingController();
  DateTime _certificateDate = DateTime.now();
  final _remarksController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _certificateNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_certificateNoController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the certificate number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await DeathCaseService.instance.registerCertificate(
      id: widget.caseId,
      certificateNo: _certificateNoController.text.trim(),
      certificateDate: _fmt(_certificateDate),
      certificateRemarks: _remarksController.text.trim(),
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
            const Text('Issue Certificate & Lock File', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('This locks the case once registered.', style: TextStyle(fontSize: 12, color: AppColors.inkMuted)),
            const SizedBox(height: 18),
            const Text('Certificate Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            TextField(controller: _certificateNoController, decoration: const InputDecoration(hintText: 'DC-2026-UC1-001')),
            const SizedBox(height: 16),
            const Text('Certificate Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _certificateDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (picked != null) setState(() => _certificateDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Text(_fmt(_certificateDate), style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Remarks (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            TextField(controller: _remarksController, maxLines: 3),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('Issue Certificate'),
            ),
          ],
        ),
      ),
    );
  }
}
