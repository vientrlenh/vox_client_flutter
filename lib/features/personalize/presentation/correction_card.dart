import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/practice_session.dart';
import 'personalize_styles.dart';

/// Design `1c` — the "SỬA NGAY" bubble that sits right under the learner's
/// turn, offset to the right so it reads as a reply to that turn.
class CorrectionCard extends StatefulWidget {
  const CorrectionCard({
    super.key,
    required this.turn,
    required this.onHearCorrect,
    required this.onContinue,
    this.continueReady = true,
    this.showContinue = true,
  });

  final PracticeTurn turn;
  final VoidCallback onHearCorrect;

  /// Advances to whatever's next — a follow-up or a new MAIN question alike (gói 11 mục
  /// 2.2/2.7b, click-to-continue). Replaces the old "Nói lại" action; there is no
  /// equivalent to redoing a turn in the real protocol.
  final VoidCallback onContinue;

  /// False while the next prompt is still being resolved server-side (rare — only when
  /// bậc 4/LLM generation takes a moment, mục 2.6). The footer shows a small spinner
  /// instead of doing nothing silently on tap.
  final bool continueReady;

  /// Chỉ lượt MỚI NHẤT mới có footer điều hướng.
  ///
  /// Các lượt cũ vẫn giữ nguyên phần nội dung sửa lỗi để học sinh cuộn lên xem lại cả buổi
  /// -- trước đây cả thẻ bị ẩn khi có lượt mới, nên bấm "Tiếp tục" là mất sạch phần sửa của
  /// những câu đã nói. Nút "Tiếp tục"/"Nghe câu đúng" thì không nhân bản ở mọi thẻ, vì hai
  /// nút đó tác động lên lượt hiện tại chứ không phải lượt đang xem.
  final bool showContinue;

  @override
  State<CorrectionCard> createState() => _CorrectionCardState();
}

class _CorrectionCardState extends State<CorrectionCard> {
  /// Loại đang lọc; null = xem tất cả.
  CorrectionType? _filter;

  PracticeTurn get turn => widget.turn;

  /// Lượt này học sinh không nói gì (transcript rỗng).
  bool get _isSilent => turn.text.trim().isEmpty;

  /// Đã chấm và không có lỗi nào.
  bool get _isClean => !_isSilent && turn.corrections.isEmpty;

  /// Thẻ LUÔN nói một điều gì đó.
  ///
  /// Trước đây tiêu đề chỉ đếm số lỗi, nên lượt im lặng và lượt nói đúng hoàn toàn đều hiện
  /// "0 chỗ cần sửa" -- học sinh không biết mình được khen hay máy không nghe thấy gì.
  String _headerText(AppLocalizations l10n) {
    if (_isSilent) return 'Lượt này em chưa nói gì';
    if (_isClean) return 'Tốt — không có gì phải sửa';
    return l10n.pzSessionCorrectNow(turn.corrections.length);
  }

  IconData get _headerIcon {
    if (_isSilent) return Icons.mic_off;
    if (_isClean) return Icons.check_circle;
    return Icons.edit_note;
  }

  Color get _headerColor {
    if (_isSilent) return AppColors.muted;
    if (_isClean) return const Color(0xFF34D399);
    return AppColors.indigo;
  }

  /// Đếm theo loại, giữ nguyên thứ tự server đã xếp (lỗi trước, nâng cấp sau).
  Map<CorrectionType, int> get _counts {
    final counts = <CorrectionType, int>{};
    for (final c in turn.corrections) {
      counts[c.type] = (counts[c.type] ?? 0) + 1;
    }
    return counts;
  }

  List<Correction> get _rows => _filter == null
      ? turn.corrections
      : turn.corrections.where((c) => c.type == _filter).toList();

  static String _categoryLabel(CorrectionType type) => switch (type) {
    CorrectionType.grammar => 'Ngữ pháp',
    CorrectionType.vocabulary => 'Từ vựng',
    CorrectionType.pronunciation => 'Phát âm',
    CorrectionType.fluency => 'Mạch lạc',
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final score = turn.score;

    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppColors.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.dark.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.headerBg,
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F1F1))),
                ),
                child: Row(
                  children: [
                    Icon(_headerIcon, size: 16, color: _headerColor),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _headerText(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                    if (score != null)
                      Text(
                        '${score.toStringAsFixed(1)}/100',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: score >= 8
                              ? AppColors.success
                              : AppColors.textGhost,
                        ),
                      ),
                  ],
                ),
              ),

              // ── Tab lọc theo loại ──
              // Chỉ hiện khi có TỪ HAI loại trở lên: một loại thì tab chẳng lọc được gì,
              // chỉ tốn một hàng và làm thẻ cao thêm vô ích.
              if (_counts.length > 1)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    children: [
                      _FilterChip(
                        label: 'Tất cả ${turn.corrections.length}',
                        selected: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final entry in _counts.entries) ...[
                        const SizedBox(width: 7),
                        _FilterChip(
                          label: '${_categoryLabel(entry.key)} ${entry.value}',
                          selected: _filter == entry.key,
                          onTap: () => setState(() => _filter = entry.key),
                        ),
                      ],
                    ],
                  ),
                ),

              // ── Rows ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _rows.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _CorrectionRow(correction: _rows[i]),
                    ],
                  ],
                ),
              ),

              // ── Footer actions -- chỉ lượt mới nhất, xem showContinue ──
              if (widget.showContinue) ...[
                const Divider(height: 1, color: Color(0xFFF1F1F1)),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _FooterAction(
                          icon: Icons.volume_up,
                          label: l10n.pzSessionHearCorrect,
                          color: AppColors.indigo,
                          onTap: widget.onHearCorrect,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: Color(0xFFF1F1F1)),
                      Expanded(
                        child: _FooterAction(
                          icon: Icons.arrow_forward,
                          label: l10n.pzSessionContinue,
                          color: AppColors.indigo,
                          onTap: widget.onContinue,
                          loading: !widget.continueReady,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  const _CorrectionRow({required this.correction});
  final Correction correction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final style = styleForCorrection(correction.type);
    final hasDiff = correction.before != null && correction.after != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(style.icon, size: 14, color: style.foreground),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDiff)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: correction.before,
                        style: TextStyle(
                          color: correction.type == CorrectionType.vocabulary
                              ? const Color(0xFF666666)
                              : AppColors.danger,
                          decoration:
                              correction.type == CorrectionType.vocabulary
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      const TextSpan(
                        text: '  →  ',
                        style: TextStyle(color: AppColors.textGhost),
                      ),
                      TextSpan(
                        text: correction.after,
                        style: TextStyle(
                          color: correction.type == CorrectionType.vocabulary
                              ? const Color(0xFF7C3AED)
                              : AppColors.chipGreenFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.5),
                )
              else
                Text(
                  correction.headline ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                correction.note,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                ),
              ),
              if (correction.accuracy != null) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: MeterBar(
                        ratio: correction.accuracy!,
                        color: AppColors.success,
                        height: 6,
                        track: AppColors.borderSoft,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(correction.accuracy! * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.chipGreenFg,
                      ),
                    ),
                  ],
                ),
              ],
              if (correction.repeatCount != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TagChip.orange(
                    l10n.pzSessionKnownWeakness(correction.repeatCount!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FooterAction extends StatelessWidget {
  const _FooterAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// Shows a small spinner instead of [icon] — used while the next prompt is still being
  /// resolved server-side (mục 2.6/2.7b), so a tap has visible feedback instead of doing
  /// nothing silently.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a learner transcript with wavy underlines over the flagged ranges.
class TranscriptText extends StatelessWidget {
  const TranscriptText({
    super.key,
    required this.text,
    required this.spans,
    required this.baseStyle,
  });

  final String text;
  final List<ErrorSpan> spans;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(children: _buildSpans()), style: baseStyle);
  }

  List<InlineSpan> _buildSpans() {
    if (spans.isEmpty) return [TextSpan(text: '“$text”')];

    // Sort by position and drop anything that overlaps what we already emitted
    // or runs past the end of the transcript — the ranges come from the model
    // and must never be trusted to line up.
    final ordered = [...spans]..sort((a, b) => a.start.compareTo(b.start));

    final result = <InlineSpan>[const TextSpan(text: '“')];
    var cursor = 0;
    for (final span in ordered) {
      final start = span.start;
      final end = span.end;
      if (start < cursor || start >= text.length || end > text.length) continue;
      if (start > cursor) {
        result.add(TextSpan(text: text.substring(cursor, start)));
      }
      result.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.wavy,
            decorationColor: styleForCorrection(span.type).underline,
            decorationThickness: 1.5,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      result.add(TextSpan(text: text.substring(cursor)));
    }
    result.add(const TextSpan(text: '”'));
    return result;
  }
}

/// Chip lọc theo loại lỗi, dùng ở đầu CorrectionCard.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : AppColors.headerBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.dark : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF555555),
          ),
        ),
      ),
    );
  }
}
