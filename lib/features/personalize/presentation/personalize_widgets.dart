import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/learner_profile.dart';
import 'personalize_styles.dart';

/// The load-failure state shared by every personalize screen — mirrors the
/// message + `Retry` pattern used across the rest of the app.
class PersonalizeErrorView extends StatelessWidget {
  const PersonalizeErrorView({super.key, this.detail, required this.onRetry});

  /// Optional exception text appended under the generic message.
  final String? detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              detail == null
                  ? l10n.pzLoadError
                  : '${l10n.pzLoadError}\n$detail',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: Text(l10n.pzRetry)),
          ],
        ),
      ),
    );
  }
}

/// The weighted five-criteria rubric card — used by the session summary and by
/// the onboarding learning-profile step.
class RubricCard extends StatelessWidget {
  const RubricCard({super.key, required this.rubric, this.trailing});

  final List<RubricCriterion> rubric;

  /// Optional right-hand widget in the header; the onboarding screen puts the
  /// overall score there, the summary puts the legend.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: SectionLabel(l10n.pzSummaryRubric)),
                trailing ??
                    Text(
                      l10n.pzSummaryRubricLegend,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          for (int i = 0; i < rubric.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                9,
                0,
                i == rubric.length - 1 ? 12 : 9,
              ),
              child: MeterRow(
                label: rubric[i].label,
                weight: '${rubric[i].weight}%',
                ratio: rubric[i].score / 100,
                value: rubric[i].score.toStringAsFixed(1),
                barColor: rubric[i].isWeak
                    ? AppColors.warning
                    : AppColors.indigo,
                valueColor: rubric[i].isWeak
                    ? AppColors.warnFg
                    : AppColors.dark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Selectable pill used by the topic filters and the progress range switcher.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.ink : AppColors.fieldBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active ? Colors.white : AppColors.chipNeutralFg,
            ),
          ),
        ),
      ),
    );
  }
}
