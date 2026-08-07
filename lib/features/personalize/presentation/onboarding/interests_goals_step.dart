import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/onboarding_question.dart';
import '../personalize_styles.dart';

/// Design `1a`, screen 3 — pick topics to talk about and one main goal.
class InterestsGoalsStep extends StatelessWidget {
  const InterestsGoalsStep({
    super.key,
    required this.choices,
    required this.goals,
    required this.selectedInterests,
    required this.selectedGoalId,
    required this.submitting,
    required this.onToggleInterest,
    required this.onSelectGoal,
    required this.onContinue,
  });

  /// The design asks for at least three topics before continuing.
  static const minimumInterests = 3;

  final List<InterestChoice> choices;
  final List<LearningGoal> goals;
  final Set<String> selectedInterests;
  final String? selectedGoalId;
  final bool submitting;
  final ValueChanged<String> onToggleInterest;
  final ValueChanged<String> onSelectGoal;
  final VoidCallback onContinue;

  bool get _canContinue => selectedInterests.length >= minimumInterests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                l10n.pzOnboardingInterestsHeading,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pzOnboardingInterestsBody,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in choices)
                    _TopicChip(
                      choice: choice,
                      selected: selectedInterests.contains(choice.id),
                      onTap: () => onToggleInterest(choice.id),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SectionLabel(l10n.pzOnboardingMainGoal),
              const SizedBox(height: 10),
              for (final goal in goals) ...[
                _GoalTile(
                  goal: goal,
                  selected: goal.id == selectedGoalId,
                  onTap: () => onSelectGoal(goal.id),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: submitting
              ? const SizedBox(
                  height: 54,
                  child: Center(child: CircularProgressIndicator()),
                )
              : GradientButton(
                  label: _canContinue
                      ? l10n.pzOnboardingContinueWithCount(
                          selectedInterests.length,
                        )
                      : l10n.pzOnboardingPickThree,
                  onTap: _canContinue ? onContinue : null,
                ),
        ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final InterestChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.indigo : AppColors.fieldBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            // The emoji only appears once the chip is picked, as in the design.
            selected ? '${choice.emoji} ${choice.label}' : choice.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? Colors.white : AppColors.chipNeutralFg,
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final LearningGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppColors.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForName(goal.icon),
                size: 22,
                color: selected ? AppColors.indigo : const Color(0xFF555555),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    goal.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? AppColors.muted : AppColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, size: 22, color: AppColors.indigo),
            ],
          ],
        ),
      ),
    );
  }
}
