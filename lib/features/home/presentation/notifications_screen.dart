import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/notifications/notification_store.dart';
import '../../../l10n/app_localizations.dart';
import '../../result/presentation/results_screen.dart';
import '../../appeal/presentation/appeals_screen.dart';
import '../../practice/presentation/speaking_screen.dart';

/// Notifications — exam reminders, results, appeal updates.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          l10n.notificationsTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: NotificationStore.instance.markAllRead,
            child: Text(
              l10n.notificationsMarkAllRead,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.indigo,
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Notif>>(
        valueListenable: NotificationStore.instance.items,
        builder: (context, all, _) {
          final unread = all.where((n) => n.unread).toList();
          final read = all.where((n) => !n.unread).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              if (unread.isNotEmpty) ...[
                _group(context, l10n.notificationsGroupNew, unread),
                const SizedBox(height: 22),
              ],
              if (read.isNotEmpty) _group(context, l10n.notificationsGroupEarlier, read),
            ],
          );
        },
      ),
    );
  }

  Widget _group(BuildContext context, String label, List<Notif> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
        ),
        for (int i = 0; i < items.length; i++) ...[
          _NotifTile(items[i]),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

extension _KindMeta on NKind {
  IconData get icon => switch (this) {
        NKind.reminder => Icons.event_outlined,
        NKind.result => Icons.assignment_turned_in_outlined,
        NKind.appeal => Icons.gavel_outlined,
        NKind.streak => Icons.local_fire_department_outlined,
        NKind.newExam => Icons.assignment_outlined,
        NKind.examAssignment => Icons.assignment_ind_outlined,
      };
  Color get fg => switch (this) {
        NKind.reminder => AppColors.indigo,
        NKind.result => AppColors.success,
        NKind.appeal => AppColors.accent,
        NKind.streak => AppColors.warning,
        NKind.newExam => AppColors.indigo,
        NKind.examAssignment => AppColors.indigo,
      };
  Color get bg => switch (this) {
        NKind.reminder => AppColors.chipBlueBg,
        NKind.result => const Color(0xFFECFDF5),
        NKind.appeal => const Color(0xFFF5F3FF),
        NKind.streak => AppColors.warnBg,
        NKind.newExam => AppColors.chipBlueBg,
        NKind.examAssignment => AppColors.chipBlueBg,
      };
}

class _NotifTile extends StatelessWidget {
  const _NotifTile(this.n);
  final Notif n;

  void _go(BuildContext context) {
    NotificationStore.instance.markRead(n.id);
    Widget? page = switch (n.target) {
      // TODO: notifications carry no sessionId yet; wire once they do.
      NTarget.results => null,
      NTarget.appeals => const AppealsScreen(),
      NTarget.speaking => const SpeakingScreen(),
      // TODO: no exam-detail screen exists yet; navigate there once it does.
      NTarget.exam => null,
      NTarget.none => null,
    };
    if (page != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _go(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: n.unread ? AppColors.chipBlueBg.withOpacity(0.4) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.unread ? const Color(0xFFC7D2FE) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: n.kind.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(n.kind.icon, size: 21, color: n.kind.fg),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: AppColors.dark,
                          ),
                        ),
                      ),
                      if (n.unread)
                        Container(
                          margin: const EdgeInsets.only(top: 5, left: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.indigo,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.body,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    n.time,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGhost,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
