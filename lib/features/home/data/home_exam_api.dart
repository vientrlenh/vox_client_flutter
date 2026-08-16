import '../../../core/network/graphql_client.dart';
import '../../schedule/data/models/exam_schedule.dart';

class HomeExamApi {
  HomeExamApi(this._client);

  final GraphQLClient _client;

  /// Ca thi sắp tới của chính học sinh đang đăng nhập.
  ///
  /// Dùng `myExamSchedules` thay cho `exams(kind: CLASS_TEST)` + N lượt `examCandidates` như
  /// trước, được ba thứ cùng lúc:
  ///
  ///   1. ĐỦ HAI LOẠI. Bản cũ lọc cứng `kind: CLASS_TEST` nên kỳ thi tập trung không bao giờ
  ///      hiện trên trang chủ, dù đó mới là loại quan trọng hơn với học sinh.
  ///   2. MỘT LỜI GỌI. Bản cũ lấy tối đa 50 kỳ thi rồi bắn 50 query `examCandidates` song song
  ///      chỉ để biết bài nào chưa làm -- N+1 thật, chạy mỗi lần mở app.
  ///   3. GIỜ THI THẬT. Bản cũ hiển thị `openAt`/`closeAt` của KỲ THI (cửa sổ chung), còn đây
  ///      là `startDate`/`endDate` của CA -- giờ thi của chính em ấy.
  ///
  /// Backend đã tự bó phạm vi theo `exam_candidate` của người gọi và loại ca chưa publish
  /// (`isVisibleToStudent`), nên không cần lọc quyền ở client.
  ///
  /// KHÔNG truyền `startDate`: bộ lọc đó bên server so `schedule.startDate >= input`, nên nó
  /// vừa loại ca ĐANG diễn ra (đã bắt đầu vài phút trước), vừa loại ca chưa gán ngày. Lấy hết
  /// rồi lọc ở đây rẻ hơn nhiều so với việc bỏ sót ca học sinh đang phải vào thi.
  Future<List<ExamSchedule>> getUpcomingExams() async {
    final data = await _client.query('''
      query MyUpcomingSchedules {
        myExamSchedules {
          id
          startDate
          endDate
          status
          exam { id name description kind status }
        }
      }
    ''');

    final rows = (data['myExamSchedules'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ExamSchedule.fromScheduleJson)
        .toList();

    // Bỏ ca đã kết thúc. Mốc so là `closeAt` (endDate của ca) chứ không phải `openAt`: ca bắt
    // đầu lúc 8h và kết thúc 10h thì lúc 9h vẫn phải hiện, vì học sinh còn đang thi.
    final now = DateTime.now();
    final upcoming = rows.where((e) {
      final end = e.closeAt ?? e.openAt;
      return end == null || !end.isBefore(now);
    }).toList();

    // Gần nhất lên trước; ca chưa có ngày xuống cuối.
    upcoming.sort(
      (a, b) => (a.openAt ?? a.closeAt ?? DateTime(9999))
          .compareTo(b.openAt ?? b.closeAt ?? DateTime(9999)),
    );
    return upcoming;
  }
}
