import 'package:flutter/material.dart';

import '../../models/lbr_case.dart';
import '../../services/lbr_service.dart';
import '../../theme/app_theme.dart';

const _kDecisionOptions = [
  ('APPROVED', '✅ Approve'),
  ('REJECTED', '❌ Reject'),
  ('RETURNED', '↩️ Return'),
];

/// Shared ADLG/DDLG review sheet for a FORWARDED (ADLG) or
/// PENDING_DDLG_APPROVAL (DDLG) case. ADLG only captures an Order No. when
/// Approve is final for the case's category (1-7 years); DDLG's decision is
/// always final for the '7+' cases it ever sees, so Order No. is always
/// shown there when approving.
class LbrReviewSheet extends StatefulWidget {
  const LbrReviewSheet({super.key, required this.role, required this.lbrCase});

  final String role;
  final LbrCase lbrCase;

  @override
  State<LbrReviewSheet> createState() => _LbrReviewSheetState();
}

class _LbrReviewSheetState extends State<LbrReviewSheet> {
  String? _action;
  final _orderNoController = TextEditingController();
  final _observationsController = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _isDdlg => widget.role == 'ddlg';
  bool get _isFinalApproval => _isDdlg ? true : widget.lbrCase.category == '1-7';

  @override
  void dispose() {
    _orderNoController.dispose();
    _observationsController.dispose();
    super.dispose();
  }

  void _selectAction(String action) {
    setState(() {
      _action = action;
      if (action == 'APPROVED' && _isFinalApproval && _orderNoController.text.isEmpty) {
        final now = DateTime.now();
        _orderNoController.text = 'LBR-ORD-${now.year}-${now.millisecondsSinceEpoch.toString().substring(9)}';
      }
    });
  }

  Future<void> _submit() async {
    if (_action == null) {
      setState(() => _error = 'Please select a decision.');
      return;
    }
    if (_observationsController.text.trim().isEmpty) {
      setState(() => _error = 'Please add your observations.');
      return;
    }
    if (_action == 'APPROVED' && _isFinalApproval && _orderNoController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the order number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await LbrService.instance.review(
      role: widget.role,
      id: widget.lbrCase.id,
      action: _action!,
      observations: _observationsController.text.trim(),
      orderNo: (_action == 'APPROVED' && _isFinalApproval) ? _orderNoController.text.trim() : null,
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
    final showOrderNo = _action == 'APPROVED' && _isFinalApproval;
    final notFinalForAdlg = !_isDdlg && widget.lbrCase.category == '7+';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(_isDdlg ? 'Final Decision' : 'Review Decision', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              if (notFinalForAdlg) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                    "Over 7 years requires DDLG's final approval — Approve here forwards it, it does not register the case.",
                    style: TextStyle(fontSize: 11.5, color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text('Decision', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 8),
              ..._kDecisionOptions.map((opt) {
                final selected = _action == opt.$1;
                var label = opt.$2;
                if (opt.$1 == 'APPROVED' && notFinalForAdlg) label = '➡️ Forward to DDLG';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected ? AppColors.primary50 : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _selectAction(opt.$1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? AppColors.primary400 : AppColors.border)),
                        child: Row(
                          children: [
                            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, size: 18, color: selected ? AppColors.primary600 : AppColors.inkFaint),
                            const SizedBox(width: 10),
                            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.primary700 : AppColors.ink)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (showOrderNo) ...[
                const SizedBox(height: 10),
                const Text('Order No.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                const SizedBox(height: 8),
                TextField(controller: _orderNoController),
              ],
              const SizedBox(height: 16),
              const Text('Observations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 8),
              TextField(controller: _observationsController, maxLines: 3),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Submit Decision'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
