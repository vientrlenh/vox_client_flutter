import 'appeal_api.dart';
import 'models/appeal_summary.dart';
import 'models/appeal_detail.dart';

class AppealRepository {
  AppealRepository(this._appealApi);

  final AppealApi _appealApi;

  Future<String> createAppeal({
    required String candidateResultId,
    required List<String> paperItemIds,
    required String reason,
    String? notes,
  }) =>
      _appealApi.createAppeal(
        candidateResultId: candidateResultId,
        paperItemIds: paperItemIds,
        reason: reason,
        notes: notes,
      );

  Future<List<AppealSummary>> getMyAppeals() => _appealApi.getMyAppeals();

  Future<AppealDetail> getAppeal(String id) => _appealApi.getAppeal(id);
}
