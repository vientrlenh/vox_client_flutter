import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vox_client_flutter/core/messaging/notification_signal.dart';
import 'package:vox_client_flutter/features/notifications/data/models/app_notification.dart';

Map<String, dynamic> _json({
  String id = 'n-1',
  String? eventType = 'ExamResultReleased',
  String? payload,
  String? readAt,
  String? createdAt = '2026-08-12T03:04:05Z',
}) {
  return {
    'id': id,
    'eventType': eventType,
    'title': 'Điểm thi của bạn đã có',
    'body': 'Cuối kỳ: 7.5 điểm',
    'payload': payload,
    'readAt': readAt,
    'createdAt': createdAt,
  };
}

void main() {
  group('AppNotification', () {
    test('readAt null means unread', () {
      expect(AppNotification.fromJson(_json()).unread, isTrue);
      expect(
        AppNotification.fromJson(_json(readAt: '2026-08-12T04:00:00Z')).unread,
        isFalse,
      );
    });

    test('maps backend eventType to a display kind', () {
      NotificationKind kindOf(String? eventType) =>
          AppNotification.fromJson(_json(eventType: eventType)).kind;

      expect(kindOf('ExamResultRegraded'), NotificationKind.examResult);
      expect(kindOf('ExamAppealApproved'), NotificationKind.appeal);
      expect(kindOf('GradingDeadlineReminder'), NotificationKind.grading);
      expect(kindOf('InvoicePaid'), NotificationKind.invoice);
      // Event backend thêm sau này vẫn phải hiện được, chỉ là không có icon riêng.
      expect(kindOf('SomethingBrandNew'), NotificationKind.other);
      expect(kindOf(null), NotificationKind.other);
    });

    test('reads the navigation key out of the payload JSON', () {
      final notification = AppNotification.fromJson(_json(
        payload: jsonEncode({
          'eventType': 'ExamAppealApproved',
          'target': 'EXAM_APPEAL_DETAIL',
          'appealId': 'a-9',
        }),
      ));

      expect(notification.payload['appealId'], 'a-9');
      expect(notification.target, NotificationTarget.examAppealDetail);
    });

    test('a broken payload costs the navigation key, not the whole row', () {
      final notification = AppNotification.fromJson(_json(payload: 'not json'));

      expect(notification.payload, isEmpty);
      expect(notification.target, isNull);
      expect(notification.title, 'Điểm thi của bạn đã có');
    });

    test('copyWith(readAt) flips a single entry to read', () {
      final unread = AppNotification.fromJson(_json());
      final read = unread.copyWith(readAt: DateTime.now());

      expect(unread.unread, isTrue);
      expect(read.unread, isFalse);
      expect(read.id, unread.id);
    });
  });

  group('NotificationPage', () {
    test('parses a cursor page', () {
      final page = NotificationPage.fromJson({
        'content': [_json(id: 'n-1'), _json(id: 'n-2')],
        'nextCursor': 'n-2',
        'hasNext': true,
      });

      expect(page.content.map((e) => e.id), ['n-1', 'n-2']);
      expect(page.nextCursor, 'n-2');
      expect(page.hasNext, isTrue);
    });

    test('a null page from the server reads as empty, not as a crash', () {
      final page = NotificationPage.fromJson({'content': null});

      expect(page.content, isEmpty);
      expect(page.hasNext, isFalse);
      expect(page.nextCursor, isNull);
    });
  });

  group('NotificationSignal', () {
    setUp(NotificationSignal.instance.clearUnread);

    test('a push bumps both the badge and the reload signal', () {
      final signal = NotificationSignal.instance;
      final revisionBefore = signal.revision.value;

      signal.onPushReceived();

      expect(signal.unreadCount.value, 1);
      expect(signal.revision.value, revisionBefore + 1);
    });

    test('the badge never goes below zero', () {
      final signal = NotificationSignal.instance;

      signal.decrementUnread();
      signal.decrementUnread();

      expect(signal.unreadCount.value, 0);
    });
  });
}
