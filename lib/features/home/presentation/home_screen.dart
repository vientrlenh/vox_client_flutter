import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/graphql_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_repository.dart';
import '../../schedule/data/models/exam_schedule.dart';
import '../data/home_exam_api.dart';
import '../data/home_exam_repository.dart';
import './notifications_screen.dart';

/// Tab 1 — Home

String _greeting(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 4) return l10n.greetingLateNight;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 18) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ProfileRepository(ProfileApi(GraphQLClient()));
  final _examRepository = HomeExamRepository(HomeExamApi(GraphQLClient()));

  String? _name;
  List<ExamSchedule>? _incompleteExams;

  @override
  void initState() {
    super.initState();
    _repository.getProfile().then((p) {
      if (mounted) setState(() => _name = p.fullName ?? p.email);
    });
    _examRepository.getIncompleteClassTests().then((exams) {
      if (mounted) setState(() => _incompleteExams = exams);
    }).catchError((_) {
      if (mounted) setState(() => _incompleteExams = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── App bar ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
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
                      _name ?? '…',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              IconCircle(
                Icons.notifications_none,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
              ),
            ],
          ),
        ),

        // ── Scroll body ──
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _SearchBar(),
              const SizedBox(height: 20),

              if (_incompleteExams != null && _incompleteExams!.isNotEmpty) ...[
                SectionLabel(l10n.homeContinueLearning),
                const SizedBox(height: 10),
                _ContinueCard(exam: _incompleteExams!.first),
                const SizedBox(height: 20),
              ],

              SectionLabel(l10n.homeExamsToComplete),
              const SizedBox(height: 10),
              ..._buildExamSection(l10n),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExamSection(AppLocalizations l10n) {
    final exams = _incompleteExams;
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
    final rest = exams.length > 1 ? exams.sublist(1) : const <ExamSchedule>[];
    return [
      for (final exam in rest) ...[
        _ExamCard(exam: exam),
        const SizedBox(height: 10),
      ],
    ];
  }
}

String _examTimeLabel(BuildContext context, DateTime? d) {
  final l10n = AppLocalizations.of(context)!;
  if (d == null) return l10n.homeNoDateSet;
  final locale = Localizations.localeOf(context).toString();
  final month = DateFormat.MMM(locale).format(d);
  final time =
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '$month ${d.day} · $time';
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam});
  final ExamSchedule exam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_outlined,
                size: 22, color: Color(0xFF555555)),
          ),
          const SizedBox(width: 14),
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
                  _examTimeLabel(context, exam.openAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textFaint,
                  ),
                ),
                const SizedBox(height: 6),
                TagChip.orange(AppLocalizations.of(context)!.homeNotCompleted),
              ],
            ),
          ),
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

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.exam});
  final ExamSchedule exam;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CLASS TEST',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            exam.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          if (exam.description != null && exam.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              exam.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _examTimeLabel(context, exam.closeAt),
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
                disabledBackgroundColor: Colors.white,
                disabledForegroundColor: AppColors.ink,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                l10n.homeResume,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
