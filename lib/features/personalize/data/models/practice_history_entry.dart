/// One row from `myPracticeHistory` — a past practice session summary, NOT
/// the live turn-by-turn session model ([PracticeSession] in
/// `practice_session.dart`, which is a different shape for the realtime view).
class PracticeHistoryEntry {
  final String id;
  final String topicId;
  final String topicName;
  final String origin;
  final String status;
  final double? overallScore;
  final int gradedSeconds;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Số câu đã nói mà chưa chấm xong.
  ///
  /// > 0 nghĩa là [overallScore] còn TẠM: nó chỉ gộp những câu đã có bản chấm, và sẽ đổi khi
  /// các câu còn lại về (thường sau vài chục giây). Màn chi tiết đã biết điều này và giấu điểm
  /// đi khi còn chờ -- danh sách phải nói cùng một chuyện, nếu không cùng một phiên hiện ba con
  /// số khác nhau ở ba thời điểm.
  final int pendingEvaluations;

  const PracticeHistoryEntry({
    required this.id,
    required this.topicId,
    required this.topicName,
    required this.origin,
    required this.status,
    this.overallScore,
    required this.gradedSeconds,
    this.startedAt,
    this.endedAt,
    this.pendingEvaluations = 0,
  });

  /// Điểm đang hiển thị có phải là số CHỐT không.
  bool get scoreIsFinal => pendingEvaluations == 0;

  factory PracticeHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PracticeHistoryEntry(
      id: json['id'] as String,
      topicId: json['topicId'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      status: json['status'] as String? ?? '',
      overallScore: (json['overallScore'] as num?)?.toDouble(),
      gradedSeconds: (json['gradedSeconds'] as num?)?.toInt() ?? 0,
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.tryParse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.tryParse(json['endedAt'] as String),
      pendingEvaluations: (json['pendingEvaluations'] as num?)?.toInt() ?? 0,
    );
  }
}
