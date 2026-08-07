import '../../../core/network/graphql_client.dart';
import 'models/exam_room_schedule.dart';

class ScheduleApi {
  ScheduleApi(this._client);

  final GraphQLClient _client;

  Future<List<ExamRoomSchedule>> getExamSchedules(String? examId) async {
    final data = await _client.query('''
      query ExamSchedules(\$examId: ID) {
        examSchedules(examId: \$examId) {
          id examId startDate endDate
          room { name code }
          proctors { teacher { id } }
        }
      }
    ''', variables: {'examId': examId});

    final list = data['examSchedules'] as List;
    return list
        .map((e) => ExamRoomSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ca thi của chính học sinh đang đăng nhập, KÈM thông tin bài thi trên từng ca.
  ///
  /// Lấy `exam { ... }` ngay tại đây chứ không gọi thêm danh sách bài thi rồi tự ghép:
  /// backend thêm field này đúng để tránh việc đó (xem ExamScheduleController#exam), và
  /// cách ghép cũ vừa hỏng vừa âm thầm -- xem chú thích ở ScheduleRepository.
  ///
  /// Không hỏi `proctors`: học sinh không hiển thị giám thị, mà mỗi field thừa là thêm
  /// một resolver có thể ném và kéo đổ cả query.
  Future<List<ExamRoomSchedule>> getMyExamSchedules() async {
    final data = await _client.query('''
      query MyExamSchedules {
        myExamSchedules {
          id examId startDate endDate
          room { name code }
          exam { id name description kind status openAt closeAt }
        }
      }
    ''');

    final list = data['myExamSchedules'] as List;
    return list
        .map((e) => ExamRoomSchedule.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
