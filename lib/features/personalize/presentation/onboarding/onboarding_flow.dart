import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/storage/preference_storage.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/models/onboarding_question.dart';
import '../../data/personalize_repository.dart';
import '../personalize_widgets.dart';
import 'interest_quiz_step.dart';

/// Design `1a` — the questionnaire that builds the learner profile.
///
/// FLAS/self-report step removed by product decision (2026-08-02) -- straight
/// to the REAL forced-choice interest quiz (`interestQuizItems`/
/// `submitInterestQuiz`, NOT `PersonalizeDemoData`, this is what actually
/// seeds `dimension_interest_score`). The old fake topic-chip/goal-tile step
/// and the fabricated CEFR/roadmap profile summary screen (`LearnerProfileStep`)
/// had no real backend behind them and were dropped rather than wired to fake
/// data.
///
/// Pops `true` once the quiz has been submitted. If `interestQuizItems` comes
/// back empty (LLM/network hiccup -- the backend's own fallback to the static
/// seed pool means a genuinely-empty result should never happen in practice),
/// this shows a retry state instead of silently finishing: silently marking
/// onboarding "done" here would permanently strand the student with an empty
/// interest vector on this device, with no automatic way back in.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _repository = PersonalizeRepository();
  final _preferences = PreferenceStorage();

  bool _loading = true;
  String? _error;

  List<InterestQuizItem> _quizItems = const [];

  /// Quiz item id → chosen statement index.
  final Map<String, int> _mostByItem = {};
  final Map<String, int> _leastByItem = {};

  int _step = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quizItems = await _repository.getInterestQuizItems();
      if (!mounted) return;
      setState(() => _quizItems = quizItems);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _step--);
  }

  void _next() {
    if (_step < _quizItems.length - 1) {
      setState(() => _step++);
      return;
    }
    _submitQuiz();
  }

  Future<void> _submitQuiz() async {
    setState(() => _submitting = true);
    try {
      final answers = [
        for (final item in _quizItems)
          InterestQuizAnswer(
            itemId: item.id,
            mostStatementIndex: _mostByItem[item.id]!,
            leastStatementIndex: _leastByItem[item.id]!,
          ),
      ];
      await _repository.submitInterestQuiz(answers);
      await _finish();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _finish() async {
    await _preferences.savePracticeOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading || _submitting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: PersonalizeErrorView(detail: _error, onRetry: _load),
      );
    }
    if (_quizItems.isEmpty) {
      // Never silently finish on empty -- see class doc comment. Let the
      // student retry instead of getting permanently stuck with no vector.
      return Scaffold(
        appBar: AppBar(),
        body: PersonalizeErrorView(onRetry: _load),
      );
    }

    final item = _quizItems[_step];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(
              title: l10n.pzInterestQuizTitle,
              counter: l10n.pzOnboardingProgress(_step + 1, _quizItems.length),
              progress: (_step + 1) / _quizItems.length,
              onBack: _back,
            ),
            Expanded(
              child: InterestQuizStep(
                item: item,
                mostIndex: _mostByItem[item.id],
                leastIndex: _leastByItem[item.id],
                canGoBack: _step > 0,
                onPickMost: (index) => setState(() {
                  _mostByItem[item.id] = index;
                  if (_leastByItem[item.id] == index) {
                    _leastByItem.remove(item.id);
                  }
                }),
                onPickLeast: (index) => setState(() {
                  _leastByItem[item.id] = index;
                  if (_mostByItem[item.id] == index) {
                    _mostByItem.remove(item.id);
                  }
                }),
                onBack: _back,
                onContinue: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared header: back button, title, counter and the gradient progress bar.
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.title,
    required this.counter,
    required this.progress,
    required this.onBack,
  });

  final String title;
  final String? counter;
  final double progress;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 20,
                    color: Color(0xFF444444),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (counter != null)
                Text(
                  counter!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 5,
              color: AppColors.borderSoft,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.indigo, AppColors.secondary],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
