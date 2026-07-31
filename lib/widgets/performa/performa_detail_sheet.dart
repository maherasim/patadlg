import 'package:flutter/material.dart';

import '../../models/performa.dart';
import '../../theme/app_theme.dart';

/// Read-only "View Details" for a Performa — title, description, mode,
/// frequency, deadline, and the field/template definition, distinct from
/// [PerformaResponsesSheet] which shows secretary submissions.
class PerformaDetailSheet extends StatelessWidget {
  const PerformaDetailSheet({super.key, required this.performa});

  final Performa performa;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
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
            Text(performa.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(performa.isExcelMode ? 'Excel Template' : 'In-app Form', AppColors.info),
                _badge(performa.isDaily ? 'Daily' : 'One-time', performa.isDaily ? AppColors.warning : AppColors.inkMuted),
                if (performa.deadline != null) _badge('Due ${performa.deadline!.split('T').first}', AppColors.inkMuted),
              ],
            ),
            if (performa.description != null && performa.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.surfaceSubtle, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Description', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    Text(performa.description!, style: const TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (performa.isExcelMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                child: Text(
                  performa.hasTemplate ? '📊 Excel template attached' : 'No template attached',
                  style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fields (${performa.fields.length})', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.inkFaint, letterSpacing: 0.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: performa.fields.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(8)),
                          child: Text('${f.label} · ${f.type}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.primary700)),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text('${performa.responsesCount ?? 0} response(s) so far', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
