import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/case_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/pk_formatters.dart';

/// Secretary-only — forms the arbitration council once a notice has been
/// issued. No ADLG equivalent action exists for this step.
class ConstituteArbitrationSheet extends StatefulWidget {
  const ConstituteArbitrationSheet({super.key, required this.caseId});

  final int caseId;

  @override
  State<ConstituteArbitrationSheet> createState() => _ConstituteArbitrationSheetState();
}

class _ConstituteArbitrationSheetState extends State<ConstituteArbitrationSheet> {
  final _husbandNameController = TextEditingController();
  final _husbandCnicController = TextEditingController();
  final _husbandPhoneController = TextEditingController();
  final _husbandDesignationController = TextEditingController();
  final _wifeNameController = TextEditingController();
  final _wifeCnicController = TextEditingController();
  final _wifePhoneController = TextEditingController();
  final _wifeDesignationController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _husbandNameController.dispose();
    _husbandCnicController.dispose();
    _husbandPhoneController.dispose();
    _husbandDesignationController.dispose();
    _wifeNameController.dispose();
    _wifeCnicController.dispose();
    _wifePhoneController.dispose();
    _wifeDesignationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_husbandNameController.text.trim().isEmpty || _husbandCnicController.text.trim().isEmpty) {
      setState(() => _error = "Please add the husband's representative name and CNIC.");
      return;
    }
    if (_wifeNameController.text.trim().isEmpty || _wifeCnicController.text.trim().isEmpty) {
      setState(() => _error = "Please add the wife's representative name and CNIC.");
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await CaseService.instance.constituteArbitration(
      caseId: widget.caseId,
      husbandRepName: _husbandNameController.text.trim(),
      husbandRepCnic: _husbandCnicController.text.trim(),
      husbandRepPhone: _husbandPhoneController.text.trim(),
      husbandRepDesignation: _husbandDesignationController.text.trim(),
      wifeRepName: _wifeNameController.text.trim(),
      wifeRepCnic: _wifeCnicController.text.trim(),
      wifeRepPhone: _wifePhoneController.text.trim(),
      wifeRepDesignation: _wifeDesignationController.text.trim(),
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
      initialChildSize: 0.75,
      maxChildSize: 0.92,
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  const Text('Constitute Arbitration Council', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 18),
                  _repFields(
                    title: "Husband's Representative",
                    name: _husbandNameController,
                    cnic: _husbandCnicController,
                    phone: _husbandPhoneController,
                    designation: _husbandDesignationController,
                  ),
                  const SizedBox(height: 20),
                  _repFields(
                    title: "Wife's Representative",
                    name: _wifeNameController,
                    cnic: _wifeCnicController,
                    phone: _wifePhoneController,
                    designation: _wifeDesignationController,
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
                        : const Text('Constitute Arbitration'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _repFields({
    required String title,
    required TextEditingController name,
    required TextEditingController cnic,
    required TextEditingController phone,
    required TextEditingController designation,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
        const SizedBox(height: 10),
        _field('Full Name', name),
        const SizedBox(height: 10),
        _field('CNIC', cnic, formatters: [CnicInputFormatter()], keyboardType: TextInputType.number, hint: '12345-1234567-1'),
        const SizedBox(height: 10),
        _field('Phone (optional)', phone, formatters: [PhoneInputFormatter()], keyboardType: TextInputType.phone, hint: '0300-1234567'),
        const SizedBox(height: 10),
        _field('Relation (optional)', designation),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller, {List<TextInputFormatter>? formatters, TextInputType? keyboardType, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          inputFormatters: formatters,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
