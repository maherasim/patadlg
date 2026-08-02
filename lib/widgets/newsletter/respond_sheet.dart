import 'package:flutter/material.dart';

import '../../models/newsletter.dart';
import '../../services/newsletter_service.dart';
import '../../theme/app_theme.dart';

/// Mirrors the web app's RespondModal — pick one option, optional remarks.
/// Pops `true` on success so the caller knows to refresh the list.
class NewsletterRespondSheet extends StatefulWidget {
  const NewsletterRespondSheet({super.key, required this.role, required this.newsletter});

  final String role;
  final Newsletter newsletter;

  @override
  State<NewsletterRespondSheet> createState() => _NewsletterRespondSheetState();
}

class _NewsletterRespondSheetState extends State<NewsletterRespondSheet> {
  late int? _optionId = widget.newsletter.myResponse?.optionId;
  late final _remarksController = TextEditingController(text: widget.newsletter.myResponse?.remarks ?? '');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_optionId == null) {
      setState(() => _error = 'Select a response option.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await NewsletterService.instance.respond(
      role: widget.role,
      newsletterId: widget.newsletter.id,
      optionId: _optionId!,
      remarks: _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
    );

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 18),
              const Text('Respond to Directive', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(widget.newsletter.subject, style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              const SizedBox(height: 18),
              const Text('Your Response', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 8),
              ...widget.newsletter.options.map((o) {
                final selected = _optionId == o.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _optionId = o.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary50 : AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: selected ? AppColors.primary500 : AppColors.border, width: selected ? 1.6 : 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 18,
                            color: selected ? AppColors.primary500 : AppColors.inkFaint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              o.label,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? AppColors.primary700 : AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              const Text('Remarks (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
              const SizedBox(height: 8),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Add any context for the Super Admin…'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Submit Response'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
