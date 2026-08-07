import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../schedule/data/models/exam_schedule.dart';

String examStatusLabel(ExamLifecycleStatus status, AppLocalizations l10n) {
  switch (status) {
    case ExamLifecycleStatus.draft:
      return l10n.teacherExamStatusDraft;
    case ExamLifecycleStatus.scheduled:
      return l10n.teacherExamStatusScheduled;
    case ExamLifecycleStatus.inProgress:
      return l10n.teacherExamStatusInProgress;
    case ExamLifecycleStatus.closed:
      return l10n.teacherExamStatusClosed;
    case ExamLifecycleStatus.resultsPublished:
      return l10n.teacherExamStatusResultsPublished;
    case ExamLifecycleStatus.cancelled:
      return l10n.teacherExamStatusCancelled;
  }
}

TagChip examStatusChip(ExamLifecycleStatus status, AppLocalizations l10n) {
  switch (status) {
    case ExamLifecycleStatus.inProgress:
      return TagChip(
        examStatusLabel(status, l10n),
        bg: AppColors.chipGreenBg,
        fg: AppColors.chipGreenFg,
        dot: true,
      );
    case ExamLifecycleStatus.scheduled:
      return TagChip(
        examStatusLabel(status, l10n),
        bg: AppColors.chipBlueBg,
        fg: AppColors.chipBlueFg,
        dot: true,
      );
    case ExamLifecycleStatus.draft:
      return TagChip(
        examStatusLabel(status, l10n),
        bg: AppColors.chipNeutralBg,
        fg: AppColors.chipNeutralFg,
      );
    case ExamLifecycleStatus.cancelled:
      return TagChip(
        examStatusLabel(status, l10n),
        bg: AppColors.dangerBg,
        fg: AppColors.danger,
      );
    case ExamLifecycleStatus.closed:
    case ExamLifecycleStatus.resultsPublished:
      return TagChip(
        examStatusLabel(status, l10n),
        bg: AppColors.statusClosedBg,
        fg: AppColors.statusClosedFg,
      );
  }
}

/// Next valid status actions per the backend's state machine
/// (UpdateExamStatusUseCase): SCHEDULE|START|CLOSE|PUBLISH_RESULTS|CANCEL.
List<MapEntry<String, String>> nextStatusActions(
  ExamLifecycleStatus status,
  AppLocalizations l10n,
) {
  switch (status) {
    case ExamLifecycleStatus.draft:
      return [
        MapEntry('SCHEDULE', l10n.teacherExamActionSchedule),
        MapEntry('CANCEL', l10n.teacherExamActionCancel),
      ];
    case ExamLifecycleStatus.scheduled:
      return [
        MapEntry('START', l10n.teacherExamActionStart),
        MapEntry('CANCEL', l10n.teacherExamActionCancel),
      ];
    case ExamLifecycleStatus.inProgress:
      return [MapEntry('CLOSE', l10n.teacherExamActionClose)];
    case ExamLifecycleStatus.closed:
      return [MapEntry('PUBLISH_RESULTS', l10n.teacherExamActionPublishResults)];
    case ExamLifecycleStatus.resultsPublished:
    case ExamLifecycleStatus.cancelled:
      return const [];
  }
}

/// Full date + hours:minutes, locale-aware (e.g. "Jul 20, 2026 09:00").
String examDateTimeLabel(BuildContext context, DateTime? d, String notSetLabel) {
  if (d == null) return notSetLabel;
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMMMd(locale).add_Hm().format(d);
}

/// White bordered card used to group detail fields, matching the app's
/// exam/appeal card style (radius 16, `#E2E8F0` border).
class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Label/value row for a [DetailCard] (e.g. "Opens: Jul 20, 2026").
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.dark,
            ),
          ),
        ],
      ),
    );
  }
}
