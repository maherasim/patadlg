import 'package:flutter/material.dart';

import '../../models/dv_case.dart';
import '../../theme/app_theme.dart';

const _kStages = ['SUBMITTED', 'SEEN', 'NOTICE_ISSUED', 'ARB_CONSTITUTED', 'FINAL'];

const Map<String, String> _kStageLabels = {
  'SUBMITTED': 'Submitted to ADLG',
  'SEEN': 'Seen by ADLG',
  'NOTICE_ISSUED': 'Notice Issued',
  'ARB_CONSTITUTED': 'Arbitration Constituted',
  'FINAL': 'Final Decision',
};

/// The 5-stage case-workflow tracker, mirroring the web app's stepper
/// exactly: disposed cases show all 5 stages complete, IN_PROCEEDINGS sits
/// visually at the same position as ARB_CONSTITUTED (hearings happen after
/// arbitration, before a final decision).
class CaseStepper extends StatelessWidget {
  const CaseStepper({super.key, required this.dvCase});

  final DvCase dvCase;

  int get _currentIndex {
    if (dvCase.isDisposed) return 4;
    if (dvCase.status == 'IN_PROCEEDINGS') return 3;
    final idx = _kStages.indexOf(dvCase.status);
    return idx == -1 ? 0 : idx;
  }

  CaseTimelineEvent? _eventFor(String stage) {
    if (stage == 'FINAL') {
      for (final e in dvCase.timeline) {
        if (kDisposedCaseStatuses.contains(e.stage)) return e;
      }
      return null;
    }
    for (final e in dvCase.timeline) {
      if (e.stage == stage) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_kStages.length, (i) {
        final stage = _kStages[i];
        final done = i < current;
        final active = i == current;
        final event = _eventFor(stage);
        final isLast = i == _kStages.length - 1;

        final circleColor = done ? AppColors.primary500 : (active ? AppColors.accent500 : AppColors.surfaceSubtle);
        final circleBorder = done || active ? Colors.transparent : AppColors.border;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle, border: Border.all(color: circleBorder)),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : AppColors.inkFaint,
                              ),
                            ),
                    ),
                  ),
                  if (!isLast) Expanded(child: Container(width: 2, color: done ? AppColors.primary500 : AppColors.border)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _kStageLabels[stage] ?? stage,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: done || active ? AppColors.ink : AppColors.inkFaint,
                        ),
                      ),
                      if (event != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${event.eventDate}${event.actor != null ? ' · ${event.actor}' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.inkFaint),
                        ),
                        if (event.note != null && event.note!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(event.note!, style: const TextStyle(fontSize: 11, color: AppColors.inkMuted)),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
