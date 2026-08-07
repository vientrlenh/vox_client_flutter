import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/practice_history_entry.dart';
import '../data/personalize_repository.dart';
import 'personalize_styles.dart';
import 'personalize_widgets.dart';
import 'session_summary_screen.dart';

/// Danh sách buổi luyện đã qua -- `myPracticeHistory(limit)`.
///
/// Bấm một buổi thì mở lại bản tổng kết của buổi đó. Trước đây không mở được vì chưa có
/// query nào trả chi tiết cho HỌC SINH: `studentPracticeSessionDetail` là endpoint của giáo
/// viên (@PreAuthorize hasRole('TEACHER')). Giờ đã có `myPracticeSessionDetail` nên đường
/// này thông.
class PracticeHistoryScreen extends StatefulWidget {
  const PracticeHistoryScreen({super.key});

  @override
  State<PracticeHistoryScreen> createState() => _PracticeHistoryScreenState();
}

class _PracticeHistoryScreenState extends State<PracticeHistoryScreen> {
  final _repository = PersonalizeRepository();

  bool _loading = true;
  String? _error;
  List<PracticeHistoryEntry> _entries = const [];

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
      final entries = await _repository.getPracticeHistory(limit: 20);
      if (!mounted) return;
      setState(() => _entries = entries);
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
      appBar: AppBar(title: Text(l10n.pzHistoryTitle)),
      body: switch ((_loading, _error)) {
        (true, _) => const Center(child: CircularProgressIndicator()),
        (_, final String error) => PersonalizeErrorView(
          detail: error,
          onRetry: _load,
        ),
        _ => _buildBody(l10n),
      },
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_entries.isEmpty) {
      return Center(
        child: Text(
          l10n.pzHistoryEmpty,
          style: const TextStyle(fontSize: 13, color: AppColors.textFaint),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final entry = _entries[index];
        return _HistoryEntryRow(
          entry: entry,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionSummaryScreen(sessionId: entry.id),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryEntryRow extends StatelessWidget {
  const _HistoryEntryRow({required this.entry, required this.onTap});
  final PracticeHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = entry.overallScore;
    final positive = score != null && score >= 7.5;
    final date = entry.startedAt;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: rowDecoration,
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fieldBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: Color(0xFF555555),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.topicName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date == null
                          ? entry.status
                          : '${date.day}/${date.month}/${date.year} · ${entry.status}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textGhost,
                      ),
                    ),
                  ],
                ),
              ),
              if (score != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: positive
                        ? AppColors.chipGreenBg
                        : AppColors.chipOrangeBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    score.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: positive
                          ? AppColors.chipGreenFg
                          : AppColors.chipOrangeFg,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
