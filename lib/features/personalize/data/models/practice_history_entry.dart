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
  });

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
    );
  }
}
