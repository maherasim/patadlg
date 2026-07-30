import 'package:flutter/material.dart';

import '../../models/dv_case.dart';
import '../../theme/app_theme.dart';
import 'document_preview.dart';

/// Read-only hearing history — mirrors the web app's ProceedingsList exactly.
class ProceedingsList extends StatelessWidget {
  const ProceedingsList({super.key, required this.proceedings});

  final List<CaseProceeding> proceedings;

  @override
  Widget build(BuildContext context) {
    if (proceedings.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No hearings recorded yet.', style: TextStyle(fontSize: 12.5, color: AppColors.inkFaint)),
      );
    }

    return Column(
      children: proceedings.asMap().entries.map((entry) {
        final index = entry.key;
        final p = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Hearing ${index + 1} · ${p.procNo}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  ),
                  Text(p.date, style: const TextStyle(fontSize: 11.5, color: AppColors.inkFaint)),
                ],
              ),
              const SizedBox(height: 8),
              _presenceRow(context, 'Petitioner', p.petitionerPresent, p.petitionerBiometric, p.petitionerPhotoUrl),
              const SizedBox(height: 6),
              _presenceRow(context, 'Respondent', p.respondentPresent, p.respondentBiometric, p.respondentPhotoUrl),
              if (p.reconciliation != null && p.reconciliation!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Reconciliation: ${p.reconciliation}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ],
              if (p.adjourned) ...[
                const SizedBox(height: 8),
                Text('Adjourned — Next hearing: ${p.nextHearingDate ?? '—'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warning)),
              ],
              if (p.noticeIssued) ...[
                const SizedBox(height: 8),
                Text('Notice ${p.noticeRef ?? ''} issued ${p.noticeDate ?? ''}', style: const TextStyle(fontSize: 12, color: AppColors.inkMuted)),
              ],
              if (p.adlgObservation != null && p.adlgObservation!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _noteBox('Note', p.adlgObservation!, AppColors.info),
              ],
              if (p.adlgDirection != null && p.adlgDirection!.isNotEmpty) ...[
                const SizedBox(height: 6),
                _noteBox('Order', p.adlgDirection!, AppColors.primary600),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _presenceRow(BuildContext context, String label, bool present, bool biometric, String? photoUrl) {
    return Row(
      children: [
        if (photoUrl != null)
          GestureDetector(
            onTap: () => openDocument(context, photoUrl),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              clipBehavior: Clip.hardEdge,
              child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.person_rounded, size: 16)),
            ),
          ),
        Expanded(
          child: Text(
            '$label: ${present ? 'Present' : 'Absent'}${present && biometric ? ' ✓' : ''}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: present ? AppColors.ink : AppColors.inkFaint),
          ),
        ),
      ],
    );
  }

  Widget _noteBox(String label, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11.5, color: AppColors.ink, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
