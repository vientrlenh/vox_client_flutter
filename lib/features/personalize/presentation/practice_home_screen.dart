import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/practice_band_option.dart';
import '../data/models/practice_dashboard.dart';
import '../data/models/practice_topic.dart';
import '../data/personalize_repository.dart';
import 'personalize_styles.dart';
import 'personalize_widgets.dart';
import 'practice_session_screen.dart';
import 'practice_topics_screen.dart';
import 'topic_intro_screen.dart';

/// Tab 2 — the personalized speaking home (design `1b`, screen 1).
class PracticeHomeScreen extends StatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  State<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends State<PracticeHomeScreen> {
  final _repository = PersonalizeRepository();

  bool _loading = true;
  String? _error;
  PracticeDashboard? _dashboard;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dashboard = await _repository.getDashboard();
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Cửa DUY NHẤT vào phiên luyện: mọi lối chọn chủ đề (thẻ hôm nay, thẻ gợi ý, màn chọn
  /// chủ đề, tìm từ khoá, chọn ngẫu nhiên) đều đi qua đây.
  ///
  /// Chèn một TRANG xác nhận thay cho bảng trượt cũ (`showBandPickerSheet`): bảng trượt bật
  /// lên đè ngay lên màn cũ nên với chủ đề đến từ nút "Chọn ngẫu nhiên" hay từ màn chọn chủ
  /// đề, học sinh không kịp thấy mình sắp luyện gì. Trang đặt tên chủ đề, lý do được chào và
  /// độ khó cạnh nhau.
  ///
  /// Quay lại từ trang đó = huỷ vào phiên, không lặng lẽ vào bằng một bậc mặc định.
  Future<void> _openSession(PracticeTopic topic) async {
    final band = await Navigator.of(context).push<PracticeBandOption>(
      MaterialPageRoute(builder: (_) => TopicIntroScreen(topic: topic)),
    );
    if (band == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticeSessionScreen(
          topic: topic,
          targetFrameworkBandId: band.id,
        ),
      ),
    );
  }

  Future<void> _openTopics() async {
    final picked = await Navigator.of(context).push<PracticeTopic>(
      MaterialPageRoute(builder: (_) => const PracticeTopicsScreen()),
    );
    if (picked != null && mounted) _openSession(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dashboard = _dashboard;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          name: dashboard?.learnerName ?? '…',
          streakDays: dashboard?.streakDays ?? 0,
        ),
        Expanded(
          child: switch ((_loading, _error, dashboard)) {
            (true, _, _) => const Center(child: CircularProgressIndicator()),
            (_, final String error, _) => PersonalizeErrorView(
              detail: error,
              onRetry: _load,
            ),
            (_, _, null) => PersonalizeErrorView(onRetry: _load),
            (_, _, final PracticeDashboard data) => RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: pagePadding,
                children: [
                  if (data.todayTopic != null)
                    _TodaySessionCard(
                      topic: data.todayTopic!,
                      onStart: () => _openSession(data.todayTopic!),
                      onChangeTopic: _openTopics,
                    )
                  else
                    _NoTopicYetCard(onBrowse: _openTopics),
                  const SizedBox(height: 12),
                  _StatRow(dashboard: data),
                  const SizedBox(height: 22),
                  _SectionHeader(
                    label: l10n.pzHomeSuggestions,
                    action: l10n.pzSeeAll,
                    onAction: _openTopics,
                  ),
                  const SizedBox(height: 10),
                  for (final topic in data.suggestions) ...[
                    _SuggestionCard(
                      topic: topic,
                      onTap: () => _openSession(topic),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          },
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.streakDays});

  final String name;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.navPractice,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.chipOrangeBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 17,
                  color: AppColors.chipOrangeFg,
                ),
                const SizedBox(width: 6),
                Text(
                  '$streakDays',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.chipOrangeFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of `_TodaySessionCard` when `practiceTopicOffers` has
/// nothing yet (brand new student, no interest signal to rank on).
class _NoTopicYetCard extends StatelessWidget {
  const _NoTopicYetCard({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.pzHomeNoTopicYet,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: onBrowse,
            child: Text(
              l10n.pzSeeAll,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The black "PHIÊN HÔM NAY" card.
class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({
    required this.topic,
    required this.onStart,
    required this.onChangeTopic,
  });

  final PracticeTopic topic;
  final VoidCallback onStart;
  final VoidCallback onChangeTopic;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  l10n.pzHomeSessionToday,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.pzHomePersonalizedBadge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF67E8F9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            topic.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.pzHomeSessionMeta,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _PillButton(
                label: l10n.pzHomeStartSpeaking,
                icon: Icons.mic,
                onTap: onStart,
                filled: true,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: _PillButton(
                  label: l10n.pzHomeChangeTopic,
                  onTap: onChangeTopic,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White-filled or outlined pill used inside the dark session card.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.filled,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: filled
            ? BorderSide.none
            : BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          height: 38,
          padding: EdgeInsets.symmetric(horizontal: filled ? 20 : 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 17,
                  color: filled ? AppColors.ink : Colors.white,
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                    color: filled
                        ? AppColors.ink
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.dashboard});
  final PracticeDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: StatBox(
            value: '${dashboard.sessionsDone}',
            caption: l10n.pzHomeStatSessions,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            value: dashboard.averageScore.toStringAsFixed(1),
            caption: l10n.pzHomeStatAverage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatBox(
            value: '${dashboard.sessionsThisWeek}',
            caption: l10n.pzHomeStatWeeklyGoal,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action, this.onAction});

  final String label;

  /// Nhãn + hành động của đường dẫn bên phải. Bỏ trống thì chỉ hiện tiêu đề -- dải "tập
  /// trung tuần này" giờ không còn trang chi tiết nào để dẫn tới.
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: SectionLabel(label)),
        if (action != null && onAction != null)
        InkWell(
          onTap: onAction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.indigo,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.topic, required this.onTap});

  final PracticeTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: rowDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topic.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFFCCCCCC),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final reason in topic.reasons) TagChip.blue(reason),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
