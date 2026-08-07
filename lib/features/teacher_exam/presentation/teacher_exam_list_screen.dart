import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/graphql_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_repository.dart';
import '../../schedule/data/models/exam_schedule.dart';
import '../data/models/exam_detail.dart';
import '../data/models/school_class.dart';
import '../data/teacher_exam_graphql_api.dart';
import '../data/teacher_exam_repository.dart';
import '../data/teacher_exam_rest_api.dart';
import '../../home/presentation/notifications_screen.dart';
import 'centralized_exam_detail_screen.dart';
import 'class_test_detail_screen.dart';
import 'class_test_form_screen.dart';
import 'teacher_exam_status.dart';

String _greeting(AppLocalizations l10n) {
  final hour = DateTime.now().hour;
  if (hour < 4) return l10n.greetingLateNight;
  if (hour < 12) return l10n.greetingMorning;
  if (hour < 18) return l10n.greetingAfternoon;
  return l10n.greetingEvening;
}

class TeacherExamListScreen extends StatefulWidget {
  const TeacherExamListScreen({super.key});

  @override
  State<TeacherExamListScreen> createState() => _TeacherExamListScreenState();
}

class _TeacherExamListScreenState extends State<TeacherExamListScreen> {
  final _profileRepository = ProfileRepository(ProfileApi(GraphQLClient()));
  final _repository = TeacherExamRepository(
    TeacherExamGraphQLApi(GraphQLClient()),
    TeacherExamRestApi(ApiClient()),
  );

  int _tab = 0;
  String? _name;
  List<SchoolClass> _schoolClasses = const [];
  List<ExamDetail> _classTests = const [];
  List<ExamDetail> _centralizedExams = const [];
  bool _loading = true;
  String? _error;

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
      final profile = await _profileRepository.getProfile();
      if (mounted) setState(() => _name = profile.fullName ?? profile.email);
      final schoolId = profile.schoolId;
      if (schoolId == null) {
        throw StateError('No school on profile');
      }
      final results = await Future.wait([
        _repository.getMySchoolClasses(schoolId),
        _repository.getClassTests(),
        _repository.getCentralizedExams(
          schoolId: schoolId,
          myUserId: profile.id,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _schoolClasses = results[0] as List<SchoolClass>;
        _classTests = results[1] as List<ExamDetail>;
        _centralizedExams = results[2] as List<ExamDetail>;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load exams.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openClassTest(ExamDetail exam) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassTestDetailScreen(
          repository: _repository,
          schoolClasses: _schoolClasses,
          exam: exam,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _createClassTest() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ClassTestFormScreen(
          repository: _repository,
          schoolClasses: _schoolClasses,
        ),
      ),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _createClassTest,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.teacherExamClassTestsTab)),
                ButtonSegment(value: 1, label: Text(l10n.teacherExamCentralizedTab)),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) =>
                  setState(() => _tab = selection.first),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.textFaint),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _load,
                          child: Text(l10n.scheduleRetry),
                        ),
                      ],
                    ),
                  )
                : _tab == 0
                ? _ExamList(
                    sectionLabel: l10n.teacherExamClassTestsTab,
                    exams: _classTests,
                    emptyLabel: l10n.teacherExamNoClassTests,
                    onTap: _openClassTest,
                  )
                : _ExamList(
                    sectionLabel: l10n.teacherExamCentralizedSection,
                    exams: _centralizedExams,
                    emptyLabel: l10n.teacherExamNoCentralizedExams,
                    onTap: (exam) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CentralizedExamDetailScreen(exam: exam),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ExamList extends StatelessWidget {
  const _ExamList({
    required this.sectionLabel,
    required this.exams,
    required this.emptyLabel,
    required this.onTap,
  });

  final String sectionLabel;
  final List<ExamDetail> exams;
  final String emptyLabel;
  final void Function(ExamDetail exam) onTap;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: AppColors.textFaint),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: exams.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return SectionLabel(sectionLabel);
        final exam = exams[index - 1];
        return _ExamListTile(exam: exam, onTap: onTap);
      },
    );
  }
}

class _ExamListTile extends StatelessWidget {
  const _ExamListTile({required this.exam, required this.onTap});

  final ExamDetail exam;
  final void Function(ExamDetail exam) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: () => onTap(exam),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exam.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            if (exam.description != null) ...[
              const SizedBox(height: 3),
              Text(
                exam.description!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                examStatusChip(exam.status, l10n),
                TagChip(
                  exam.kind == ExamKind.centralized
                      ? l10n.teacherExamCentralizedTab
                      : l10n.teacherExamKindClassTest,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
