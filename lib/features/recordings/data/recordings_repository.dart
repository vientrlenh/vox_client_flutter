import 'models/exam_attempt_summary.dart';
import 'models/exam_item_response.dart';
import 'models/exam_item_evaluation.dart';
import 'models/exam_response_item.dart';
import 'recordings_api.dart';

class RecordingsRepository {
  RecordingsRepository(this._recordingsApi);

  final RecordingsApi _recordingsApi;

  Future<List<ExamAttemptSummary>> getMyAttempts() =>
      _recordingsApi.getMyAttempts();

  Future<List<ExamResponseItem>> getSessionItems(String sessionId) =>
      _recordingsApi.getSessionItems(sessionId);

  Future<ExamItemResponse> getItemResponse(String answerId) =>
      _recordingsApi.getItemResponse(answerId);

  Future<ExamItemEvaluation?> getItemEvaluation(String answerId) =>
      _recordingsApi.getItemEvaluation(answerId);
}
