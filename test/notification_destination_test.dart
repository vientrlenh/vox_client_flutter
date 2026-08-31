import 'package:flutter_test/flutter_test.dart';
import 'package:vox_client_flutter/core/messaging/notification_service.dart';
import 'package:vox_client_flutter/core/messaging/pending_push_navigation.dart';
import 'package:vox_client_flutter/features/appeal/presentation/appeal_detail_screen.dart';
import 'package:vox_client_flutter/features/appeal/presentation/appeals_screen.dart';
import 'package:vox_client_flutter/features/notifications/data/models/app_notification.dart';
import 'package:vox_client_flutter/features/notifications/presentation/notification_destination.dart';
import 'package:vox_client_flutter/features/result/presentation/results_list_screen.dart';
import 'package:vox_client_flutter/features/result/presentation/results_screen.dart';

void main() {
  group('NotificationTarget.parse', () {
    test('đọc đúng tên trên dây của backend', () {
      expect(
        NotificationTarget.parse('EXAM_RESULT_DETAIL'),
        NotificationTarget.examResultDetail,
      );
      expect(
        NotificationTarget.parse('ADMIN_GRADING_ASSIGNMENT'),
        NotificationTarget.adminGradingAssignment,
      );
    });

    /// Backend thêm target mới trước khi bản app này lên store: mất khả năng bấm,
    /// không mở bừa một màn hình.
    test('trả null với target lạ hoặc thiếu', () {
      expect(NotificationTarget.parse('MOT_TARGET_MOI'), isNull);
      expect(NotificationTarget.parse(null), isNull);
    });
  });

  group('notificationDestination', () {
    test('mở đúng kết quả bài thi tập trung bằng sessionId', () {
      final screen = notificationDestination({
        'target': 'EXAM_RESULT_DETAIL',
        'examKind': 'CENTRALIZED',
        'sessionId': 's-1',
        'examName': 'Kỳ thi giữa kỳ',
      });

      expect(screen, isA<ExamResultScreen>());
      expect((screen! as ExamResultScreen).sessionId, 's-1');
      expect((screen as ExamResultScreen).examName, 'Kỳ thi giữa kỳ');
    });

    test('tách bài kiểm tra lớp sang màn hình riêng', () {
      final screen = notificationDestination({
        'target': 'EXAM_RESULT_DETAIL',
        'examKind': 'CLASS_TEST',
        'sessionId': 's-2',
      });

      expect(screen, isA<ClassTestResultScreen>());
      expect((screen! as ClassTestResultScreen).sessionId, 's-2');
    });

    test('mở đúng đơn phúc khảo bằng appealId', () {
      final screen = notificationDestination({
        'target': 'EXAM_APPEAL_DETAIL',
        'appealId': 'a-9',
      });

      expect(screen, isA<AppealDetailScreen>());
      expect((screen! as AppealDetailScreen).appealId, 'a-9');
    });

    /// Dòng ghi trước khi backend gửi khoá điều hướng sẽ mãi mãi thiếu chúng.
    test('lui về đúng danh sách khi payload cũ thiếu id', () {
      expect(
        notificationDestination({'target': 'EXAM_RESULT_DETAIL'}),
        isA<MyExamsScreen>(),
      );
      expect(
        notificationDestination({
          'target': 'EXAM_RESULT_DETAIL',
          'examKind': 'CLASS_TEST',
        }),
        isA<MyClassTestsScreen>(),
      );
      expect(
        notificationDestination({'target': 'EXAM_APPEAL_DETAIL'}),
        isA<AppealsScreen>(),
      );
    });

    /// App này dành cho học sinh và giáo viên: các target quản trị không có màn hình,
    /// và null ở đây được `openFromPush` dịch thành "mở danh sách thông báo".
    test('trả null cho target chỉ tồn tại trên web', () {
      for (final target in [
        'TEACHER_GRADING_TASK',
        'ADMIN_GRADING_ASSIGNMENT',
        'SCHOOL_BLUEPRINT_DETAIL',
        'SCHOOL_INVOICE_DETAIL',
        'SCHOOL_BILLING_OVERVIEW',
        'SCHOOL_SUBSCRIPTION_DETAIL',
        'SYSTEM_SCHOOL_ATTENTION',
      ]) {
        expect(notificationDestination({'target': target}), isNull, reason: target);
      }
    });

    test('trả null khi payload không có target', () {
      expect(notificationDestination(const {}), isNull);
      expect(notificationDestination({'appealId': 'a-9'}), isNull);
    });
  });

  group('NotificationService.decodePayload', () {
    /// Khay cục bộ chỉ chở được một chuỗi, nên cả map đi qua JSON. Trước đây chỗ này
    /// chỉ chở `eventType` và cú bấm không mở được gì ngoài danh sách.
    test('khôi phục lại toàn bộ khoá điều hướng từ chuỗi JSON', () {
      final decoded = NotificationService.decodePayload(
        '{"target":"EXAM_RESULT_DETAIL","sessionId":"s-1"}',
      );

      expect(decoded['target'], 'EXAM_RESULT_DETAIL');
      expect(decoded['sessionId'], 's-1');
    });

    test('payload hỏng hoặc rỗng cho map rỗng, không ném', () {
      expect(NotificationService.decodePayload('khong-phai-json'), isEmpty);
      expect(NotificationService.decodePayload(''), isEmpty);
      expect(NotificationService.decodePayload(null), isEmpty);
    });
  });

  group('PendingPushNavigation', () {
    setUp(PendingPushNavigation.take);

    /// Bấm vào thông báo lúc app đã tắt hẳn: `getInitialMessage()` chạy trước `runApp`
    /// nên chưa có navigator, payload phải sống tới lúc MainShell dựng xong.
    test('giữ payload rồi trả lại đúng một lần', () {
      PendingPushNavigation.remember({'target': 'EXAM_APPEAL_DETAIL'});

      expect(PendingPushNavigation.take(), {'target': 'EXAM_APPEAL_DETAIL'});
      // Lần thứ hai phải rỗng: MainShell được dựng lại mỗi lần đăng nhập, và một payload
      // còn sót lại sẽ bật lên màn hình cũ giữa phiên mới.
      expect(PendingPushNavigation.take(), isNull);
    });

    test('bỏ qua message không mang data', () {
      PendingPushNavigation.remember(const {});

      expect(PendingPushNavigation.take(), isNull);
    });
  });
}
