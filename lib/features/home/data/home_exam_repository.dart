import '../../schedule/data/models/exam_schedule.dart';
import 'home_exam_api.dart';

class HomeExamRepository {
  HomeExamRepository(this._api);

  final HomeExamApi _api;

  Future<List<ExamSchedule>> getIncompleteClassTests() =>
      _api.getIncompleteClassTests();
}
