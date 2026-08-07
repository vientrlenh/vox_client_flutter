enum ExamResultStatus {
  pendingReview,
  released,
  appealed,
  reGrading,
  final_,
  invalid,
  retakeRequired,
  passed,
  failed,
}

enum ExamKind { centralized, classTest }

/// One past exam attempt, from `myExamResults` (StudentExamResultSummary).
class ExamResultSummary {
  const ExamResultSummary({
    required this.examId,
    required this.examCode,
    required this.kind,
    required this.sessionId,
    required this.sessionStatus,
    required this.examName,
    required this.totalScore,
    required this.status,
    required this.submittedAt,
    required this.startedAt,
  });

  final String examId;
  final String? examCode;
  final ExamKind kind;
  final String sessionId;
  final String? sessionStatus;
  final String examName;
  final double? totalScore;
  final ExamResultStatus status;
  final DateTime? submittedAt;
  final DateTime? startedAt;

  factory ExamResultSummary.fromJson(Map<String, dynamic> json) {
    return ExamResultSummary(
      examId: json['examId'] as String,
      examCode: json['examCode'] as String?,
      kind: json['kind'] == 'CLASS_TEST'
          ? ExamKind.classTest
          : ExamKind.centralized,
      sessionId: json['sessionId'] as String,
      sessionStatus: json['sessionStatus'] as String?,
      examName: json['examName'] as String? ?? 'Exam',
      totalScore: (json['totalScore'] as num?)?.toDouble(),
      status: statusFromJson(json['resultStatus'] as String?),
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
    );
  }

  static ExamResultStatus statusFromJson(String? value) {
    switch (value) {
      case 'RELEASED':
        return ExamResultStatus.released;
      case 'APPEALED':
        return ExamResultStatus.appealed;
      case 'RE_GRADING':
        return ExamResultStatus.reGrading;
      case 'FINAL':
        return ExamResultStatus.final_;
      case 'INVALID':
        return ExamResultStatus.invalid;
      case 'RETAKE_REQUIRED':
        return ExamResultStatus.retakeRequired;
      case 'PASSED':
        return ExamResultStatus.passed;
      case 'FAILED':
        return ExamResultStatus.failed;
      case 'PENDING_REVIEW':
      default:
        return ExamResultStatus.pendingReview;
    }
  }
}

class ExamResultGroup {
  const ExamResultGroup({
    required this.examId,
    required this.examName,
    required this.sessions,
  });

  final String examId;
  final String examName;
  final List<ExamResultSummary> sessions;

  DateTime? get latestStartedAt =>
      sessions.isEmpty ? null : sessions.first.startedAt;
}
