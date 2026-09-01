import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Nhóm hiển thị của một thông báo, suy ra từ `eventType` backend gửi kèm.
///
/// Danh sách giá trị lấy từ `EventTypeConstant` bên vox. Event lạ (backend thêm
/// loại mới, client chưa cập nhật) rơi vào [other] và vẫn hiện bình thường --
/// tiêu đề/nội dung đã do server dựng sẵn nên không mất gì ngoài cái icon riêng.
enum NotificationKind { examResult, appeal, grading, blueprint, invoice, account, other }

/// Màn hình mà server muốn client mở khi bấm vào thông báo.
///
/// Tên trên dây khớp enum `NotificationTarget` bên backend. Server chốt "mở cái gì",
/// còn "mở màn hình nào của app này" là việc của [notificationDestination] --
/// nhiều target trong đây không có màn hình tương ứng trên mobile (blueprint, hoá
/// đơn, các trang quản trị) và đó là chuyện bình thường.
///
/// Trước đây target được suy ra từ [NotificationKind], tức là từ `eventType`. Cách
/// đó không phân biệt được hai event dùng chung một khoá id nhưng gửi cho hai vai
/// trò khác nhau, và mỗi client lại đoán một kiểu.
enum NotificationTarget {
  examResultDetail('EXAM_RESULT_DETAIL'),
  examAppealDetail('EXAM_APPEAL_DETAIL'),
  teacherGradingTask('TEACHER_GRADING_TASK'),
  examHumanGradingRequired('EXAM_HUMAN_GRADING_REQUIRED'),
  adminGradingAssignment('ADMIN_GRADING_ASSIGNMENT'),
  schoolBlueprintDetail('SCHOOL_BLUEPRINT_DETAIL'),
  schoolInvoiceDetail('SCHOOL_INVOICE_DETAIL'),
  schoolBillingOverview('SCHOOL_BILLING_OVERVIEW'),
  schoolSubscriptionDetail('SCHOOL_SUBSCRIPTION_DETAIL'),
  systemSchoolAttention('SYSTEM_SCHOOL_ATTENTION');

  const NotificationTarget(this.wireName);

  /// Giá trị đúng như backend gửi trong `payload['target']`.
  final String wireName;

  /// `null` khi thiếu target (dòng ghi trước khi backend gửi khoá này) hoặc khi
  /// backend đã thêm target mới mà bản app này chưa biết. Cả hai đều dẫn tới "không
  /// bấm được", không bao giờ dẫn tới mở bừa một màn hình.
  static NotificationTarget? parse(String? value) {
    if (value == null) return null;
    for (final target in NotificationTarget.values) {
      if (target.wireName == value) return target;
    }
    return null;
  }
}

/// Loại bài thi, quyết định mở màn hình kết quả nào.
enum ExamKind {
  centralized('CENTRALIZED'),
  classTest('CLASS_TEST');

  const ExamKind(this.wireName);

  final String wireName;

  static ExamKind? parse(String? value) {
    if (value == null) return null;
    for (final kind in ExamKind.values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// Một dòng trong `myNotifications` (NotificationDto).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String? eventType;
  final String title;
  final String body;

  /// `payload` bên backend là chuỗi JSON của đúng cái map đã gửi qua FCM:
  /// luôn có `eventType`, cộng thêm một khoá điều hướng tuỳ loại event.
  final Map<String, String> payload;

  final DateTime? createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  NotificationKind get kind => switch (eventType) {
        'ExamResultReleased' ||
        'ExamResultRegraded' ||
        'ExamResultInvalidated' ||
        'ExamResultInvalidCleared' ||
        'ExamResultOutcomeDecided' =>
          NotificationKind.examResult,
        'ExamAppealPublished' ||
        'ExamAppealRejected' ||
        'ExamAppealApproved' =>
          NotificationKind.appeal,
        'GradingDeadlineReminder' ||
        'GradingAssignmentDeclined' =>
          NotificationKind.grading,
        'ExamBlueprintVersionPublished' => NotificationKind.blueprint,
        'InvoicePaid' => NotificationKind.invoice,
        'UserCreated' || 'RegisterFormRejected' => NotificationKind.account,
        _ => NotificationKind.other,
      };

  /// Màn hình server muốn mở, đọc thẳng từ payload thay vì suy từ `eventType`.
  NotificationTarget? get target => NotificationTarget.parse(payload['target']);

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      eventType: json['eventType'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      payload: _decodePayload(json['payload'] as String?),
      createdAt: _parseTime(json['createdAt'] as String?),
      readAt: _parseTime(json['readAt'] as String?),
    );
  }

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
        id: id,
        eventType: eventType,
        title: title,
        body: body,
        payload: payload,
        createdAt: createdAt,
        readAt: readAt ?? this.readAt,
      );

  /// Payload hỏng không được phép làm hỏng cả danh sách: nó chỉ dùng để điều
  /// hướng, còn tiêu đề/nội dung -- phần người dùng thực sự đọc -- nằm ở cột riêng.
  static Map<String, String> _decodePayload(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      return {
        for (final entry in decoded.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Backend format bằng `Instant.toString()` -> ISO-8601 UTC. Đổi sang giờ máy
  /// ngay tại đây để tầng hiển thị không phải nhớ chuyện múi giờ.
  static DateTime? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}

/// Một trang của `myNotifications` (`CursorPage<NotificationDto>`).
@immutable
class NotificationPage {
  const NotificationPage({
    required this.content,
    required this.nextCursor,
    required this.hasNext,
  });

  final List<AppNotification> content;
  final String? nextCursor;
  final bool hasNext;

  static const empty = NotificationPage(content: [], nextCursor: null, hasNext: false);

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List? ?? const [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationPage(
      content: content,
      nextCursor: json['nextCursor'] as String?,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }
}
