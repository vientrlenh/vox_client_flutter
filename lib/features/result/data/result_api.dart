import '../../../core/network/graphql_client.dart';
import 'models/exam_candidate_result.dart';
import 'models/exam_result_summary.dart';

class ResultApi {
  ResultApi(this._client);

  final GraphQLClient _client;

  Future<List<ExamResultSummary>> getMyExamResults() async {
    final data = await _client.query('''
      query MyExamResults {
        myExamResults {
          examId
          examCode
          kind
          sessionId
          sessionStatus
          examName
          startedAt
          totalScore
          resultStatus
          submittedAt
        }
      }
    ''');

    final results = data['myExamResults'] as List;
    return results
        .map((e) => ExamResultSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExamCandidateResult> getSessionResult(String sessionId) async {
    final data = await _client.query('''
      query ExamSessionResult(\$sessionId: ID!) {
        examSessionResult(sessionId: \$sessionId) {
          id
          scoreVisible
          totalScore
          status
          sections { sectionId title score }
          items { paperItemId responseId sectionId itemScore }
        }
      }
    ''', variables: {'sessionId': sessionId});

    return ExamCandidateResult.fromJson(
        data['examSessionResult'] as Map<String, dynamic>);
  }

  /// Chi tiết AI chấm một câu. Tải RIÊNG khi học sinh xổ mục ra, không nạp sẵn cùng
  /// `examSessionResult`: một bài có thể có nhiều câu, mỗi câu là một lượt truy vấn kèm
  /// join tới bảng điểm tiêu chí -- nạp hết chỉ để có thể người ta không mở cái nào.
  ///
  /// Trả `null` khi chưa có bản chấm (đang chấm, hoặc chấm lỗi) -- schema cho phép null.
  Future<ExamItemEvaluation?> getItemEvaluation(String answerId) async {
    final data = await _client.query('''
      query ExamItemResponseEvaluation(\$answerId: ID!) {
        examItemResponseEvaluation(answerId: \$answerId) {
          itemScore
          markedInvalid
          feedbackSummary
          criteria {
            criterionCode
            criterionName
            minScore
            maxScore
            finalScore
            rationale
          }
        }
      }
    ''', variables: {'answerId': answerId});

    final json = data['examItemResponseEvaluation'];
    if (json == null) return null;
    return ExamItemEvaluation.fromJson(json as Map<String, dynamic>);
  }
}
