import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/practice_topic.dart';
import '../data/personalize_repository.dart';
import 'personalize_styles.dart';
import 'personalize_widgets.dart';

/// Design `1b`, screen 2 — the browsable topic list.
///
/// Pops the [PracticeTopic] the learner picked so the caller decides how to
/// open the session.
class PracticeTopicsScreen extends StatefulWidget {
  const PracticeTopicsScreen({
    super.key,
    this.initialFilter = TopicFilter.forYou,
  });

  final TopicFilter initialFilter;

  @override
  State<PracticeTopicsScreen> createState() => _PracticeTopicsScreenState();
}

class _PracticeTopicsScreenState extends State<PracticeTopicsScreen> {
  final _repository = PersonalizeRepository();
  final _searchController = TextEditingController();

  late TopicFilter _filter = widget.initialFilter;
  bool _loading = true;
  bool _pickingRandom = false;
  bool _generating = false;
  String? _error;
  List<PracticeTopic> _topics = const [];

  /// Kho chủ đề không có gì khớp từ khoá, nhưng từ khoá hợp lệ để nhờ AI soạn mới.
  bool _canGenerate = false;

  /// Lô chào thứ mấy. Từ lô 2 trở đi backend nâng tỉ lệ thăm dò ε 0,10 → 0,30, tức chịu
  /// tráo vào nhiều chủ đề ngoài top hơn — đúng lúc học sinh vừa nói "cái này chán".
  int _round = 1;

  /// Chủ đề đã bị từ chối ở các lô trước, không chào lại nữa trong phiên duyệt này.
  final _rejectedTopicIds = <String>{};

  // GỠ 2026-08-06: thẻ "gợi ý chờ duyệt" (_suggestions / _respondToSuggestion / _loadSuggestions).
  // Nguồn duy nhất tạo ra gợi ý là đường suy chủ đề TỪ LỜI HỌC SINH NÓI, đã bỏ ở backend, nên
  // thẻ này vĩnh viễn không có gì để hiện. Tìm chủ đề theo từ khoá (_openKeywordSheet bên dưới)
  // là đường KHÁC và vẫn chạy -- đừng nhầm hai cái.

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchController.text;
      if (query.trim().isEmpty) {
        final topics = await _repository.getTopics(
          _filter,
          round: _round,
          excludeTopicIds: _rejectedTopicIds.toList(),
        );
        if (!mounted) return;
        setState(() {
          _topics = topics;
          _canGenerate = false;
        });
      } else {
        final result = await _repository.searchTopics(query);
        if (!mounted) return;
        setState(() {
          _topics = result.topics;
          // Cờ này backend đã trả từ lâu; trước đây client lấy `.topics` rồi vứt nó đi, nên
          // tìm không ra chỉ hiện danh sách rỗng thay vì mời soạn chủ đề mới.
          _canGenerate = result.canGenerate;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "Đổi gợi ý" — loại cả lô hiện tại rồi xin lô khác.
  ///
  /// Hai việc cùng lúc: chuyển sang lô sau (ε cao hơn) và cấm chào lại đúng những chủ đề
  /// vừa hiện. Thiếu vế thứ hai thì xếp hạng vốn tất định sẽ trả về gần như y hệt.
  Future<void> _refreshOffers() async {
    setState(() {
      _rejectedTopicIds.addAll(_topics.map((t) => t.id));
      _round = _round + 1;
    });
    await _load();
  }

  /// "Không thích chủ đề này" — loại đúng MỘT thẻ.
  ///
  /// Khác `_refreshOffers` ở chỗ nó DẠY hệ thống chứ không chỉ giấu thẻ: backend ghi tín hiệu
  /// sở thích âm 0,15 (bằng mức "bỏ dở vì chán") rồi tính lại điểm quan tâm, nên chủ đề tụt
  /// hạng ở mọi lần mở sau chứ không quay lại như cũ.
  ///
  /// Vẫn thêm vào `_rejectedTopicIds`: tín hiệu âm hạ điểm chứ không cấm tuyệt đối, mà học
  /// sinh vừa bấm loại thì không muốn thấy nó lại ngay trong lô kế tiếp.
  Future<void> _dismissTopic(PracticeTopic topic) async {
    setState(() {
      _rejectedTopicIds.add(topic.id);
      _topics = [for (final item in _topics) if (item.id != topic.id) item];
    });
    try {
      await _repository.dismissTopicOffer(topic.id);
    } catch (_) {
      // Thẻ đã biến mất trước mắt học sinh rồi -- kéo nó về chỗ cũ vì một lỗi mạng thì rối
      // hơn là im lặng. Lần mở sau nó xuất hiện lại, đúng như khi chưa kịp ghi nhận.
    }
    // Lô còn 3 thẻ thì xin bù cho đủ, nhưng KHÔNG tăng _round: đây là loại một thẻ, không
    // phải "đổi cả lô", nên chưa cần nâng tỉ lệ thăm dò.
    if (mounted && _topics.length < 4 && _searchController.text.trim().isEmpty) {
      await _load();
    }
  }

  /// Nhờ AI soạn chủ đề cho từ khoá học sinh vừa gõ.
  ///
  /// Gắn `origin: KEYWORD` (trong repository) — tín hiệu sở thích mạnh nhất, 1,00. Có cơ
  /// sở: học sinh tự gõ ra chữ đó thì đấy là bằng chứng rõ hơn hẳn so với bấm một thẻ hệ
  /// thống bày sẵn. Đó cũng chính là phần "đưa lên ưu tiên".
  Future<void> _generateFromKeyword() async {
    if (_generating) return;
    setState(() => _generating = true);
    final keyword = _searchController.text.trim();
    try {
      final topic = await _repository.generateTopicFromKeyword(keyword);
      if (!mounted) return;
      if (topic == null) {
        // AI từ chối (REJECTED_UNSUITABLE / OUT_OF_EXAM_SCOPE). Nói thẳng lý do thay vì im
        // lặng -- im lặng khiến học sinh bấm lại mãi.
        setState(() => _generating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chủ đề này chưa phù hợp để luyện nói. Thử một từ khoá khác nhé.',
            ),
          ),
        );
        return;
      }
      // KHÔNG _pick(topic) ở đây.
      //
      // _pick là Navigator.pop -- nó ĐÓNG màn tìm kiếm, trả chủ đề về trang trước, và trang
      // đó mở ngay bảng chọn bậc. Nghĩa là học sinh vừa chờ 10-40 giây cho AI soạn xong thì
      // bị đẩy thẳng vào phiên, chưa kịp nhìn thứ mình vừa tạo ra là gì.
      //
      // Cần nhìn, vì tên AI đặt thường KHÁC HẲN từ khoá đã gõ: gõ "khoa học viễn tưởng" ra
      // "How the discovery of life on other planets might change human society". Không cho
      // xem thì học sinh không biết đã tạo được hay chưa -- và tìm lại bằng chính từ khoá cũ
      // cũng không ra, vì chỉ tên tiếng Anh được lưu.
      //
      // Đặt thẳng vào _topics thay vì gọi _load(): _load sẽ tìm lại theo từ khoá tiếng Việt
      // đang còn trong ô, không khớp gì cả, và kết quả vừa tạo biến mất ngay trước mắt.
      setState(() {
        _topics = [topic];
        _canGenerate = false;
        _generating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tạo chủ đề: ${topic.title}'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tạo được chủ đề: $e')),
      );
    }
  }

  void _selectFilter(TopicFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      // Đổi bộ lọc là bắt đầu một lượt duyệt khác -- không mang theo lô đã từ chối, và
      // không tính là "đã đổi gợi ý" ở bộ lọc mới.
      _round = 1;
      _rejectedTopicIds.clear();
    });
    _load();
  }

  /// Trả chủ đề về màn trước, kèm NGỮ CẢNH lô chào.
  ///
  /// Backend đọc hai danh sách này để ghi tín hiệu âm cho chủ đề đã chào mà không được chọn
  /// (0.30 lô hiện tại, 0.20 lô đã "Đổi gợi ý"). Trước đây client không gửi gì, nên
  /// `practice_paper.offered_topic_ids_json` luôn là `[]` và cả nhánh tín hiệu âm chưa từng
  /// chạy một lần nào -- kiểm bằng DB ngày 2026-08-05: sau 3 phiên, `topic_interest_score`
  /// chỉ có đúng 2 dòng, là 2 chủ đề đã chọn.
  ///
  /// Chỉ gửi khi đang xem lô chào. Kết quả TÌM KIẾM không phải lô chào -- gõ từ khoá ra 10
  /// chủ đề rồi chọn 1 thì 9 cái kia không hề bị "từ chối", chỉ là không khớp từ khoá.
  void _pick(PracticeTopic topic) {
    final offering = _searchController.text.trim().isEmpty;
    Navigator.of(context).pop(
      offering
          ? topic.copyWith(
              offeredTopicIds: [for (final t in _topics) t.id],
              previousOfferedTopicIds: _rejectedTopicIds.toList(),
            )
          : topic,
    );
  }

  Future<void> _toggleSaved(PracticeTopic topic) async {
    final isSaved = topic.buckets.contains(TopicFilter.saved);
    // Optimistic: flip locally first, revert on failure.
    setState(() {
      _topics = [
        for (final t in _topics)
          if (t.id == topic.id)
            t.copyWith(
              buckets: {...t.buckets, if (!isSaved) TopicFilter.saved}
                ..removeWhere((b) => isSaved && b == TopicFilter.saved),
            )
          else
            t,
      ];
    });
    try {
      if (isSaved) {
        await _repository.unsaveTopic(topic.id);
      } else {
        await _repository.saveTopic(topic.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topics = [
          for (final t in _topics)
            if (t.id == topic.id) topic else t,
        ];
      });
    }
  }

  Future<void> _pickRandom() async {
    if (_pickingRandom) return;
    setState(() => _pickingRandom = true);
    try {
      final topic = await _repository.pickRandomTopic();
      if (!mounted) return;
      _pick(topic);
    } catch (_) {
      if (mounted) setState(() => _pickingRandom = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.pzTopicsTitle),
        actions: [
          // Chỉ có nghĩa ở danh sách gợi ý: tab "Đã lưu" là do học sinh tự chọn, và khi
          // đang tìm kiếm thì kết quả bám từ khoá chứ không phải một lô hệ thống chào.
          if (_filter != TopicFilter.saved && _searchController.text.trim().isEmpty)
            IconButton(
              onPressed: _loading ? null : _refreshOffers,
              icon: const Icon(Icons.refresh),
              tooltip: 'Đổi gợi ý khác',
            ),
          // Nút này có CHỮ chứ không chỉ icon: ⤨ một mình không nói được nó sẽ bốc đại một
          // chủ đề rồi VÀO PHIÊN NGAY. Người dùng tưởng là "xáo lại danh sách" -- một thao
          // tác vô hại -- rồi bị đẩy thẳng vào buổi luyện.
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: _pickingRandom ? null : _pickRandom,
              icon: _pickingRandom
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shuffle, size: 18),
              label: Text(l10n.pzTopicsRandom),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.indigo,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              children: [
                _SearchField(
                  controller: _searchController,
                  onSubmitted: (_) => _load(),
                  onClear: () {
                    _searchController.clear();
                    _load();
                  },
                ),
                if (_canGenerate) ...[
                  const SizedBox(height: 10),
                  _GenerateTopicCard(
                    keyword: _searchController.text.trim(),
                    busy: _generating,
                    onGenerate: _generateFromKeyword,
                  ),
                ],
                const SizedBox(height: 12),
                _FilterPills(selected: _filter, onSelect: _selectFilter),
              ],
            ),
          ),
          Expanded(child: _buildBody(l10n)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    // Nói rõ đang chờ CÁI GÌ thay vì để một vòng xoay trống: khi kho chủ đề còn thưa, lượt này
    // phải nhờ AI soạn chủ đề mới nên có thể mất hàng chục giây. Vòng xoay trống ở khoảng thời
    // gian đó khiến người dùng tưởng ứng dụng treo và thoát ra giữa chừng.
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              l10n.pzPreparingTopics,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                l10n.pzPreparingHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return PersonalizeErrorView(detail: _error, onRetry: _load);
    }

    if (_topics.isEmpty) {
      // Rỗng ngay sau khi làm xong khảo sát KHÔNG phải lỗi -- backend đã nhận và đang soạn chủ
      // đề chạy nền (xem TopicOfferBackfillService). Trước đây chỗ này chờ LLM ngay trong
      // request nên lượt đầu luôn timeout; giờ vào thẳng màn này rồi tải lại sau.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 34, color: AppColors.indigo),
              const SizedBox(height: 14),
              Text(
                l10n.pzTopicsPreparing,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.pzTopicsPreparingBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l10n.pzTopicsRefresh),
              ),
            ],
          ),
        ),
      );
    }

    // The best match is promoted into the highlighted "ƯU TIÊN #1" card.
    final priority = _topics.first;
    final rest = _topics.skip(1).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
      children: [
        _PriorityCard(
          topic: priority,
          onSpeak: () => _pick(priority),
          onToggleSaved: () => _toggleSaved(priority),
          onDismiss: () => _dismissTopic(priority),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionLabel(l10n.pzTopicsOtherSuggestions),
          const SizedBox(height: 10),
          for (final topic in rest) ...[
            _TopicRow(
              topic: topic,
              onTap: () => _pick(topic),
              onToggleSaved: () => _toggleSaved(topic),
              onDismiss: () => _dismissTopic(topic),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 12),
        const _FooterTip(),
      ],
    );
  }
}

/// Lời mời nhờ AI soạn chủ đề cho từ khoá vừa gõ.
///
/// Chỉ hiện khi backend trả `canGenerate = true`, tức kho không có gì khớp NHƯNG từ khoá
/// vẫn hợp lệ để soạn mới. Trước đây tìm không ra chỉ ra một danh sách rỗng — học sinh
/// không có đường nào đi tiếp, dù backend đã sẵn sàng soạn.
class _GenerateTopicCard extends StatelessWidget {
  const _GenerateTopicCard({
    required this.keyword,
    required this.busy,
    required this.onGenerate,
  });

  final String keyword;
  final bool busy;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.chipBlueBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 20, color: AppColors.indigo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chưa có chủ đề này trong kho',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Để AI soạn một chủ đề về "$keyword" cho em',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton(
                  onPressed: onGenerate,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Tạo'),
                ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.fieldBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: l10n.pzTopicsSearchHint,
                hintStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textGhost,
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : InkWell(
                    onTap: onClear,
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF999999),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterPills extends StatelessWidget {
  const _FilterPills({required this.selected, required this.onSelect});

  final TopicFilter selected;
  final ValueChanged<TopicFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Chỉ còn hai rổ. "Theo mục tiêu" và "Điểm yếu" đã bỏ cùng hồ sơ điểm yếu -- xếp hạng
    // chủ đề giờ dựa hoàn toàn vào sở thích, kho câu còn lại và mức khớp chương trình, nên
    // ba pill sẽ trả về cùng một danh sách và học sinh bấm qua lại không thấy gì đổi.
    final labels = <TopicFilter, String>{
      TopicFilter.forYou: l10n.pzTopicsFilterForYou,
      TopicFilter.saved: l10n.pzTopicsFilterSaved,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            SelectablePill(
              label: entry.value,
              active: entry.key == selected,
              onTap: () => onSelect(entry.key),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// The highlighted top match.
class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.topic,
    required this.onSpeak,
    required this.onToggleSaved,
    required this.onDismiss,
  });

  final PracticeTopic topic;
  final VoidCallback onSpeak;
  final VoidCallback onToggleSaved;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  l10n.pzTopicsPriority,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: Colors.white,
                  ),
                ),
              ),
              if (topic.matchPercent != null) ...[
                const SizedBox(width: 8),
                Text(
                  l10n.pzTopicsMatch(topic.matchPercent!),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
              const Spacer(),
              _SaveButton(
                saved: topic.buckets.contains(TopicFilter.saved),
                onTap: onToggleSaved,
              ),
              _DismissButton(onTap: onDismiss),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            topic.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.32,
            ),
          ),
          if (topic.rationale != null) ...[
            const SizedBox(height: 6),
            Text(
              topic.rationale!,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: Color(0xFF4C4A75),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSpeak,
              icon: const Icon(Icons.mic, size: 18),
              label: Text(l10n.pzTopicsSpeakThis),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.indigo,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(99),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bookmark toggle shared by `_PriorityCard` and `_TopicRow`.
/// "Không thích chủ đề này" — loại thẻ khỏi lô đang chào.
///
/// Khác nút "Đổi gợi ý" trên thanh tiêu đề: cái kia đổi CẢ LÔ và chỉ nhớ trong màn hình này,
/// còn nút này gửi tín hiệu âm 0,15 xuống backend nên chủ đề tụt hạng ở mọi lần mở sau.
class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          size: 20,
          color: Color(0xFF999999),
          semanticLabel: 'Không thích chủ đề này',
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          saved ? Icons.bookmark : Icons.bookmark_border,
          size: 20,
          color: saved ? AppColors.indigo : const Color(0xFF999999),
          semanticLabel: saved ? l10n.pzTopicsUnsave : l10n.pzTopicsSave,
        ),
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.onTap,
    required this.onToggleSaved,
    required this.onDismiss,
  });

  final PracticeTopic topic;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: rowDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.fieldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconForName(topic.icon),
                size: 22,
                color: const Color(0xFF555555),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                      _SaveButton(
                        saved: topic.buckets.contains(TopicFilter.saved),
                        onTap: onToggleSaved,
                      ),
                      _DismissButton(onTap: onDismiss),
                    ],
                  ),
                  if (topic.reasons.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final reason in topic.reasons)
                          TagChip.blue(reason),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterTip extends StatelessWidget {
  const _FooterTip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.headerBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.tips_and_updates_outlined,
            size: 18,
            color: AppColors.indigo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '${l10n.pzTopicsFooterTip} ',
                children: [
                  TextSpan(
                    text: l10n.pzTopicsWhy,
                    style: const TextStyle(
                      color: AppColors.indigo,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
