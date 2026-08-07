import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/graphql_client.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/data/profile_api.dart';
import '../../profile/data/profile_repository.dart';
import '../../teacher_exam/data/teacher_exam_graphql_api.dart';
import '../data/models/exam_schedule.dart';
import '../data/models/exam_room_schedule.dart';
import '../data/schedule_api.dart';
import '../data/schedule_repository.dart';

String _monthYearLabel(BuildContext context, DateTime d) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toString()).format(d);

String _monthDayLabel(BuildContext context, DateTime d) =>
    DateFormat.MMMd(Localizations.localeOf(context).toString()).format(d);

String _weekdayShortLabel(BuildContext context, DateTime d) =>
    DateFormat.E(Localizations.localeOf(context).toString()).format(d);

String _weekdayHeaderLabel(BuildContext context, int sundayIndex) {
  if (Localizations.localeOf(context).languageCode == 'vi') {
    return sundayIndex == 0 ? 'CN' : 'T${sundayIndex + 1}';
  }
  return _weekdayShortLabel(context, DateTime(2024, 1, 7 + sundayIndex));
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _ScheduleEntry {
  final String name;
  final String? description;
  final ExamKind kind;
  final ExamLifecycleStatus status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? roomLabel;

  const _ScheduleEntry({
    required this.name,
    this.description,
    required this.kind,
    required this.status,
    this.startAt,
    this.endAt,
    this.roomLabel,
  });

  factory _ScheduleEntry.fromTeacherItem(TeacherScheduleItem item) =>
      _ScheduleEntry(
        name: item.exam.name,
        description: item.exam.description,
        kind: item.exam.kind,
        status: item.exam.status,
        startAt: item.schedule.startDate,
        endAt: item.schedule.endDate,
        roomLabel: item.schedule.roomCode ?? item.schedule.roomName,
      );

  factory _ScheduleEntry.fromStudentItem(
    ExamRoomSchedule schedule,
    ExamSchedule exam,
  ) => _ScheduleEntry(
        name: exam.name,
        description: exam.description,
        kind: exam.kind,
        status: exam.status,
        startAt: schedule.startDate,
        endAt: schedule.endDate,
        roomLabel: schedule.roomCode ?? schedule.roomName,
      );
}

/// Tab 2 — Schedule.
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _profileRepository = ProfileRepository(ProfileApi(GraphQLClient()));
  final _repository = ScheduleRepository(
    ScheduleApi(GraphQLClient()),
    TeacherExamGraphQLApi(GraphQLClient()),
  );

  final DateTime _today = DateTime.now();
  late final DateTime _weekStart =
      _today.subtract(Duration(days: _today.weekday - 1));

  int _selectedDay = 0;
  List<_ScheduleEntry> _entries = const [];
  Map<DateTime, List<_ScheduleEntry>> _entriesByDay = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = _today.weekday - 1;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _profileRepository.getProfile();
      final entries = <_ScheduleEntry>[];
      if (profile.roleCode == 'TEACHER') {
        final schoolId = profile.schoolId;
        if (schoolId == null) throw StateError('No school on profile');
        final items = await _repository.getTeacherCentralizedSchedule(
          schoolId: schoolId,
          myUserId: profile.id,
        );
        entries.addAll(items.map(_ScheduleEntry.fromTeacherItem));
      } else {
        final schedules = await _repository.getStudentSchedule();
        for (final schedule in schedules) {
          final exam = schedule.exam;
          if (exam != null) {
            entries.add(_ScheduleEntry.fromStudentItem(schedule, exam));
          }
        }
      }
      final byDay = <DateTime, List<_ScheduleEntry>>{};
      for (final e in entries) {
        if (e.startAt == null) continue;
        final day = DateTime(e.startAt!.year, e.startAt!.month, e.startAt!.day);
        (byDay[day] ??= []).add(e);
      }
      for (final list in byDay.values) {
        list.sort((a, b) => a.startAt!.compareTo(b.startAt!));
      }
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _entriesByDay = byDay;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_ScheduleEntry> _examsOn(DateTime day) =>
      _entriesByDay[DateTime(day.year, day.month, day.day)] ?? const [];

  void _openMonth() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MonthSheet(exams: _entries, month: _today),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tomorrow = _today.add(const Duration(days: 1));
    final selectedDate = _weekStart.add(Duration(days: _selectedDay));

    // Bám theo NGÀY ĐANG CHỌN, không phải hôm nay.
    //
    // Bản trước luôn dựng hai mục "Hôm nay"/"Ngày mai" cố định, còn `_selectedDay` chỉ đổi ô
    // được tô đậm trên thanh ngày. Nên bấm lùi về thứ Hai vẫn thấy đúng lịch thứ Năm -- thanh
    // ngày trông như bấm được nhưng thực ra không dẫn đi đâu cả.
    final selectedSessions = _examsOn(selectedDate);
    final isToday = _isSameDate(selectedDate, _today);
    final isTomorrow = _isSameDate(selectedDate, tomorrow);
    final sectionTitle = isToday
        ? l10n.scheduleToday(_monthDayLabel(context, selectedDate))
        : isTomorrow
            ? l10n.scheduleTomorrow(_monthDayLabel(context, selectedDate))
            : l10n.scheduleOnDate(
                _weekdayShortLabel(context, selectedDate),
                _monthDayLabel(context, selectedDate),
              );
    final emptyText = isToday
        ? l10n.scheduleNoSessionsToday
        : isTomorrow
            ? l10n.scheduleNoSessionsTomorrow
            : l10n.scheduleNoSessionsOnDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── App bar ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.scheduleTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  IconCircle(Icons.calendar_today_outlined, onTap: _openMonth),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _monthYearLabel(context, _today),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < 7; i++)
                    Expanded(
                      child: _DayButton(
                        label: _weekdayShortLabel(context, _weekStart.add(Duration(days: i))),
                        date: _weekStart.add(Duration(days: i)),
                        hasEvent: _examsOn(_weekStart.add(Duration(days: i))).isNotEmpty,
                        selected: i == _selectedDay,
                        onTap: () => setState(() => _selectedDay = i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Scroll body ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l10n.scheduleLoadError(_error!),
                              style: const TextStyle(color: AppColors.textFaint)),
                          const SizedBox(height: 8),
                          TextButton(onPressed: _load, child: Text(l10n.scheduleRetry)),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        SectionLabel(sectionTitle),
                        const SizedBox(height: 16),
                        if (selectedSessions.isEmpty)
                          Text(emptyText,
                              style: const TextStyle(color: AppColors.textFaint))
                        else
                          for (final e in selectedSessions) ...[
                            // Tô đậm chỉ khi đang xem hôm nay: nó nghĩa là "buổi này đang tới
                            // gần", không phải "đây là ngày bạn vừa bấm" -- ngày nào bấm cũng
                            // tô thì màu đó hết mang tin gì.
                            _SessionCard(exam: e, highlighted: isToday),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
        ),
      ],
    );
  }
}

String _kindLabel(BuildContext context, ExamKind kind) {
  final l10n = AppLocalizations.of(context)!;
  return kind == ExamKind.centralized ? l10n.scheduleKindCentralized : l10n.scheduleKindClassTest;
}

/// Trạng thái của MỘT CA THI, không phải của cả kỳ thi.
///
/// Trước 2026-08-06 hàm này chỉ đọc `ExamLifecycleStatus`, tức trạng thái của **cả kỳ thi**.
/// Một kỳ thi `IN_PROGRESS` có thể trải nhiều ngày và nhiều ca; ca sáng đã đóng từ lâu vẫn
/// hiện "Đang diễn ra" vì kỳ thi nói chung vẫn đang diễn ra. Sai ở chỗ trộn hai cấp: thẻ này
/// nói về ca thi, còn cột nó đọc lại nói về kỳ thi.
///
/// Nay giờ của ca là căn cứ chính; trạng thái kỳ thi chỉ được phép **thu hẹp**:
/// kỳ đã đóng/huỷ/công bố thì mọi ca đều đóng, kỳ chưa mở thì mọi ca đều là sắp tới —
/// đồng hồ không cứu được một kỳ thi chưa publish.
_SessionStatus _statusFor(_ScheduleEntry entry) {
  switch (entry.status) {
    case ExamLifecycleStatus.closed:
    case ExamLifecycleStatus.resultsPublished:
    case ExamLifecycleStatus.cancelled:
      return _SessionStatus.closed;
    case ExamLifecycleStatus.scheduled:
    case ExamLifecycleStatus.draft:
      return _SessionStatus.upcoming;
    case ExamLifecycleStatus.inProgress:
      break;
  }

  final now = DateTime.now();
  final start = entry.startAt;
  final end = entry.endAt;
  // Ca chưa xếp giờ (startDate/endDate nullable ở schema): không có gì để so, giữ nguyên
  // kết luận theo kỳ thi thay vì đoán.
  if (start == null && end == null) return _SessionStatus.open;
  if (start != null && now.isBefore(start)) return _SessionStatus.upcoming;
  if (end != null && now.isAfter(end)) return _SessionStatus.closed;
  return _SessionStatus.open;
}

String _timeLabel(BuildContext context, DateTime? d) {
  if (d == null) return AppLocalizations.of(context)!.scheduleTimeUnset;
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Full-month calendar shown from the app-bar button.
/// Tapping a day with an exam shows its info at the top of the sheet.
class _MonthSheet extends StatefulWidget {
  const _MonthSheet({required this.exams, required this.month});

  final List<_ScheduleEntry> exams;
  final DateTime month;

  @override
  State<_MonthSheet> createState() => _MonthSheetState();
}

class _MonthSheetState extends State<_MonthSheet> {
  late DateTime _month = DateTime(widget.month.year, widget.month.month);
  late int _selectedDay = widget.month.day;

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
      if (_selectedDay > daysInMonth) _selectedDay = daysInMonth;
    });
  }

  void _goToToday() {
    setState(() {
      _month = DateTime(widget.month.year, widget.month.month);
      _selectedDay = widget.month.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday: Mon=1..Sun=7; grid starts on Sunday (0-based).
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7;
    final weekdayLabels = [
      for (int i = 0; i < 7; i++) _weekdayHeaderLabel(context, i),
    ];

    final eventDays = <int>{
      for (final e in widget.exams)
        if (e.startAt != null &&
            e.startAt!.year == _month.year &&
            e.startAt!.month == _month.month)
          e.startAt!.day,
    };

    final examsForSelected = widget.exams
        .where((e) =>
            e.startAt != null &&
            e.startAt!.year == _month.year &&
            e.startAt!.month == _month.month &&
            e.startAt!.day == _selectedDay)
        .toList();
    final exam = examsForSelected.isEmpty ? null : examsForSelected.first;

    final cells = <int?>[
      for (int i = 0; i < firstWeekday; i++) null,
      for (int d = 1; d <= daysInMonth; d++) d,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthYearLabel(context, _month),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              InkWell(
                onTap: _goToToday,
                borderRadius: BorderRadius.circular(99),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  child: Text(
                    l10n.scheduleJumpToday,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.indigo,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _NavArrow(Icons.chevron_left, onTap: () => _changeMonth(-1)),
              const SizedBox(width: 6),
              _NavArrow(Icons.chevron_right, onTap: () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 16),
          if (exam != null) ...[
            _ExamInfoBanner(exam),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              for (final w in weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textGhost,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: [
              for (final cell in cells)
                if (cell == null)
                  const SizedBox()
                else
                  _MonthCell(
                    day: cell,
                    selected: cell == _selectedDay,
                    hasEvent: eventDays.contains(cell),
                    onTap: () => setState(() => _selectedDay = cell),
                  ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.indigo,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                l10n.scheduleLegendHasSession,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.selected,
    required this.hasEvent,
    required this.onTap,
  });

  final int day;
  final bool selected;
  final bool hasEvent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.indigo
                  : hasEvent
                      ? AppColors.chipBlueBg
                      : Colors.transparent,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    hasEvent || selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : hasEvent
                        ? AppColors.indigo
                        : const Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  hasEvent && !selected ? AppColors.indigo : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown at the top of the month sheet for the tapped day's exam.
class _ExamInfoBanner extends StatelessWidget {
  const _ExamInfoBanner(this.exam);
  final _ScheduleEntry exam;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.chipBlueBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _timeLabel(context, exam.startAt),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                if (exam.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    exam.description!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    TagChip.blue(_kindLabel(context, exam.kind)),
                    if (exam.roomLabel != null)
                      TagChip(AppLocalizations.of(context)!.scheduleRoomLabel(exam.roomLabel!)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow(this.icon, {required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFF1F5F9),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF475569)),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.label,
    required this.date,
    required this.hasEvent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final bool hasEvent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: selected ? AppColors.indigo : AppColors.textGhost,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.indigo : Colors.transparent,
              ),
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF333333),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasEvent ? AppColors.indigo : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SessionStatus { open, upcoming, closed }

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.exam, this.highlighted = false});

  final _ScheduleEntry exam;
  final bool highlighted;

  TagChip _statusChip(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_statusFor(exam)) {
      case _SessionStatus.open:
        return TagChip(
          l10n.scheduleStatusOpen,
          bg: AppColors.chipGreenBg,
          fg: AppColors.chipGreenFg,
          dot: true,
        );
      case _SessionStatus.upcoming:
        return TagChip(
          l10n.scheduleStatusUpcoming,
          bg: AppColors.chipBlueBg,
          fg: AppColors.chipBlueFg,
          dot: true,
        );
      case _SessionStatus.closed:
        return TagChip(
          l10n.scheduleStatusClosed,
          bg: AppColors.statusClosedBg,
          fg: AppColors.statusClosedFg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimmed = _statusFor(exam) == _SessionStatus.closed;
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.chipBlueBg : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? AppColors.indigo : AppColors.border,
            width: 1.5,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(
                      _timeLabel(context, exam.startAt),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        constraints: const BoxConstraints(minHeight: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(context, exam.endAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textGhost,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (exam.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        exam.description!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _statusChip(context),
                        if (exam.roomLabel == null) TagChip(_kindLabel(context, exam.kind)),
                        if (exam.roomLabel != null)
                          TagChip.blue(AppLocalizations.of(context)!.scheduleRoomLabel(exam.roomLabel!)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
