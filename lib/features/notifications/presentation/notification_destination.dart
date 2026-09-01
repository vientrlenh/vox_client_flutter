import 'package:flutter/material.dart';

import '../../appeal/presentation/appeal_detail_screen.dart';
import '../../appeal/presentation/appeals_screen.dart';
import '../../result/presentation/results_list_screen.dart';
import '../../result/presentation/results_screen.dart';
import '../data/models/app_notification.dart';

/// Tên hiển thị khi payload không mang `examName`.
///
/// Dòng notification ghi trước khi backend gửi khoá này sẽ mãi mãi thiếu nó (cột payload
/// không được backfill). Màn hình kết quả tự nạp điểm theo `sessionId`, nên thiếu tên chỉ
/// làm phần tiêu đề chung chung chứ không làm hỏng gì.
const _fallbackExamName = 'Bài kiểm tra';

/// Màn hình để mở cho một thông báo, hoặc `null` khi app này không có màn hình tương ứng.
///
/// <p>Bảng tra DUY NHẤT từ `target` của server sang màn hình của app. Server chốt "mở cái
/// gì", phía này chỉ dịch sang "mở widget nào" — y hệt `notificationTarget.ts` bên web,
/// nhưng ra kết quả khác, và đó chính là lý do server gửi target chứ không gửi URL: web có
/// hai route kết quả, app này có hai màn hình, còn các target quản trị thì app không có gì
/// cả.
///
/// <p>`null` có ba nguyên nhân, và cả ba đều phải dẫn tới "mở danh sách thông báo" chứ
/// không phải mở bừa: payload không có target, target mới mà bản app này chưa biết, và
/// target chỉ tồn tại trên web (chấm bài, blueprint, hoá đơn, các trang quản trị).
Widget? notificationDestination(Map<String, String> payload) {
  final target = NotificationTarget.parse(payload['target']);
  if (target == null) return null;

  return switch (target) {
    NotificationTarget.examResultDetail => _resultScreen(payload),
    NotificationTarget.examAppealDetail => _appealScreen(payload),

    // Chấm bài là việc của giáo viên trên web: app chỉ có danh sách kỳ thi, không có màn
    // hình chấm từng bài, cũng không có hàng đợi chấm của cả bài thi.
    NotificationTarget.teacherGradingTask => null,
    NotificationTarget.examHumanGradingRequired => null,

    // Bốn target dưới đây gửi cho school admin / system admin. App này chỉ dành cho học
    // sinh và giáo viên nên sẽ không bao giờ nhận, nhưng vẫn liệt kê đủ để `switch` không
    // có nhánh mặc định — thêm target mới bên backend sẽ báo lỗi biên dịch ở đây.
    NotificationTarget.adminGradingAssignment => null,
    NotificationTarget.schoolBlueprintDetail => null,
    NotificationTarget.schoolInvoiceDetail => null,
    NotificationTarget.schoolBillingOverview => null,
    NotificationTarget.schoolSubscriptionDetail => null,
    NotificationTarget.systemSchoolAttention => null,
  };
}

/// Bài tập trung và bài kiểm tra lớp có hai màn hình riêng, phân biệt bằng `examKind`.
///
/// Thiếu `sessionId` thì lui về đúng danh sách của loại đó: mở sai khu vực còn khó hiểu hơn
/// là không mở gì.
Widget _resultScreen(Map<String, String> payload) {
  final isClassTest = ExamKind.parse(payload['examKind']) == ExamKind.classTest;
  final sessionId = payload['sessionId'];
  final examName = payload['examName'] ?? _fallbackExamName;

  if (sessionId == null || sessionId.isEmpty) {
    return isClassTest ? const MyClassTestsScreen() : const MyExamsScreen();
  }

  return isClassTest
      ? ClassTestResultScreen(sessionId: sessionId, examName: examName)
      : ExamResultScreen(sessionId: sessionId, examName: examName);
}

Widget _appealScreen(Map<String, String> payload) {
  final appealId = payload['appealId'];

  return appealId == null || appealId.isEmpty
      ? const AppealsScreen()
      : AppealDetailScreen(appealId: appealId);
}
