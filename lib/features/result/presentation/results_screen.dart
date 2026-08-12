import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/graphql_client.dart';
import '../../appeal/presentation/new_appeal_screen.dart';
import '../../practice/presentation/attempt_recordings_screen.dart';
import '../data/models/exam_candidate_result.dart';
import '../data/models/exam_result_summary.dart';
import '../data/result_api.dart';
import '../data/result_repository.dart';
import 'results_list_screen.dart' show ResultStatusMeta;

/// Results / Performance Review screen shown after a speaking exam attempt.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.sessionId,
    required this.examName,
    this.pageTitle = 'Kết quả bài kiểm tra',
  });

  final String sessionId;
  final String examName;
  final String pageTitle;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _repository = ResultRepository(ResultApi(GraphQLClient()));

  bool _loading = true;
  String? _error;
  ExamCandidateResult? _result;

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
      final result = await _repository.getSessionResult(widget.sessionId);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this result.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.pageTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildBody(context, _result!),
    );
  }

  Widget _buildBody(BuildContext context, ExamCandidateResult result) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _ScoreHero(examName: widget.examName, result: result),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AttemptRecordingsScreen(
                sessionId: widget.sessionId,
                examName: widget.examName,
              ),
            ),
          ),
          icon: const Icon(Icons.mic, size: 18),
          label: const Text('View recordings'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.indigo,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
            ),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        if (result.sections.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionLabel('Section Breakdown'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < result.sections.length; i++) ...[
                  _SectionRow(
                    result.sections[i],
                    scoreRatio: result.ratioOf(result.sections[i].score),
                    // Một mục có thể gồm nhiều câu -- gom hết responseId của mục đó lại.
                    answerIds: [
                      for (final item in result.items)
                        if (item.sectionId == result.sections[i].sectionId)
                          item.responseId,
                    ],
                    repository: _repository,
                  ),
                  if (i != result.sections.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
          ),
        ],
        if (result.status == ExamResultStatus.released) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NewAppealScreen(
                  candidateResultId: result.id,
                  examName: widget.examName,
                  parts: [
                    for (final item in result.items)
                      AppealablePart(
                        paperItemId: item.paperItemId,
                        label: result.sections
                            .firstWhere(
                              (s) => s.sectionId == item.sectionId,
                              orElse: () => const ExamCandidateResultSection(
                                sectionId: '',
                                title: null,
                                score: 0,
                              ),
                            )
                            .title ??
                            'Part',
                        score: item.itemScore,
                      ),
                  ],
                ),
              ),
            ),
            icon: const Icon(Icons.flag_outlined, size: 18),
            label: const Text('Appeal this result'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
              textStyle:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.indigo,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99),
            ),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({super.key, required this.sessionId, required this.examName});
  final String sessionId;
  final String examName;

  @override
  Widget build(BuildContext context) => ResultsScreen(
        sessionId: sessionId,
        examName: examName,
        pageTitle: 'Kết quả bài kiểm tra',
      );
}

class ClassTestResultScreen extends StatelessWidget {
  const ClassTestResultScreen({super.key, required this.sessionId, required this.examName});
  final String sessionId;
  final String examName;

  @override
  Widget build(BuildContext context) => ResultsScreen(
        sessionId: sessionId,
        examName: examName,
        pageTitle: 'Kết quả bài tập',
      );
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.examName, required this.result});

  final String examName;
  final ExamCandidateResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.indigo, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text(
            examName.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 18),
          if (result.scoreVisible && result.totalScore != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  result.totalScore!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              
                Text(
                  result.scoringScaleMax == null
                      ? ''
                      : ' / ${_trimZero(result.scoringScaleMax!)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Score not released yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              result.status.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: result.status.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "100.0" -> "100", "9.5" -> "9.5". Mẫu số của thang gần như luôn là số tròn, kéo theo ".0"
/// nhìn như điểm lẻ.
String _trimZero(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

/// Một mục điểm, xổ ra được để xem AI chấm mục đó thế nào.
///
/// Bản chấm tải LƯỜI -- chỉ gọi khi học sinh mở mục ra, và chỉ gọi một lần. Một bài có nhiều
/// câu, mỗi câu là một lượt truy vấn kèm join tới bảng điểm tiêu chí; nạp sẵn tất cả chỉ để
/// có thể người ta không mở cái nào là trả giá cho việc chưa chắc xảy ra.
class _SectionRow extends StatefulWidget {
  const _SectionRow(
    this.section, {
    required this.answerIds,
    required this.repository,
    required this.scoreRatio,
  });

  final ExamCandidateResultSection section;

  /// Vị trí của điểm mục này trong thang rubric, 0..1 -- do nơi gọi tính từ
  /// `ExamCandidateResult.ratioOf`. Null khi backend chưa trả thang.
  ///
  /// Truyền SỐ ĐÃ TÍNH chứ không truyền cả `result` xuống: widget này chỉ cần đúng một con số,
  /// và bản cũ tự chia `score / 10` chính là hệ quả của việc nó không có thang trong tay.
  final double? scoreRatio;

  /// `responseId` của các câu thuộc mục này -- khoá để hỏi `examItemResponseEvaluation`.
  final List<String> answerIds;
  final ResultRepository repository;

  @override
  State<_SectionRow> createState() => _SectionRowState();
}

class _SectionRowState extends State<_SectionRow> {
  bool _expanded = false;
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  List<ExamItemEvaluation> _evaluations = const [];

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (!_expanded || _loaded || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = <ExamItemEvaluation>[];
      for (final answerId in widget.answerIds) {
        final evaluation = await widget.repository.getItemEvaluation(answerId);
        if (evaluation != null) results.add(evaluation);
      }
      if (!mounted) return;
      setState(() {
        _evaluations = results;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(onTap: widget.answerIds.isEmpty ? null : _toggle, child: _header()),
        if (_expanded) _detail(),
      ],
    );
  }

  Widget _detail() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          'Không tải được bản chấm chi tiết.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
      );
    }
    if (_evaluations.isEmpty) {
      // Khác rỗng vì lỗi: ở đây gọi được nhưng KHÔNG có bản chấm nào -- câu chưa chấm xong,
      // hoặc bản chấm bị đánh dấu không hợp lệ. Nói thẳng thay vì để khoảng trắng.
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text(
          'Chưa có bản chấm chi tiết cho phần này.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _evaluations.length; i++) ...[
            if (_evaluations.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Câu ${i + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    color: AppColors.textFaint,
                  ),
                ),
              ),
            _EvaluationBlock(_evaluations[i]),
            if (i != _evaluations.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    final section = widget.section;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          if (widget.answerIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: AppColors.textFaint,
              ),
            ),
          Expanded(
            child: Text(
              section.title ?? 'Section',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
          ),
          // Không biết thang thì KHÔNG vẽ thanh. Thanh tiến trình là một khẳng định về tỉ lệ;
          // thiếu mẫu số mà vẫn vẽ thì hoặc phải bịa mẫu số (bản cũ chia cứng cho 10, nên mọi
          // mục của rubric thang 0-100 đều đầy kín), hoặc vẽ thanh rỗng -- trông như 0 điểm.
          // Con số bên phải vẫn hiện đủ, đó mới là thông tin thật.
          if (widget.scoreRatio != null)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  height: 8,
                  color: const Color(0xFFF1F5F9),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: widget.scoreRatio!,
                    child: Container(color: AppColors.indigo),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          SizedBox(
            width: 42,
            child: Text(
              section.score.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bản chấm AI của một câu: tổng điểm, nhận xét chung, và từng tiêu chí kèm lời giải thích.
class _EvaluationBlock extends StatelessWidget {
  const _EvaluationBlock(this.evaluation);

  final ExamItemEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (evaluation.markedInvalid) ...[
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bản chấm này bị đánh dấu không hợp lệ.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (evaluation.feedbackSummary != null &&
              evaluation.feedbackSummary!.trim().isNotEmpty) ...[
            Text(
              evaluation.feedbackSummary!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 12),
          ],
          for (final criterion in evaluation.criteria) ...[
            _CriterionRow(criterion),
            if (criterion != evaluation.criteria.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow(this.criterion);

  final ExamItemCriterionScore criterion;

  @override
  Widget build(BuildContext context) {
    // Thang lấy từ RUBRIC đang áp, không cứng 0-10: đổi trường sang thang khác thì thanh
    // tiến trình vẫn đúng tỉ lệ. Thiếu min/max thì không vẽ thanh chứ không đoán bừa.
    final min = criterion.minScore;
    final max = criterion.maxScore;
    final score = criterion.finalScore;
    final hasScale = min != null && max != null && max > min && score != null;
    final ratio = hasScale ? ((score - min) / (max - min)).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                criterion.criterionName,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ),
            Text(
              score == null ? '—' : score.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.indigo,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (hasScale)
              Text(
                ' / ${max.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
              ),
          ],
        ),
        if (hasScale) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Container(
              height: 5,
              color: const Color(0xFFE2E8F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(color: AppColors.indigo),
              ),
            ),
          ),
        ],
        if (criterion.rationale != null &&
            criterion.rationale!.trim().isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            criterion.rationale!,
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
