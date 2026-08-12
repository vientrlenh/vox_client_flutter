import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/network/graphql_client.dart';
import '../data/models/exam_result_summary.dart';
import '../data/result_api.dart';
import '../data/result_repository.dart';
import 'results_screen.dart';

class ResultsListScreen extends StatelessWidget {
  const ResultsListScreen({super.key});

  @override
  Widget build(BuildContext context) => const MyExamsScreen();
}

class MyExamsScreen extends StatelessWidget {
  const MyExamsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ResultsListCore(
        kind: ExamKind.centralized,
        title: 'Bài kiểm tra của tôi',
      );
}

class MyClassTestsScreen extends StatelessWidget {
  const MyClassTestsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _ResultsListCore(
        kind: ExamKind.classTest,
        title: 'Bài tập của tôi',
      );
}

class _ResultsListCore extends StatefulWidget {
  const _ResultsListCore({required this.kind, required this.title});
  final ExamKind kind;
  final String title;

  @override
  State<_ResultsListCore> createState() => _ResultsListCoreState();
}

class _ResultsListCoreState extends State<_ResultsListCore> {
  final _repository = ResultRepository(ResultApi(GraphQLClient()));
  final _expandedExamIds = <String>{};
  bool _loading = true;
  String? _error;
  List<ExamResultGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final groups = await _repository.getGroupedResults(widget.kind, refresh: refresh);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể tải kết quả.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openResult(ExamResultSummary result) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => widget.kind == ExamKind.classTest
          ? ClassTestResultScreen(sessionId: result.sessionId, examName: result.examName)
          : ExamResultScreen(sessionId: result.sessionId, examName: result.examName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark)),
        centerTitle: true,
      ),
      // RefreshIndicator bọc NGOÀI cả ba nhánh. Bản cũ đặt nó bên trong nhánh "đã có dữ liệu",
      // nên đúng trạng thái cần làm mới nhất -- danh sách rỗng vì điểm chưa công bố lúc mở --
      // lại là trạng thái duy nhất không kéo được. Cộng với nút "Thử lại" chỉ hiện khi LỖI (mà
      // rỗng thì không phải lỗi), màn hình thành ngõ cụt: không còn thao tác nào gọi lại mạng.
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _FullHeightMessage(
                    message: _error!,
                    action: TextButton(onPressed: () => _load(refresh: true), child: const Text('Thử lại')),
                  )
                : _groups.isEmpty
                    ? const _FullHeightMessage(message: 'Chưa có kết quả.\nKéo xuống để tải lại.')
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                        itemCount: _groups.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final group = _groups[index];
                          final expanded = _expandedExamIds.contains(group.examId);
                          return _ExamGroupCard(
                            expanded: expanded,
                            group: group,
                            onOpen: _openResult,
                            onToggle: () => setState(() {
                              if (expanded) _expandedExamIds.remove(group.examId); else _expandedExamIds.add(group.examId);
                            }),
                          );
                        },
                      ),
      ),
    );
  }
}

/// Thông báo giữa màn hình mà VẪN kéo xuống được.
///
/// Phải là widget cuộn được thì RefreshIndicator mới nhận cử chỉ kéo -- `Center` trần không
/// cuộn nên nuốt mất thao tác. Dùng ListView một phần tử với AlwaysScrollableScrollPhysics
/// (mặc định thì nội dung ngắn hơn màn hình sẽ tắt cuộn) và ép cao bằng màn hình để kéo được
/// từ bất kỳ đâu, không phải chỉ đúng dòng chữ.
class _FullHeightMessage extends StatelessWidget {
  const _FullHeightMessage({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted, height: 1.5),
                  ),
                  ?action,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamGroupCard extends StatelessWidget {
  const _ExamGroupCard({required this.group, required this.expanded, required this.onToggle, required this.onOpen});
  final ExamResultGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<ExamResultSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    final single = group.sessions.length == 1 ? group.sessions.first : null;
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: single == null ? onToggle : () => onOpen(single),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(group.examName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)), const SizedBox(height: 6), Text(single == null ? '${group.sessions.length} lượt làm bài' : _formatDate(single.startedAt), style: const TextStyle(fontSize: 12, color: AppColors.muted))])),
              if (single?.totalScore != null) Text(single!.totalScore!.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.dark)),
              const SizedBox(width: 8),
              Icon(single == null ? (expanded ? Icons.expand_less : Icons.expand_more) : Icons.chevron_right, color: AppColors.muted),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          for (int index = 0; index < group.sessions.length; index++)
            InkWell(
              onTap: () => onOpen(group.sessions[index]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Lượt ${group.sessions.length - index}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark)), const SizedBox(height: 4), Text(_formatDate(group.sessions[index].startedAt), style: const TextStyle(fontSize: 11, color: AppColors.muted))])), _StatusPill(group.sessions[index].status), if (group.sessions[index].totalScore != null) ...[const SizedBox(width: 10), Text(group.sessions[index].totalScore!.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800))], const Icon(Icons.chevron_right, size: 18, color: AppColors.muted)]),
              ),
            ),
        ],
      ]),
    );
  }
}

String _formatDate(DateTime? date) => date == null ? 'Chưa có thời gian' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

extension ResultStatusMeta on ExamResultStatus {
  String get label => switch (this) { ExamResultStatus.pendingReview => 'Chờ duyệt', ExamResultStatus.released => 'Đã công bố', ExamResultStatus.appealed => 'Đang phúc khảo', ExamResultStatus.reGrading => 'Đang chấm lại', ExamResultStatus.final_ => 'Hoàn tất', ExamResultStatus.invalid => 'Không hợp lệ', ExamResultStatus.retakeRequired => 'Cần thi lại', ExamResultStatus.passed => 'Đạt', ExamResultStatus.failed => 'Chưa đạt' };
  Color get fg => switch (this) { ExamResultStatus.pendingReview || ExamResultStatus.retakeRequired || ExamResultStatus.failed => AppColors.warnFg, ExamResultStatus.released || ExamResultStatus.final_ || ExamResultStatus.passed => AppColors.success, ExamResultStatus.appealed || ExamResultStatus.reGrading => AppColors.indigo, ExamResultStatus.invalid => AppColors.muted };
  Color get bg => switch (this) { ExamResultStatus.pendingReview || ExamResultStatus.retakeRequired || ExamResultStatus.failed => AppColors.warnBg, ExamResultStatus.released || ExamResultStatus.final_ || ExamResultStatus.passed => const Color(0xFFECFDF5), ExamResultStatus.appealed || ExamResultStatus.reGrading => AppColors.chipBlueBg, ExamResultStatus.invalid => AppColors.chipNeutralBg };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final ExamResultStatus status;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: status.bg, borderRadius: BorderRadius.circular(99)), child: Text(status.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: status.fg)));
}
