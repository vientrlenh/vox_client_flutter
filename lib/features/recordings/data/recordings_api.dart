import '../../../core/network/graphql_client.dart';
import 'models/exam_attempt_summary.dart';
import 'models/exam_item_response.dart';
import 'models/exam_item_evaluation.dart';
import 'models/exam_response_item.dart';

class RecordingsApi {
  RecordingsApi(this._client);

  final GraphQLClient _client;

  Future<List<ExamAttemptSummary>> getMyAttempts() async {
    final data = await _client.query('''
      query MyExamResults {
        myExamResults {
          sessionId
          examName
          submittedAt
          totalScore
          sessionStatus
        }
      }
    ''');

    final results = data['myExamResults'] as List;
    return results
        .where((e) => (e as Map<String, dynamic>)['sessionId'] != null)
        .map((e) => ExamAttemptSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExamResponseItem>> getSessionItems(String sessionId) async {
    final data = await _client.query('''
      query ExamSessionResult(\$sessionId: ID!) {
        examSessionResult(sessionId: \$sessionId) {
          items { responseId itemScore }
        }
      }
    ''', variables: {'sessionId': sessionId});

    final result = data['examSessionResult'] as Map<String, dynamic>?;
    final items = result?['items'] as List? ?? const [];
    return items
        .map((e) => ExamResponseItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExamItemResponse> getItemResponse(String answerId) async {
    final data = await _client.query('''
      query ExamItemResponse(\$answerId: ID!) {
        examItemResponse(answerId: \$answerId) {
          id
          audioUrl
          durationSeconds
          transcript
          submittedAt
          turns {
            id
            turnOrder
            promptText
            audioUrl
            transcript
            durationSeconds
          }
        }
      }
    ''', variables: {'answerId': answerId});

    return ExamItemResponse.fromJson(
        data['examItemResponse'] as Map<String, dynamic>);
  }

  Future<ExamItemEvaluation?> getItemEvaluation(String answerId) async {
    final data = await _client.query('''
      query ExamItemResponseEvaluation(\$answerId: ID!) {
        examItemResponseEvaluation(answerId: \$answerId) {
          feedbackSummary
          criteria { criterionCode criterionName finalScore minScore maxScore rationale }
          turns { id turnOrder wordFeedback }
        }
      }
    ''', variables: {'answerId': answerId});
    final evaluation = data['examItemResponseEvaluation'] as Map<String, dynamic>?;
    return evaluation == null ? null : ExamItemEvaluation.fromJson(evaluation);
  }
}
