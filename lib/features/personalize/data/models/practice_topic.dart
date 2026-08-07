/// Buckets behind the filter pills on the topics screen.
///
/// `byGoal`/`byWeakness` đã bỏ cùng hồ sơ điểm yếu: backend chỉ còn một công thức xếp hạng
/// nên ba rổ sẽ trả về cùng một danh sách.
enum TopicFilter { forYou, saved }

/// A speaking topic the app can propose for a practice session.
class PracticeTopic {
  final String id;
  final String title;

  /// Why this topic was picked — shown on the priority card.
  final String? rationale;
  final int minutes;

  /// 0..100 match score; only the top suggestion renders it.
  final int? matchPercent;

  /// Short "Vì bạn thích bóng đá" style chips.
  final List<String> reasons;

  /// Material icon codepoint name resolved by the UI; kept as a plain string
  /// so the model stays free of Flutter imports.
  final String icon;
  final Set<TopicFilter> buckets;

  /// HỌC SINH đến với chủ đề này bằng đường nào -- quyết định độ mạnh của tín hiệu sở thích
  /// ghi lại ở cuối phiên (thiết kế gói 6 mục 2.5/2.8, cài trong
  /// `InterestVectorService.recordSessionOutcome`):
  ///
  /// | origin | hoàn thành | bỏ dở vì chán |
  /// |---|---|---|
  /// | `KEYWORD` (tự gõ tìm) | 1.00 | 0.20 |
  /// | `SELECTED` (tự bấm thẻ) | 0.95 | 0.15 |
  /// | `EXPLORATION` (bấm "chọn giúp tôi") | 0.60 | 0.10 |
  /// | `EPSILON` (hệ thống tráo vào lô chào) | 0.60 | 0.10 |
  ///
  /// Phải đi theo chủ đề chứ không gán cứng lúc vào phiên: hệ thống tự đưa chủ đề mà ghi
  /// 0.95 như học sinh tự chọn là **dương giả** -- đúng thứ thiết kế cảnh báo.
  ///
  /// `EPSILON` KHÔNG do client gửi. Học sinh tưởng mình tự bấm nên client gửi `SELECTED`;
  /// backend tự suy ra bằng cách xếp hạng lại (`BuildPracticePaperUseCase.resolveOrigin`).
  final String origin;

  /// Cả lô thẻ đang hiện lúc học sinh bấm chọn chủ đề này, và các lô đã bị "Đổi gợi ý" trước
  /// đó. Backend dùng chúng để ghi tín hiệu ÂM cho chủ đề đã chào mà không được chọn -- 0.30
  /// cho lô hiện tại, 0.20 cho lô trước (`InterestVectorService.recordSessionOutcome`, từ
  /// chối hai lần thì nặng hơn một lần).
  ///
  /// Đi theo chủ đề vì cùng lý do với [origin]: đây là NGỮ CẢNH của lượt chào, không phải
  /// thuộc tính của chủ đề, mà lượt chào thì chỉ màn chọn chủ đề biết. Đường vào từ thẻ
  /// "hôm nay luyện gì" không có lô chào nào nên để rỗng -- rỗng nghĩa là *không có thông tin*,
  /// khác hẳn với *đã chào mà bị bỏ qua*.
  ///
  /// Chủ đề được chọn có nằm trong [offeredTopicIds] cũng không sao: backend loại nó ra bằng
  /// `alreadyRecorded` trước khi ghi tín hiệu âm.
  final List<String> offeredTopicIds;
  final List<String> previousOfferedTopicIds;

  const PracticeTopic({
    required this.id,
    required this.title,
    this.rationale,
    required this.minutes,
    this.matchPercent,
    this.reasons = const [],
    this.icon = 'chat_bubble_outline',
    this.buckets = const {TopicFilter.forYou},
    this.origin = 'SELECTED',
    this.offeredTopicIds = const [],
    this.previousOfferedTopicIds = const [],
  });

  /// Bản sao đổi vài trường. Có mặt vì trước đây mỗi chỗ cần đổi một trường lại dựng tay
  /// `PracticeTopic(...)` mới và **quên** những trường không liên quan tới việc mình đang làm
  /// -- `_toggleSaved` chẳng hạn, đổi mỗi cờ đã lưu nhưng làm `origin` tụt về mặc định
  /// 'SELECTED', tức tín hiệu sở thích bị ghi sai ngay sau khi học sinh bấm lưu.
  PracticeTopic copyWith({
    Set<TopicFilter>? buckets,
    String? origin,
    List<String>? offeredTopicIds,
    List<String>? previousOfferedTopicIds,
  }) {
    return PracticeTopic(
      id: id,
      title: title,
      rationale: rationale,
      minutes: minutes,
      matchPercent: matchPercent,
      reasons: reasons,
      icon: icon,
      buckets: buckets ?? this.buckets,
      origin: origin ?? this.origin,
      offeredTopicIds: offeredTopicIds ?? this.offeredTopicIds,
      previousOfferedTopicIds:
          previousOfferedTopicIds ?? this.previousOfferedTopicIds,
    );
  }

  /// Builds from the real backend shape (`PracticeTopicOffer`/`TopicSearchResult.topics`
  /// in `practice-planning.graphqls`) — see gói 11 mục 2.6b for the field-by-field mapping.
  factory PracticeTopic.fromOffer(
    Map<String, dynamic> json, {
    TopicFilter bucket = TopicFilter.forYou,
    String origin = 'SELECTED',
  }) {
    final savedByMe = json['savedByMe'] as bool? ?? false;
    return PracticeTopic(
      id: json['topicId'] as String,
      title: json['name'] as String,
      rationale: json['rationale'] as String?,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      matchPercent: (json['matchPercent'] as num?)?.toInt(),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      buckets: {bucket, if (savedByMe) TopicFilter.saved},
      origin: origin,
    );
  }

  factory PracticeTopic.fromJson(Map<String, dynamic> json) {
    return PracticeTopic(
      id: json['id'] as String,
      title: json['title'] as String,
      rationale: json['rationale'] as String?,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      matchPercent: (json['matchPercent'] as num?)?.toInt(),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      icon: json['icon'] as String? ?? 'chat_bubble_outline',
      buckets: (json['buckets'] as List<dynamic>? ?? const [])
          .map((e) => _filterFromJson(e as String?))
          .toSet(),
    );
  }

  static TopicFilter _filterFromJson(String? value) {
    return value == 'SAVED' ? TopicFilter.saved : TopicFilter.forYou;
  }
}
