import 'dart:async';

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

  /// Tự hỏi lại backend trong lúc kho chủ đề còn trống -- cùng cơ chế với
  /// `PracticeTopicsScreen._syncPolling`, vì cùng một tình huống: `getDashboard` đã kích hoạt
  /// việc soạn chạy nền ở backend (nó gọi `practiceTopicOffers`, và use case đó gọi
  /// `TopicOfferBackfillService.backfillAsync` khi lô chào còn thưa) nhưng không có kênh đẩy
  /// ngược về client, nên hỏi lại theo nhịp là cách duy nhất để màn tự hiện chủ đề.
  ///
  /// Nói "quay lại sau 1 phút" mà bắt bấm Tải lại mới thấy là hứa một đằng làm một nẻo.
  Timer? _pollTimer;

  /// 12 lượt × 5 giây = 60 giây, khớp đúng con số hứa với người dùng. Hết lượt thì dừng hẳn để
  /// không quay vô hạn khi backend thật sự hỏng (agents chết, hạn mức LLM cạn) -- lúc đó kéo
  /// xuống để làm mới vẫn còn đó.
  static const _maxPolls = 12;
  static const _pollInterval = Duration(seconds: 5);
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Đúng trạng thái "khảo sát xong nhưng kho chủ đề chưa có gì".
  ///
  /// Phải rỗng CẢ HAI: `todayTopic` và `suggestions` đều lấy từ cùng một lượt
  /// `practiceTopicOffers` (xem `PersonalizeRepository.getDashboard`), nên chỉ cần có một chủ đề
  /// là `todayTopic` đã có -- lúc đó không còn gì đang soạn để mà chờ.
  bool get _showsPreparing =>
      _error == null &&
      _dashboard != null &&
      _dashboard!.todayTopic == null &&
      _dashboard!.suggestions.isEmpty;

  void _syncPolling() {
    if (_showsPreparing) {
      _pollTimer ??= Timer.periodic(_pollInterval, (timer) {
        if (!mounted || _pollCount >= _maxPolls) {
          timer.cancel();
          _pollTimer = null;
          return;
        }
        _pollCount++;
        _load(silent: true);
      });
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  /// [silent] giữ nguyên màn đang hiện thay vì thay bằng vòng xoay: không có cờ này thì cứ 5
  /// giây thông báo "đang soạn" lại bị đè một nhịp, nhìn như app giật chứ không phải đang chờ.
  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
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
      if (mounted) {
        setState(() => _loading = false);
        _syncPolling();
      }
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
                  // Kho chưa có chủ đề nào -- nói thẳng là hệ thống đang soạn, KHÔNG dùng
                  // _NoTopicYetCard.
                  //
                  // Hai tình huống nhìn giống nhau mà khác hẳn nhau: _NoTopicYetCard nghĩa là
                  // "có chủ đề đấy, hôm nay bạn chưa chọn cái nào" và mời bấm sang màn chọn --
                  // sang tới nơi thì cũng trống trơn. Ở đây là "chưa có chủ đề nào tồn tại",
                  // việc phải làm là ĐỢI chứ không phải bấm đi đâu cả.
                  //
                  // Cũng bỏ luôn mục "Gợi ý cho bạn" trong lúc này: một tiêu đề mục với khoảng
                  // trống bên dưới trông như app lỗi.
                  if (_showsPreparing) ...[
                    _PreparingTopicsCard(
                      title: l10n.pzHomePreparingTitle,
                      body: l10n.pzHomePreparingBody,
                      onRetry: _load,
                      retryLabel: l10n.pzTopicsRefresh,
                    ),
                    const SizedBox(height: 12),
                    _StatRow(dashboard: data),
                  ] else ...[
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

/// Kho chủ đề còn TRỐNG HẲN -- vừa làm xong khảo sát sở thích, backend đang soạn lô đầu tiên.
///
/// Khác `_NoTopicYetCard` ở chỗ quan trọng nhất là VIỆC PHẢI LÀM: cái kia mời bấm sang màn chọn
/// chủ đề, còn ở đây sang tới nơi cũng trống, nên chỉ mời đợi. Nút "Tải lại" là lối thoát cho
/// trường hợp vòng hỏi tự động đã hết lượt, không phải thao tác bắt buộc.
class _PreparingTopicsCard extends StatelessWidget {
  const _PreparingTopicsCard({
    required this.title,
    required this.body,
    required this.onRetry,
    required this.retryLabel,
  });

  final String title;
  final String body;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.chipBlueBg, Color(0xFFF5F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.indigo, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Vòng xoay CHẠY THẬT chứ không phải icon tĩnh: nó là thứ duy nhất trên màn nói
              // được "hệ thống đang làm việc", chứ không phải "đã xong và không có gì".
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF4C4A75),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(retryLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.indigo,
              side: const BorderSide(color: AppColors.indigo),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
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
