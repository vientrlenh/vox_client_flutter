import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../app/widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/onboarding_question.dart';

/// Real forced-choice interest triplet — backs `interestQuizItems`/
/// `submitInterestQuiz`, NOT the onboarding topic-chip mockup.
class InterestQuizStep extends StatelessWidget {
  const InterestQuizStep({
    super.key,
    required this.item,
    required this.mostIndex,
    required this.leastIndex,
    required this.canGoBack,
    required this.onPickMost,
    required this.onPickLeast,
    required this.onBack,
    required this.onContinue,
  });

  final InterestQuizItem item;
  final int? mostIndex;
  final int? leastIndex;
  final bool canGoBack;
  final ValueChanged<int> onPickMost;
  final ValueChanged<int> onPickLeast;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  bool get _canContinue =>
      mostIndex != null && leastIndex != null && mostIndex != leastIndex;

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
                l10n.pzInterestQuizHeading,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pzInterestQuizBody,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              for (int i = 0; i < item.statements.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _StatementRow(
                  label: item.statements[i],
                  isMost: mostIndex == i,
                  isLeast: leastIndex == i,
                  onPickMost: () => onPickMost(i),
                  onPickLeast: () => onPickLeast(i),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (canGoBack) ...[
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF555555),
                        side: const BorderSide(
                          color: Color(0xFFE6E6E6),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(99),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(l10n.pzOnboardingBack),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: l10n.pzOnboardingContinue,
                  icon: Icons.arrow_forward,
                  onTap: _canContinue ? onContinue : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.label,
    required this.isMost,
    required this.isLeast,
    required this.onPickMost,
    required this.onPickLeast,
  });

  final String label;
  final bool isMost;
  final bool isLeast;
  final VoidCallback onPickMost;
  final VoidCallback onPickLeast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final highlighted = isMost || isLeast;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMost
            ? AppColors.chipBlueBg
            : (isLeast ? const Color(0xFFFDECEC) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMost
              ? AppColors.indigo
              : (isLeast ? AppColors.danger : AppColors.border),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PickChip(
                  label: l10n.pzInterestQuizMostLike,
                  icon: Icons.thumb_up_alt_outlined,
                  selected: isMost,
                  color: AppColors.indigo,
                  onTap: onPickMost,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PickChip(
                  label: l10n.pzInterestQuizLeastLike,
                  icon: Icons.thumb_down_alt_outlined,
                  selected: isLeast,
                  color: AppColors.danger,
                  onTap: onPickLeast,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.fieldBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
