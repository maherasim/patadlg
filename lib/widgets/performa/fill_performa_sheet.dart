import 'package:flutter/material.dart';

import '../../models/performa.dart';
import '../../services/performa_service.dart';
import '../../theme/app_theme.dart';

/// Secretary-only — fills a form-mode Performa's dynamic fields in-app.
/// Pre-fills from any existing response for today (the backend upserts by
/// secretary+date, so re-opening this after submitting edits in place).
class FillPerformaSheet extends StatefulWidget {
  const FillPerformaSheet({super.key, required this.performa});

  final Performa performa;

  @override
  State<FillPerformaSheet> createState() => _FillPerformaSheetState();
}

class _FillPerformaSheetState extends State<FillPerformaSheet> {
  final Map<int, TextEditingController> _controllers = {};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final field in widget.performa.fields) {
      String existingValue = '';
      for (final v in widget.performa.myResponse?.values ?? const []) {
        if (v.fieldId == field.id) {
          existingValue = v.value;
          break;
        }
      }
      _controllers[field.id] = TextEditingController(text: existingValue);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    final values = <int, String>{for (final entry in _controllers.entries) entry.key: entry.value.text.trim()};

    final result = await PerformaService.instance.respondForm(performaId: widget.performa.id, values: values);

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() {
        _submitting = false;
        _error = result.errorMessage;
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  TextInputType _keyboardFor(String type) {
    if (type == 'number') return TextInputType.number;
    return TextInputType.text;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              Text(widget.performa.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              if (widget.performa.description != null && widget.performa.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(widget.performa.description!, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ],
              const SizedBox(height: 18),
              ...widget.performa.fields.map((field) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                        const SizedBox(height: 8),
                        if (field.type == 'date')
                          _dateField(field.id)
                        else
                          TextField(controller: _controllers[field.id], keyboardType: _keyboardFor(field.type)),
                      ],
                    ),
                  )),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField(int fieldId) {
    final controller = _controllers[fieldId]!;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1950), lastDate: DateTime(2100));
        if (picked != null) {
          controller.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, _) => Text(
            controller.text.isEmpty ? 'Select date' : controller.text,
            style: TextStyle(fontSize: 13.5, color: controller.text.isEmpty ? AppColors.inkFaint : AppColors.ink, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
