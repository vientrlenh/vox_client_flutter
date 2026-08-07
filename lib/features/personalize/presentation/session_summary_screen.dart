import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/session_summary.dart';
import '../data/personalize_repository.dart';
import 'personalize_styles.dart';
import 'personalize_widgets.dart';

/// Design `1f`, screen 1 — the post-session report.
class SessionSummaryScreen extends StatefulWidget {
  const SessionSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  /// Chấm chạy bất đồng bộ và về SAU khi phiên đóng vài chục giây (đo thật: kết thúc
  /// 11:03:25, chấm xong 11:04:10). Nên vào màn này ngay là gần như chắc chắn chưa có điểm.
  /// Hỏi lại vài giây một lần thay vì bắt học sinh tự kéo để làm mới.
  static const _pollInterval = Duration(seconds: 4);

  /// Trần chờ. Quá mốc này thì hiện những gì đang có kèm ghi chú, KHÔNG quay vô hạn: chấm có
  /// thể hỏng thật (Kafka nghẽn, Python chết), và một vòng xoay không bao giờ dừng là cách
  /// tệ nhất để nói điều đó.
  static const _maxWait = Duration(minutes: 3);

  final _repository = PersonalizeRepository();

  bool _loading = true;
  String? _error;
  SessionSummary? _summary;
  Timer? _poll;
  DateTime? _waitingSince;
  bool _gaveUpWaiting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// true khi còn câu chưa chấm VÀ chưa quá hạn chờ.
  bool get _waitingForGrading =>
      !_gaveUpWaiting && (_summary?.stillGrading ?? false);

  void _scheduleNextPoll() {
    _poll?.cancel();
    if (!_waitingForGrading) return;
    _waitingSince ??= DateTime.now();
    if (DateTime.now().difference(_waitingSince!) >= _maxWait) {
      setState(() => _gaveUpWaiting = true);
      return;
    }
    _poll = Timer(_pollInterval, _load);
  }

  Future<void> _load() async {
    // Lần poll sau KHÔNG bật lại _loading: màn hình đã có nội dung rồi, nhấp nháy về vòng
    // xoay mỗi 4 giây thì tệ hơn hẳn việc để nguyên và chỉ đổi phần đang chờ.
    setState(() {
      _loading = _summary == null;
      _error = null;
    });
    try {
      final summary = await _repository.getSessionSummary(widget.sessionId);
      if (!mounted) return;
      setState(() => _summary = summary);
      _scheduleNextPoll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        title: Text(l10n.pzSummaryTitle),
      ),
      body: switch ((_loading, _error, _summary)) {
        (true, _, _) => const Center(child: CircularProgressIndicator()),
        (_, final String error, _) => PersonalizeErrorView(
          detail: error,
          onRetry: _load,
        ),
        (_, _, null) => PersonalizeErrorView(onRetry: _load),
        (_, _, final SessionSummary summary) => _buildBody(summary),
      },
    );
  }

  Widget _buildBody(SessionSummary summary) {
    // Còn câu đang chấm -> KHÔNG hiện điểm.
    //
    // Bản trước hiện điểm ngay kèm banner "đang tổng hợp", với lập luận "phần đã chấm là
    // thật". Nhưng `score` là điểm TRUNG BÌNH trên các câu đã chấm, không phải một phần của
    // kết quả cuối -- chấm xong câu còn lại thì con số nhảy, và nhảy theo hướng nào cũng
    // được. Học sinh đọc 72 rồi thấy thành 58 sẽ tin con số nào?
    //
    // Danh sách lỗi thì khác: chúng chỉ DÀI THÊM khi chấm xong, không đổi cái đã hiện. Nhưng
    // đặt chúng cạnh một ô điểm trống thì đọc như thể đó là toàn bộ kết quả, nên vẫn chờ.
    if (_waitingForGrading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _GradingBanner(
            pendingEvaluations: summary.pendingEvaluations,
            onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Quá hạn chờ mà vẫn chưa xong: lúc này hiện những gì đang có LÀ đúng -- chấm có thể
        // hỏng thật, và để trống vô hạn thì học sinh mất trắng cả buổi luyện. Banner nói rõ
        // con số chưa đầy đủ.
        if (_gaveUpWaiting && summary.stillGrading) ...[
          const _GradingStalledBanner(),
          const SizedBox(height: 12),
        ],
        _ScoreHero(summary: summary),
        const SizedBox(height: 12),
        _SessionRubricCard(
          rubric: summary.rubric,
          scaleMin: summary.scoreScaleMin,
          scaleMax: summary.scoreScaleMax,
        ),
        const SizedBox(height: 12),
        _RepeatedErrorsCard(errors: summary.repeatedErrors),
        const SizedBox(height: 12),
        _MispronouncedCard(words: summary.mispronounced),
      ],
    );
  }
}

/// "Đang chấm bài" — thứ DUY NHẤT hiện khi còn câu chưa chấm.
///
/// Cố ý che hết điểm phía dưới: `score` là trung bình trên các câu ĐÃ chấm, nên nó không
/// phải một phần của kết quả cuối mà là một con số khác hẳn, sẽ nhảy khi chấm xong. Cho học
/// sinh đọc 72 rồi đổi thành 58 thì con số nào cũng mất tin cậy.
///
/// Đổi lại phải nói rõ đang chờ cái gì, còn mấy câu, và cho lối thoát -- không ai phải ngồi
/// nhìn màn hình đợi máy.
class _GradingBanner extends StatelessWidget {
  const _GradingBanner({
    required this.pendingEvaluations,
    required this.onLeave,
  });

  /// Số câu chưa chấm xong. 0 nghĩa là không biết (server chưa trả) -- lúc đó nói chung chung.
  final int pendingEvaluations;

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pendingEvaluations > 0
                      ? 'Đang chấm $pendingEvaluations câu cuối, kết quả sẽ tự hiện ra.'
                      : 'Đang chấm bài, kết quả sẽ tự hiện ra.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.indigo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Chưa hiện điểm vì còn câu chưa chấm — hiện bây giờ thì con số sẽ đổi. '
            'Không cần đợi ở đây: kết quả vẫn được lưu, xem lại trong Lịch sử luyện tập '
            'bất cứ lúc nào.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onLeave,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Quay lại trang chính'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quá hạn chờ mà vẫn chưa chấm xong. Nói thật là có trục trặc, thay vì quay vô hạn.
class _GradingStalledBanner extends StatelessWidget {
  const _GradingStalledBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warnBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Một số câu chưa chấm xong sau vài phút. Phần dưới là những gì đã có; mở lại buổi này trong Lịch sử luyện tập sau ít phút để xem đầy đủ.',
        style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.warnFg),
      ),
    );
  }
}

class _ScoreHero extends StatelessWidget {
  const _ScoreHero({required this.summary});
  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GradientHeroCard(
      child: Column(
        children: [
          Text(
            l10n
                .pzSummaryHeader(summary.topicTitle, summary.minutes)
                .toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          // The score is deliberately huge — scale it down rather than clip it
          // on narrow screens or at large system text sizes.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  summary.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                Text(
                  // Mẫu số theo thang của CHÍNH phiên, không viết cứng: phiên từ V13 là 0-100,
                  // phiên cũ theo rubric (0-10, hoặc 5-10). Trước 2026-08-07 in cứng " / 100"
                  // nên điểm 7,8 trên thang 10 hiện thành "7.8 / 100".
                  ' / ${summary.scoreScaleMax.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (summary.difficultyRank != null) ...[
            const SizedBox(height: 8),
            // Đặt NGAY dưới điểm, không nhét xuống cuối: thiếu con số này thì điểm ở trên
            // đọc sai nghĩa, nên hai thứ phải nhìn thấy cùng lúc.
            Text(
              'Câu hỏi ở mức bậc ${summary.difficultyRank!.toStringAsFixed(1).replaceAll('.', ',')}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (summary.delta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    summary.delta! >= 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 16,
                    color: summary.delta! >= 0
                        ? AppColors.chipGreenFg
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.pzSummaryDelta(formatDelta(summary.delta!)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: summary.delta! >= 0
                            ? AppColors.chipGreenFg
                            : AppColors.danger,
                      ),
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

/// "Từ phát âm chưa đạt" — từ nào sai và sai ở âm nào.
///
/// Dữ liệu lấy từ `wordFeedbackJson` mà Azure đã chấm ngay lúc học sinh nói và đã lưu sẵn
/// theo từng lượt; không cần bảng mới, không cần màn mới.
class _MispronouncedCard extends StatefulWidget {
  const _MispronouncedCard({required this.words});
  final List<MispronouncedWord> words;

  @override
  State<_MispronouncedCard> createState() => _MispronouncedCardState();
}

class _MispronouncedCardState extends State<_MispronouncedCard> {
  /// Hiện sẵn mấy từ SAI NẶNG NHẤT, phần còn lại xổ ra mới thấy.
  ///
  /// Danh sách đã xếp từ tệ nhất, nên ba dòng đầu là ba dòng đáng luyện nhất. Đổ hết ra thì
  /// một buổi nói dài thành ba màn hình toàn từ, và học sinh không biết bắt đầu từ đâu.
  static const _collapsedCount = 3;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final words = widget.words;
    final hidden = words.length - _collapsedCount;
    final visible = _expanded || hidden <= 0
        ? words
        : words.take(_collapsedCount).toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l10n.pzSummaryPronunciation),
          const SizedBox(height: 12),
          if (words.isEmpty)
            Text(
              l10n.pzSummaryPronunciationEmpty,
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _MispronouncedRow(item: visible[i]),
          ],
          if (hidden > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(_expanded ? 'Thu gọn' : 'Xem thêm $hidden từ'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MispronouncedRow extends StatelessWidget {
  const _MispronouncedRow({required this.item});
  final MispronouncedWord item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Dưới 50% là sai rõ, 50-70% là chưa tròn tiếng -- hai mức đó nên nhìn khác nhau.
    final severe = item.accuracy < 50;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: severe ? AppColors.dangerBg : AppColors.warnBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${item.accuracy.round()}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: severe ? AppColors.danger : AppColors.warnFg,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.word,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              if (item.worstPhoneme != null &&
                  item.worstPhonemeAccuracy != null) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.pzSummaryWorstPhoneme(
                    item.worstPhoneme!,
                    item.worstPhonemeAccuracy!.round().toString(),
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
        if (item.times > 1)
          Text(
            '×${item.times}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
      ],
    );
  }
}

class _RepeatedErrorsCard extends StatelessWidget {
  const _RepeatedErrorsCard({required this.errors});
  final List<RepeatedError> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionLabel(l10n.pzSummaryRepeatedErrors),
          const SizedBox(height: 12),
          if (errors.isEmpty)
            const Text(
              'Không ghi nhận lỗi lặp lại trong phiên này.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          for (int i = 0; i < errors.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ErrorRow(error: errors[i]),
          ],
        ],
      ),
    );
  }
}

/// Một tiêu chí trong "lỗi lặp lại", xổ ra mới thấy nguyên văn.
///
/// Mặc định thu lại: một buổi có thể sinh ra chục lỗi, đổ hết ra thì thẻ dài mấy màn hình và
/// chính con số "×3" -- thứ đáng nhìn trước -- bị trôi mất. Xổ ra là hành động có chủ đích của
/// học sinh khi muốn xem mình sai câu nào.
class _ErrorRow extends StatefulWidget {
  const _ErrorRow({required this.error});
  final RepeatedError error;

  @override
  State<_ErrorRow> createState() => _ErrorRowState();
}

class _ErrorRowState extends State<_ErrorRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final canExpand = error.examples.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: canExpand ? () => setState(() => _expanded = !_expanded) : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chipOrangeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '×${error.count}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.chipOrangeFg,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                if (canExpand)
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final example in error.examples) ...[
            const SizedBox(height: 8),
            _CorrectionDetail(correction: example),
          ],
      ],
    );
  }
}

/// "Em nói → đúng phải là", kèm lý do.
///
/// Thụt vào dưới dòng đếm của tiêu chí: đây là bằng chứng cho con số đó, không phải một mục
/// ngang hàng.
class _CorrectionDetail extends StatelessWidget {
  const _CorrectionDetail({required this.correction});
  final SessionCorrection correction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 34),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (correction.originalText.isNotEmpty)
            Text(
              correction.originalText,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.danger,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppColors.danger,
              ),
            ),
          if (correction.correctedText.isNotEmpty) ...[
            if (correction.originalText.isNotEmpty) const SizedBox(height: 3),
            Text(
              correction.correctedText,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.chipGreenFg,
              ),
            ),
          ],
          if (correction.explanation.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              correction.explanation,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionRubricCard extends StatelessWidget {
  const _SessionRubricCard({
    required this.rubric,
    required this.scaleMin,
    required this.scaleMax,
  });

  final List<SessionRubricCriterion> rubric;

  /// Dải điểm THẬT của phiên này -- xem [SessionSummary.scoreScaleMin].
  final double scaleMin;
  final double scaleMax;

  /// Vị trí của một điểm trên dải, về 0..1.
  ///
  /// Dải hỏng (max <= min, dữ liệu cấu hình sai) thì trả 0 chứ không chia cho 0: thanh trống
  /// là sai, nhưng NaN làm vỡ cả layout.
  static double _ratioOnScale(double score, double min, double max) {
    if (max <= min) return 0;
    return ((score - min) / (max - min)).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
            child: SectionLabel(l10n.pzSummaryRubric),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          if (rubric.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Chưa có điểm chi tiết theo tiêu chí.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ),
          for (int i = 0; i < rubric.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                9,
                0,
                i == rubric.length - 1 ? 12 : 9,
              ),
              child: MeterRow(
                label: rubric[i].label,
                // Chuẩn hoá theo dải THẬT của phiên. Chia cứng cho 100 trong khi dữ liệu là
                // 0-10 làm mọi thanh chỉ đầy ~8% -- nhìn như học sinh làm bài rất tệ.
                ratio: _ratioOnScale(rubric[i].score, scaleMin, scaleMax),
                value: rubric[i].score.round().toString(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
