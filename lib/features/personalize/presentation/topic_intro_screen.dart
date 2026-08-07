import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../data/models/practice_band_option.dart';
import '../data/models/practice_topic.dart';
import '../data/personalize_repository.dart';
import 'personalize_styles.dart';

/// Trang xác nhận trước khi vào phiên: chủ đề vừa chọn + độ khó.
///
/// Thay cho `showBandPickerSheet`. Lý do đổi từ bảng trượt sang TRANG riêng: chủ đề tới từ
/// nhiều lối vào khác nhau (thẻ "hôm nay luyện gì" ở trang chủ, thẻ gợi ý, màn chọn chủ đề,
/// tìm theo từ khoá, nút chọn ngẫu nhiên). Bảng trượt bật lên đè ngay lên màn cũ nên với ba
/// lối sau, học sinh không kịp thấy mình sắp luyện chủ đề gì -- rõ nhất ở nút "Chọn ngẫu
/// nhiên", nơi chủ đề do hệ thống bốc và bảng độ khó che luôn tên nó.
///
/// Một trang thì tên chủ đề, lý do được chào và độ khó nằm cùng một chỗ, đọc rồi mới bắt đầu.
class TopicIntroScreen extends StatefulWidget {
  const TopicIntroScreen({super.key, required this.topic});

  final PracticeTopic topic;

  @override
  State<TopicIntroScreen> createState() => _TopicIntroScreenState();
}

class _TopicIntroScreenState extends State<TopicIntroScreen> {
  final _repository = PersonalizeRepository();

  bool _loading = true;
  String? _error;
  List<PracticeBandOption> _options = const [];
  String? _selectedId;

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
      final result = await _repository.getPracticeBandOptions();
      if (!mounted) return;
      setState(() {
        _options = result.options;
        // Chọn sẵn bậc mục tiêu của trường -- điểm khởi đầu có cơ sở, không phải tuyên bố
        // "đây là trình độ của em". Học sinh đổi thoải mái.
        _selectedId = _options
            .where((option) => option.code == result.defaultCode)
            .map((option) => option.id)
            .firstOrNull;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Chuẩn bị luyện nói',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _TopicHeader(topic: topic),
                const SizedBox(height: 22),
                const Text(
                  'Chọn độ khó cho buổi luyện',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Câu hỏi sẽ được chọn quanh mức em chọn. Buổi sau đổi lại được.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textFaint),
                ),
                const SizedBox(height: 12),
                _bandList(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                height: 50,
                width: double.infinity,
                child: FilledButton(
                  // Không có bậc nào chọn thì không cho bắt đầu: hệ thống không còn suy ra
                  // bậc của học sinh nữa, nên không có giá trị nào đúng để điền thay em.
                  onPressed: _selectedId == null
                      ? null
                      : () => Navigator.of(context).pop(
                            _options.firstWhere((option) => option.id == _selectedId),
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Bắt đầu'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandList() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textFaint)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Trường chưa cấu hình thang bậc nào cho khung đánh giá đang dùng.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textFaint),
        ),
      );
    }
    return Column(
      children: [
        for (final option in _options) ...[
          _BandOptionTile(
            option: option,
            selected: option.id == _selectedId,
            onTap: () => setState(() => _selectedId = option.id),
          ),
          if (option != _options.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TopicHeader extends StatelessWidget {
  const _TopicHeader({required this.topic});

  /// Trên ngưỡng này thì không còn là nhãn -- dựng thành đoạn văn thay vì viên thuốc.
  static const _chipMaxChars = 48;

  final PracticeTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.chipBlueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconForName(topic.icon), size: 24, color: AppColors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          // Vì sao chủ đề này được chào.
          //
          // Backend gửi cả hai loại qua cùng một trường `reasons`, nhưng nội dung khác hẳn nhau
          // về BẢN CHẤT:
          //   - chủ đề xếp hạng  -> "Gợi ý cho bạn", 13 ký tự, đúng là một cái nhãn
          //   - chủ đề từ từ khoá -> cả đoạn LLM giải thích, vài trăm ký tự
          //
          // Nhét đoạn văn vào viên thuốc bo tròn 99 thì nó xuống 7 dòng và thành một vệt xám
          // to đùng -- hình dạng nói "đây là nhãn" trong khi nội dung là lời giải thích.
          //
          // Chọn theo ĐỘ DÀI chứ không theo nguồn: client không biết chủ đề đến từ đâu, mà
          // nhãn thì ngắn theo bản chất -- dài quá ngưỡng nghĩa là nó không còn là nhãn nữa.
          if (topic.reasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (topic.reasons.every((reason) => reason.length <= _chipMaxChars))
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final reason in topic.reasons)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.fieldBg,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(reason,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ),
                ],
              )
            else
              for (final reason in topic.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    reason,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _BandOptionTile extends StatelessWidget {
  const _BandOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PracticeBandOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.indigo : AppColors.borderSoft,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? AppColors.indigo : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.label,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if ((option.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      option.description!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textFaint, height: 1.35),
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
