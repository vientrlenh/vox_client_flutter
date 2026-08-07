import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme.dart';
import '../../../core/network/graphql_client.dart';
import '../../recordings/data/models/exam_item_response.dart';
import '../../recordings/data/models/exam_item_evaluation.dart';
import '../../recordings/data/models/exam_response_item.dart';
import '../../recordings/data/recordings_api.dart';
import '../../recordings/data/recordings_repository.dart';

/// Item responses within one exam attempt, with lazy-loaded playback.
/// Each item may itself be multiple turns (AI follow-up ↔ student reply).
class AttemptRecordingsScreen extends StatefulWidget {
  const AttemptRecordingsScreen({
    super.key,
    required this.sessionId,
    required this.examName,
  });

  final String sessionId;
  final String examName;

  @override
  State<AttemptRecordingsScreen> createState() =>
      _AttemptRecordingsScreenState();
}

class _AttemptRecordingsScreenState extends State<AttemptRecordingsScreen> {
  final _repository = RecordingsRepository(RecordingsApi(GraphQLClient()));
  final _player = AudioPlayer();

  bool _loading = true;
  String? _error;
  List<ExamResponseItem> _items = const [];

  String? _expandedId;
  final Map<String, ExamItemResponse> _details = {};
  final Map<String, ExamItemEvaluation?> _evaluations = {};

  String? _playingKey;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repository.getSessionItems(widget.sessionId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this attempt.\n$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleExpand(ExamResponseItem item) async {
    if (_expandedId == item.responseId) {
      setState(() => _expandedId = null);
      return;
    }
    setState(() => _expandedId = item.responseId);
    if (_details.containsKey(item.responseId)) return;
    try {
      final detailFuture = _repository.getItemResponse(item.responseId);
      final evaluationFuture = _repository.getItemEvaluation(item.responseId);
      final detail = await detailFuture;
      final evaluation = await evaluationFuture;
      if (!mounted) return;
      setState(() {
        _details[item.responseId] = detail;
        _evaluations[item.responseId] = evaluation;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _expandedId = null);
    }
  }

  Future<void> _togglePlay(String key, String? audioUrl) async {
    if (_playingKey == key) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      if (mounted) setState(() {});
      return;
    }
    if (audioUrl == null) return;
    setState(() => _playingKey = key);
    try {
      await _player.setUrl(audioUrl);
      await _player.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      setState(() => _playingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          widget.examName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No recorded items in this attempt.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return _ItemCard(
                          index: i + 1,
                          item: item,
                          detail: _details[item.responseId],
                          evaluation: _evaluations[item.responseId],
                          expanded: _expandedId == item.responseId,
                          playingKey: _playingKey,
                          player: _player,
                          onExpand: () => _toggleExpand(item),
                          onPlay: _togglePlay,
                        );
                      },
                    ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.index,
    required this.item,
    required this.detail,
    required this.evaluation,
    required this.expanded,
    required this.playingKey,
    required this.player,
    required this.onExpand,
    required this.onPlay,
  });

  final int index;
  final ExamResponseItem item;
  final ExamItemResponse? detail;
  final ExamItemEvaluation? evaluation;
  final bool expanded;
  final String? playingKey;
  final AudioPlayer player;
  final VoidCallback onExpand;
  final void Function(String key, String? audioUrl) onPlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onExpand,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.chipBlueBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic,
                        color: AppColors.indigo, size: 22),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      'Item $index',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                  ),
                  if (item.itemScore != null)
                    Text(
                      item.itemScore!.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textGhost,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            if (detail == null)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (detail!.turns.isNotEmpty)
              for (final turn in detail!.turns)
                _TurnRow(
                  turn: turn,
                  playing: playingKey == turn.id,
                  player: player,
                  onPlay: () => onPlay(turn.id, turn.audioUrl),
                  wordFeedback: _wordFeedbackFor(turn),
                )
            else
              _TurnRow(
                turn: ExamItemResponseTurn(
                  id: detail!.id,
                  turnOrder: 1,
                  audioUrl: detail!.audioUrl,
                  transcript: detail!.transcript,
                  durationSeconds: detail!.durationSeconds,
                ),
                playing: playingKey == detail!.id,
                player: player,
                onPlay: () => onPlay(detail!.id, detail!.audioUrl),
                wordFeedback: const [],
              ),
            if (detail != null) ...[
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _CriterionBreakdown(evaluation: evaluation),
            ],
          ],
        ],
      ),
    );
  }

  List<WordFeedback> _wordFeedbackFor(ExamItemResponseTurn turn) {
    for (final evaluationTurn in evaluation?.turns ?? const <ExamItemEvaluationTurn>[]) {
      if (evaluationTurn.id == turn.id || evaluationTurn.turnOrder == turn.turnOrder) {
        return evaluationTurn.wordFeedback;
      }
    }
    return const [];
  }
}

class _TurnRow extends StatelessWidget {
  const _TurnRow({
    required this.turn,
    required this.playing,
    required this.player,
    required this.onPlay,
    required this.wordFeedback,
  });

  final ExamItemResponseTurn turn;
  final bool playing;
  final AudioPlayer player;
  final VoidCallback onPlay;
  final List<WordFeedback> wordFeedback;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: turn.audioUrl == null ? null : onPlay,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: playing ? AppColors.indigo : AppColors.chipBlueBg,
                    shape: BoxShape.circle,
                  ),
                  child: StreamBuilder<bool>(
                    stream: player.playingStream,
                    initialData: player.playing,
                    builder: (_, snapshot) => Icon(
                      playing && (snapshot.data ?? false) ? Icons.pause : Icons.play_arrow,
                      color: playing ? Colors.white : AppColors.indigo,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (turn.promptText != null &&
                        turn.promptText!.isNotEmpty) ...[
                      Text(
                        turn.promptText!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (turn.durationSeconds != null)
                      Text(
                        _formatDuration(turn.durationSeconds),
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textGhost),
                      ),
                    if (playing) ...[
                      const SizedBox(height: 8),
                      StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, snapshot) {
                          final position = snapshot.data ?? Duration.zero;
                          final total = player.duration ??
                              Duration(seconds: turn.durationSeconds ?? 0);
                          final progress = total.inMilliseconds == 0
                              ? 0.0
                              : (position.inMilliseconds /
                                      total.inMilliseconds)
                                  .clamp(0.0, 1.0);
                          return Column(
                            children: [
                              Slider(
                                value: progress,
                                onChanged: total.inMilliseconds == 0 ? null : (value) => player.seek(Duration(milliseconds: (value * total.inMilliseconds).round())),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(position.inSeconds), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                  Text(_formatDuration(total.inSeconds), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                    if (wordFeedback.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: wordFeedback.map((word) => ActionChip(
                          label: Text(word.word),
                          backgroundColor: _wordColor(word.color).$1,
                          labelStyle: TextStyle(color: _wordColor(word.color).$2, fontWeight: FontWeight.w600),
                          side: BorderSide.none,
                          onPressed: () => _showWordDetail(context, word),
                        )).toList(),
                      ),
                    ],
                    if (turn.transcript != null &&
                        turn.transcript!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        turn.transcript!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  (Color, Color) _wordColor(String? color) {
    switch (color?.toLowerCase()) {
      case 'green': return (const Color(0xFFDCFCE7), const Color(0xFF166534));
      case 'yellow': return (const Color(0xFFFEF3C7), const Color(0xFF92400E));
      case 'red': return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
      default: return (const Color(0xFFF1F5F9), AppColors.muted);
    }
  }

  void _showWordDetail(BuildContext context, WordFeedback word) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(word.word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
              if (word.accuracyScore != null) Text('Độ chính xác: ${word.accuracyScore!.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.muted)),
              if (word.errorNote?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 10), child: Text(word.errorNote!, style: const TextStyle(fontSize: 14, color: AppColors.dark))),
              if (word.phonemes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('Chi tiết âm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark)),
                const SizedBox(height: 8),
                for (final phoneme in word.phonemes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${phoneme.phoneme}: ${phoneme.note ?? phoneme.accuracyScore?.toStringAsFixed(1) ?? 'Không có ghi chú'}', style: const TextStyle(fontSize: 13, color: AppColors.muted))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

/// Điểm AI chấm theo từng tiêu chí. Điểm luôn thấy; NHẬN XÉT của AI nằm sau dropdown ở
/// từng tiêu chí -- xem [_CriterionTile].
class _CriterionBreakdown extends StatelessWidget {
  const _CriterionBreakdown({required this.evaluation});
  final ExamItemEvaluation? evaluation;

  @override
  Widget build(BuildContext context) {
    if (evaluation == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chưa có đánh giá chi tiết.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    final data = evaluation!;
    if (data.criteria.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Câu này chưa có điểm theo tiêu chí.',
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Theo tiêu chí',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.dark)),
          const SizedBox(height: 10),
          if (data.feedbackSummary?.isNotEmpty == true) ...[
            Text(data.feedbackSummary!,
                style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.dark)),
            const SizedBox(height: 12),
          ],
          for (final criterion in data.criteria) _CriterionTile(criterion),
        ],
      ),
    );
  }
}

class _CriterionTile extends StatefulWidget {
  const _CriterionTile(this.criterion);

  final ExamItemCriterionScore criterion;

  @override
  State<_CriterionTile> createState() => _CriterionTileState();
}

class _CriterionTileState extends State<_CriterionTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final criterion = widget.criterion;
    // Thang lấy từ rubric đang áp, KHÔNG cứng 0-10: đổi trường sang thang khác thì thanh vẫn
    // đúng tỉ lệ. Thiếu min/max thì không vẽ thanh chứ không đoán.
    final min = criterion.minScore;
    final max = criterion.maxScore;
    final score = criterion.finalScore;
    final hasScale = min != null && max != null && max > min && score != null;
    final ratio = hasScale ? ((score - min) / (max - min)).clamp(0.0, 1.0) : 0.0;
    final hasRationale = criterion.rationale?.isNotEmpty == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Điểm luôn thấy, nhận xét nằm sau dropdown: nhận xét AI dài vài dòng mỗi tiêu chí,
          // năm tiêu chí mở hết thì đẩy các lượt nói phía dưới ra khỏi màn hình.
          InkWell(
            onTap: hasRationale ? () => setState(() => _open = !_open) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(criterion.criterionName ?? criterion.criterionCode,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark)),
                      ),
                      Text(
                        '${score?.toStringAsFixed(1) ?? '-'} / ${max?.toStringAsFixed(1) ?? '-'}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.indigo),
                      ),
                      if (hasRationale) ...[
                        const SizedBox(width: 4),
                        Icon(_open ? Icons.expand_less : Icons.expand_more,
                            size: 18, color: AppColors.muted),
                      ],
                    ],
                  ),
                  if (hasScale) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 5,
                        color: const Color(0xFFE2E8F0),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: ratio,
                          child: Container(color: AppColors.indigo),
                        ),
                      ),
                    ),
                  ],
                  // Nói rõ còn gì để xem, thay vì để mũi tên tự giải thích lấy.
                  if (hasRationale && !_open) ...[
                    const SizedBox(height: 6),
                    const Text('Xem nhận xét của AI',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.indigo)),
                  ],
                ],
              ),
            ),
          ),
          if (hasRationale && _open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(criterion.rationale!,
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}
