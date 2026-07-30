import 'package:flutter/material.dart';

import '../../services/case_service.dart';
import '../../theme/app_theme.dart';

const _kDecisionOptions = [
  ('DISPOSED_RECONCILED', '✅ Reconciled'),
  ('DISPOSED_EFFECTIVE', '⚖️ Effective'),
  ('FILED_NON_RESPONSE', '📁 Filed — Non-Response'),
];

/// ADLG-only — the terminal action that closes a case for good.
class PassDecisionSheet extends StatefulWidget {
  const PassDecisionSheet({super.key, required this.caseId});

  final int caseId;

  @override
  State<PassDecisionSheet> createState() => _PassDecisionSheetState();
}

class _PassDecisionSheetState extends State<PassDecisionSheet> {
  String? _type;
  final _orderNoController = TextEditingController();
  final _remarksController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _orderNoController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_type == null) {
      setState(() => _error = 'Please select a decision outcome.');
      return;
    }
    if (_orderNoController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the order number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await CaseService.instance.passDecision(
      caseId: widget.caseId,
      type: _type!,
      orderNo: _orderNoController.text.trim(),
      remarks: _remarksController.text.trim(),
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
            const Text('Pass Final Decision', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text(
              'This closes the case — it cannot be reopened afterward.',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const SizedBox(height: 18),
            const Text('Outcome', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            ..._kDecisionOptions.map((opt) {
              final selected = _type == opt.$1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected ? AppColors.primary50 : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _type = opt.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? AppColors.primary400 : AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 18,
                            color: selected ? AppColors.primary600 : AppColors.inkFaint,
                          ),
                          const SizedBox(width: 10),
                          Text(opt.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary700 : AppColors.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            const Text('Order No.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
            const SizedBox(height: 8),
            TextField(controller: _orderNoController),
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
                  : const Text('Pass Decision'),
            ),
          ],
        ),
      ),
    );
  }
}
