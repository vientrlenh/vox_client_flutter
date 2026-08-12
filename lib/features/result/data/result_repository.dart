import 'models/exam_candidate_result.dart';
import 'models/exam_result_summary.dart';
import 'result_api.dart';

class ResultRepository {
  ResultRepository(this._resultApi);

  final ResultApi _resultApi;

  /// Cache theo VÒNG ĐỜI REPOSITORY, không phải `static`.
  ///
  /// Bản cũ khai `static`, nên nó sống theo cả tiến trình app và chỉ mất khi tiến trình chết.
  /// Nó còn ghim chính cái `Future` chứ không phải kết quả -- nghĩa là ảnh chụp ĐẦU TIÊN được
  /// giữ vĩnh viễn. Đúng lúc tệ nhất: học sinh mở màn kết quả trước khi giáo viên công bố điểm
  /// (trường hợp phổ biến nhất) thì danh sách rỗng bị ghim, và mọi lần mở lại sau đó trả thẳng
  /// nó ra mà không chạm mạng. Đo thực tế: app hỏi backend đúng một lần lúc 21:53, điểm công bố
  /// lúc 22:15, và suốt hơn một giờ sau không hề có thêm request nào.
  ///
  /// Giữ cache ở mức instance thì vẫn tránh gọi lại khi đổi tab trong cùng màn hình, mà rời màn
  /// rồi vào lại là có repository mới -> dữ liệu mới.
  Future<List<ExamResultSummary>>? _cachedResults;

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
