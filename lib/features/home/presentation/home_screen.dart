import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/graphql_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../../personalize/data/models/practice_dashboard.dart';
import '../../personalize/data/models/practice_history_entry.dart';
import '../../personalize/data/models/practice_topic.dart';
import '../../personalize/data/personalize_repository.dart';
import '../../personalize/presentation/personalize_styles.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_repository.dart';
import '../../schedule/data/models/exam_schedule.dart';
import '../data/home_exam_api.dart';
import '../data/home_exam_repository.dart';

/// Tab 1 — Home

String _greeting(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 4) return l10n.greetingLateNight;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 18) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

String _initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+'))
    ..removeWhere((p) => p.isEmpty);
  if (parts.isEmpty) return '';
  final first = parts.first.substring(0, 1);
  final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
  return (first + last).toUpperCase();
}

int? _daysUntil(DateTime? at) {
  if (at == null) return null;
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day);
  final to = DateTime(at.year, at.month, at.day);
  return to.difference(from).inDays;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenSchedule, this.onOpenPractice});

  final VoidCallback? onOpenSchedule;
  final VoidCallback? onOpenPractice;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ProfileRepository(ProfileApi(GraphQLClient()));
  final _examRepository = HomeExamRepository(HomeExamApi(GraphQLClient()));
  final _personalizeRepository = PersonalizeRepository();

  String? _name;
  List<ExamSchedule>? _upcomingExams;
  PracticeDashboard? _dashboard;
  List<PracticeHistoryEntry>? _recentHistory;

  @override
  void initState() {
    super.initState();
    _repository.getProfile().then((p) {
      if (mounted) setState(() => _name = p.fullName ?? p.email);
    });
    _examRepository.getIncompleteClassTests().then((exams) {
      if (!mounted) return;
      // Soonest deadline first; exams with no date at all sink to the bottom.
      final sorted = [...exams]..sort(
        (a, b) => (a.closeAt ?? a.openAt ?? DateTime(9999))
            .compareTo(b.closeAt ?? b.openAt ?? DateTime(9999)),
      );
      setState(() => _upcomingExams = sorted);
    }).catchError((_) {
      if (mounted) setState(() => _upcomingExams = []);
    });
    _personalizeRepository.getDashboard().then((d) {
      if (mounted) setState(() => _dashboard = d);
    }).catchError((_) {
      if (mounted) {
        setState(
          () => _dashboard = const PracticeDashboard(
            learnerName: '',
            streakDays: 0,
            sessionsDone: 0,
            averageScore: 0,
            sessionsThisWeek: 0,
          ),
        );
      }
    });
    _personalizeRepository.getPracticeHistory(limit: 20).then((rows) {
      if (mounted) setState(() => _recentHistory = rows);
    }).catchError((_) {
      if (mounted) setState(() => _recentHistory = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(name: _name),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _SearchBar(),
              const SizedBox(height: 20),
              _StatRow(dashboard: _dashboard),
              const SizedBox(height: 16),
              _ProgressCard(history: _recentHistory),
              const SizedBox(height: 22),
              _SectionHeader(
                label: l10n.homeExamsToComplete,
                action: widget.onOpenSchedule == null
                    ? null
                    : l10n.homeSeeSchedule,
                onAction: widget.onOpenSchedule,
              ),
              const SizedBox(height: 10),
              ..._buildExamSection(l10n),
              if (_dashboard != null && _dashboard!.suggestions.isNotEmpty) ...[
                const SizedBox(height: 22),
                _SectionHeader(
                  label: l10n.pzHomeSuggestions,
                  action: l10n.pzSeeAll,
                  onAction: widget.onOpenPractice,
                ),
                const SizedBox(height: 10),
                for (final topic in _dashboard!.suggestions.take(3)) ...[
                  _SuggestionCard(topic: topic, onTap: widget.onOpenPractice),
                  const SizedBox(height: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExamSection(AppLocalizations l10n) {
    final exams = _upcomingExams;
    if (exams == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (exams.isEmpty) {
      return [
        Text(
          l10n.homeNoExamsLeft,
          style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
        ),
      ];
    }
    final visible = exams.take(3);
    return [
      for (final exam in visible) ...[
        _ExamRow(exam: exam),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.chipBlueBg,
            child: Text(
              _initials(name),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.indigo,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(l10n),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name ?? '…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const NotificationBell(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context)!.homeSearchLessons,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textGhost,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.dashboard});
  final PracticeDashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = dashboard;
    return Row(
      children: [
        Expanded(
          child: StatBox(
            value: d == null ? '—' : '${d.sessionsDone}',
            caption: l10n.pzHomeStatSessions,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            value: d == null ? '—' : d.averageScore.toStringAsFixed(1),
            caption: l10n.pzHomeStatAverage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            value: d == null ? '—' : '${d.sessionsThisWeek}',
            caption: l10n.pzHomeStatWeeklyGoal,
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.history});
  final List<PracticeHistoryEntry>? history;

  static const _maxBarHeight = 56.0;

  List<double> _scores() {
    final rows = history ?? const <PracticeHistoryEntry>[];
    final scored = rows.where((e) => e.overallScore != null).toList()
      ..sort(
        (a, b) => (a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
      );
    final tail = scored.length > 7
        ? scored.sublist(scored.length - 7)
        : scored;
    return [for (final e in tail) e.overallScore!];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (history == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final scores = _scores();
    // Need at least two points to call it a "trend" — one bar alone can't
    // show progress or carry a delta.
    if (scores.length < 2) return const SizedBox.shrink();

    final delta = scores.last - scores[scores.length - 2];
    final minV = scores.reduce((a, b) => a < b ? a : b);
    final maxV = scores.reduce((a, b) => a > b ? a : b);
    // Floor the spread so a flat run of near-identical scores doesn't divide
    // by (near) zero and still reads as one solid color instead of noise.
    final range = (maxV - minV) < 0.5 ? 0.5 : (maxV - minV);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: rowDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SectionLabel(l10n.homeProgressTitle)),
              Text(
                formatDelta(delta),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: delta >= 0 ? AppColors.chipGreenFg : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < scores.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _Bar(score: scores[i], minV: minV, range: range)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.score, required this.minV, required this.range});
  final double score;
  final double minV;
  final double range;

  @override
  Widget build(BuildContext context) {
    final fraction = (0.15 + 0.85 * (score - minV) / range).clamp(0.15, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: _ProgressCard._maxBarHeight * fraction,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.chipBlueBg,
              AppColors.indigo,
              ((score - minV) / range).clamp(0.0, 1.0),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textFaint,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action, this.onAction});
  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: SectionLabel(label)),
        if (action != null && onAction != null)
          InkWell(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.indigo,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam});
  final ExamSchedule exam;

  @override
  Widget build(BuildContext context) {
    final dueAt = exam.closeAt ?? exam.openAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: rowDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBadge(date: dueAt),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeLabel(context, dueAt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                ),
                const SizedBox(height: 6),
                _DueTag(days: _daysUntil(dueAt)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _timeLabel(BuildContext context, DateTime? d) {
    if (d == null) return AppLocalizations.of(context)!.homeNoDateSet;
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Container(
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: date == null
          ? const Icon(Icons.event_busy, size: 18, color: AppColors.textFaint)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat.MMM(locale).format(date!).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textFaint,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date!.day}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
    );
  }
}

class _DueTag extends StatelessWidget {
  const _DueTag({required this.days});
  final int? days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final d = days;
    if (d == null) return TagChip(l10n.homeNoDateSet);
    if (d < 0) return TagChip.orange(l10n.homeOverdue);
    if (d == 0) return TagChip.orange(l10n.homeDueToday);
    if (d <= 2) return TagChip.orange(l10n.homeDaysLeft(d));
    return TagChip(l10n.homeDaysLeft(d));
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.topic, this.onTap});
  final PracticeTopic topic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: rowDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFFCCCCCC),
                ),
              ],
            ),
            if (topic.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final reason in topic.reasons) TagChip.blue(reason),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
