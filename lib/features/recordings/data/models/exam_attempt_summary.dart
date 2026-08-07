/// One past exam attempt, from `myExamResults` (StudentExamResultSummary).
class ExamAttemptSummary {
  const ExamAttemptSummary({
    required this.sessionId,
    required this.examName,
    this.submittedAt,
    this.totalScore,
    this.sessionStatus,
  });

  final String sessionId;
  final String? examName;
  final DateTime? submittedAt;
  final double? totalScore;
  final String? sessionStatus;

  factory ExamAttemptSummary.fromJson(Map<String, dynamic> json) {
    return ExamAttemptSummary(
      sessionId: json['sessionId'] as String,
      examName: json['examName'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      totalScore: (json['totalScore'] as num?)?.toDouble(),
      sessionStatus: json['sessionStatus'] as String?,
    );
  }
}
