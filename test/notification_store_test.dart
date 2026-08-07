import 'package:flutter_test/flutter_test.dart';
import 'package:vox_client_flutter/core/notifications/notification_store.dart';

Notif _addUnread(NotificationStore store, String id) {
  final n = Notif(
    id: id,
    kind: NKind.reminder,
    title: 'Test',
    body: 'Test body',
    time: 'Just now',
    unread: true,
  );
  store.items.value = [n, ...store.items.value];
  return n;
}

void main() {
  test('markRead clears only the matching entry', () {
    final store = NotificationStore.instance;
    final n = _addUnread(store, 'test-1');
    final otherUnread = store.items.value.firstWhere((e) => e.id != n.id && e.unread);
    store.markRead(n.id);
    expect(store.items.value.firstWhere((e) => e.id == n.id).unread, isFalse);
    expect(store.items.value.firstWhere((e) => e.id == otherUnread.id).unread, isTrue);
  });

  test('markAllRead clears every entry', () {
    final store = NotificationStore.instance;
    _addUnread(store, 'test-2');
    store.markAllRead();
    expect(store.items.value.every((e) => !e.unread), isTrue);
  });
}
