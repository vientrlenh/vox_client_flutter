import '../../schedule/data/models/exam_schedule.dart';
import 'home_exam_api.dart';

class HomeExamRepository {
  HomeExamRepository(this._api);

  final HomeExamApi _api;

  /// Ca thi sắp tới, gồm CẢ kỳ thi tập trung lẫn bài kiểm tra lớp.
  ///
  /// Tên cũ `getIncompleteClassTests` nói đúng bản chất cũ (chỉ lấy CLASS_TEST) nên phải đổi
  /// theo, không giữ lại làm alias: một cái tên nói sai phạm vi còn tệ hơn không có tên.
  Future<List<ExamSchedule>> getUpcomingExams() => _api.getUpcomingExams();
}
