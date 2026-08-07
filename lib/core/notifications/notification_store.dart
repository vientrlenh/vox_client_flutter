import 'package:flutter/foundation.dart';

enum NKind { reminder, result, appeal, streak, newExam, examAssignment }

// No exam-detail screen exists yet; NTarget.exam just marks the intent so the
// tap handler has somewhere to grow into.
enum NTarget { none, results, appeals, speaking, exam }

class Notif {
  const Notif({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.unread = false,
    this.target = NTarget.none,
    this.examId,
  });

  final String id;
  final NKind kind;
  final String title;
  final String body;
  final String time;
  final bool unread;
  final NTarget target;
  final String? examId;

  Notif copyWith({bool? unread}) => Notif(
        id: id,
        kind: kind,
        title: title,
        body: body,
        time: time,
        unread: unread ?? this.unread,
        target: target,
        examId: examId,
      );
}

/// Shared, mutable notification list — no state-management lib in this app,
/// so a singleton + ValueNotifier is the plain-Dart equivalent.
class NotificationStore {
  NotificationStore._();
  static final instance = NotificationStore._();

  final ValueNotifier<List<Notif>> items = ValueNotifier(_seed());

  static List<Notif> _seed() => [
        const Notif(
          id: 'seed-1',
          kind: NKind.reminder,
          title: 'Final Oral Proficiency Test starts soon',
          body: 'Tomorrow at 9:00 AM · Room 201. Be ready 10 minutes early.',
          time: '5m ago',
          unread: true,
          target: NTarget.speaking,
        ),
        const Notif(
          id: 'seed-2',
          kind: NKind.appeal,
          title: 'Your appeal was approved',
          body: 'Mid-term Speaking Exam re-scored from 6.5 → 7.5 by Ms. Linh.',
          time: '2h ago',
          unread: true,
          target: NTarget.appeals,
        ),
        const Notif(
          id: 'seed-3',
          kind: NKind.result,
          title: 'Results ready: Talking About Social Media',
          body: 'You scored 7.7 / 10 — above class average. Tap to review.',
          time: 'Yesterday',
          target: NTarget.results,
        ),
        const Notif(
          id: 'seed-4',
          kind: NKind.appeal,
          title: 'Appeal under review',
          body: 'A teacher is checking your Role-Play: At the Airport request.',
          time: 'Jun 24',
          target: NTarget.appeals,
        ),
        const Notif(
          id: 'seed-5',
          kind: NKind.reminder,
          title: 'New homework assigned',
          body: 'Practice: Telling a Story · due Jun 28.',
          time: 'Jun 23',
          target: NTarget.speaking,
        ),
        const Notif(
          id: 'seed-6',
          kind: NKind.streak,
          title: '12-day streak! 🔥',
          body: 'You’ve practiced every day for 12 days. Keep it going!',
          time: 'Jun 23',
        ),
      ];

  void markRead(String id) {
    items.value = [
      for (final n in items.value) n.id == id ? n.copyWith(unread: false) : n,
    ];
  }

  void markAllRead() {
    items.value = [for (final n in items.value) n.copyWith(unread: false)];
  }
}
