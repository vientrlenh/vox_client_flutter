import 'models/exam_candidate_result.dart';
import 'models/exam_result_summary.dart';
import 'result_api.dart';

class ResultRepository {
  ResultRepository(this._resultApi);

  final ResultApi _resultApi;

  static Future<List<ExamResultSummary>>? _cachedResults;

  Future<List<ExamResultSummary>> getMyExamResults({bool refresh = false}) {
    if (refresh || _cachedResults == null) {
      _cachedResults = _resultApi.getMyExamResults();
    }
    return _cachedResults!;
  }

  Future<List<ExamResultGroup>> getGroupedResults(
    ExamKind kind, {
    bool refresh = false,
  }) async {
    final all = await getMyExamResults(refresh: refresh);
    final grouped = <String, List<ExamResultSummary>>{};
    for (final result in all.where((result) => result.kind == kind)) {
      grouped.putIfAbsent(result.examId, () => []).add(result);
    }
    final groups = grouped.entries.map((entry) {
      entry.value.sort((a, b) =>
          (b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ));
      return ExamResultGroup(
        examId: entry.key,
        examName: entry.value.first.examName,
        sessions: entry.value,
      );
    }).toList();
    groups.sort((a, b) =>
        (b.latestStartedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
          a.latestStartedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ));
    return groups;
  }

  Future<ExamCandidateResult> getSessionResult(String sessionId) =>
      _resultApi.getSessionResult(sessionId);

  /// Chi tiết AI chấm một câu -- gọi khi học sinh xổ một mục ra xem.
  Future<ExamItemEvaluation?> getItemEvaluation(String answerId) =>
      _resultApi.getItemEvaluation(answerId);
}
