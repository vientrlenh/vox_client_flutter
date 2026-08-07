import '../../teacher_exam/data/models/exam_detail.dart';
import '../../teacher_exam/data/teacher_exam_graphql_api.dart';
import 'models/exam_room_schedule.dart';
import 'schedule_api.dart';

class TeacherScheduleItem {
  final ExamDetail exam;
  final ExamRoomSchedule schedule;

  const TeacherScheduleItem({required this.exam, required this.schedule});
}

class ScheduleRepository {
  ScheduleRepository(this._api, [TeacherExamGraphQLApi? teacherApi])
      : _teacherApi = teacherApi;

  final ScheduleApi _api;
  final TeacherExamGraphQLApi? _teacherApi;

  /// Ca thi của học sinh, mỗi ca đã kèm sẵn bài thi (`ExamRoomSchedule.exam`).
  ///
  /// Trước đây hàm này gọi thêm REST `/v1/exams` rồi ghép theo examId. Cách đó hỏng hai
  /// tầng: (1) REST trả `StudentExamSummaryResponse` -- các khoá là `title`/`examDate`,
  /// không phải `name`/`openAt` mà `ExamSchedule.fromJson` chờ (model đó viết cho type
  /// `Exam` của GraphQL), nên ép kiểu ném ngay lập tức và cả màn lịch báo lỗi; (2) kể cả
  /// nếu đọc được thì danh sách bài thi có phân trang, bài thi rơi ngoài trang đầu sẽ làm
  /// ca thi biến mất không một lời báo.
  Future<List<ExamRoomSchedule>> getStudentSchedule() =>
      _api.getMyExamSchedules();

  /// Centralized exams the teacher proctors, one item per room assignment.
  Future<List<TeacherScheduleItem>> getTeacherCentralizedSchedule({
    required String schoolId,
    required String myUserId,
  }) async {
    final teacherApi = _teacherApi;
    if (teacherApi == null) {
      throw StateError('ScheduleRepository was not given a TeacherExamGraphQLApi');
    }

    final exams = await teacherApi.getSchoolCentralizedExams(schoolId);

    final schedulesPerExam = await Future.wait(
      exams.map((exam) => _api.getExamSchedules(exam.id)),
    );

    final items = <TeacherScheduleItem>[];
    for (var i = 0; i < exams.length; i++) {
      for (final schedule in schedulesPerExam[i]) {
        if (schedule.proctorUserIds.contains(myUserId)) {
          items.add(TeacherScheduleItem(exam: exams[i], schedule: schedule));
        }
      }
    }
    return items;
  }
}
