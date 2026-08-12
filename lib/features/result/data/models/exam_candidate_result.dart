import 'exam_result_summary.dart';

class ExamCandidateResultSection {
  const ExamCandidateResultSection({
    required this.sectionId,
    required this.title,
    required this.score,
  });

  final String sectionId;
  final String? title;
  final double score;

  factory ExamCandidateResultSection.fromJson(Map<String, dynamic> json) {
    return ExamCandidateResultSection(
      sectionId: json['sectionId'] as String,
      title: json['title'] as String?,
      score: (json['score'] as num).toDouble(),
    );
  }
}

/// One graded part of the attempt — the unit a student picks when appealing.
class ExamCandidateResultItem {
  const ExamCandidateResultItem({
    required this.paperItemId,
    required this.responseId,
    required this.sectionId,
    required this.itemScore,
  });

  final String paperItemId;

  /// Khoá để hỏi chi tiết AI chấm: `examItemResponseEvaluation(answerId: responseId)`.
  final String responseId;
  final String sectionId;
  final double itemScore;

  factory ExamCandidateResultItem.fromJson(Map<String, dynamic> json) {
    return ExamCandidateResultItem(
      paperItemId: json['paperItemId'] as String,
      responseId: json['responseId'] as String,
      sectionId: json['sectionId'] as String,
      itemScore: (json['itemScore'] as num).toDouble(),
    );
  }
}

/// Điểm AI chấm cho MỘT tiêu chí của một câu.
class ExamItemCriterionScore {
  const ExamItemCriterionScore({
    required this.criterionName,
    required this.finalScore,
    required this.minScore,
    required this.maxScore,
    required this.rationale,
  });

  final String criterionName;
  final double? finalScore;
  final double? minScore;
  final double? maxScore;

  /// Lời giải thích AI viết cho tiêu chí này -- thứ đáng đọc nhất trong cả bản chấm.
  final String? rationale;

  factory ExamItemCriterionScore.fromJson(Map<String, dynamic> json) {
    return ExamItemCriterionScore(
      // criterionName có thể null nếu rubric không đặt tên; rơi về mã tiêu chí.
      criterionName: (json['criterionName'] as String?) ??
          (json['criterionCode'] as String?) ??
          '—',
      finalScore: (json['finalScore'] as num?)?.toDouble(),
      minScore: (json['minScore'] as num?)?.toDouble(),
      maxScore: (json['maxScore'] as num?)?.toDouble(),
      rationale: json['rationale'] as String?,
    );
  }
}

/// Bản chấm AI của một câu trả lời (`examItemResponseEvaluation`).
class ExamItemEvaluation {
  const ExamItemEvaluation({
    required this.itemScore,
    required this.feedbackSummary,
    required this.criteria,
    required this.markedInvalid,
  });

  final double? itemScore;
  final String? feedbackSummary;
  final List<ExamItemCriterionScore> criteria;
  final bool markedInvalid;

  factory ExamItemEvaluation.fromJson(Map<String, dynamic> json) {
    return ExamItemEvaluation(
      itemScore: (json['itemScore'] as num?)?.toDouble(),
      feedbackSummary: json['feedbackSummary'] as String?,
      markedInvalid: json['markedInvalid'] as bool? ?? false,
      criteria: (json['criteria'] as List? ?? const [])
          .map((e) => ExamItemCriterionScore.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Full per-attempt result, from `examSessionResult` (ExamCandidateResult).
class ExamCandidateResult {
  const ExamCandidateResult({
    required this.id,
    required this.scoreVisible,
    required this.totalScore,
    required this.scoringScaleMin,
    required this.scoringScaleMax,
    required this.status,
    required this.sections,
    required this.items,
  });

  /// candidateResultId — required to submit an appeal for this attempt.
  final String id;
  final bool scoreVisible;
  final double? totalScore;

  /// Thang điểm THẬT của rubric chấm bài này, do backend trả về.
  ///
  /// Trước 2026-08-11 màn kết quả viết cứng `/ 10`, nên với rubric thang 0-100 đang chạy thật thì
  /// bài 79,13 điểm hiện thành "79.1 / 10" và thanh điểm từng phần đầy 100% ở mọi phần. Đừng đoán
  /// lại thang từ giá trị điểm -- 8.0 có thể là 8/10 mà cũng có thể là 8/100.
  final double? scoringScaleMin;
  final double? scoringScaleMax;

  /// Bề rộng thang, dùng làm mẫu số cho thanh tiến trình. Null/không hợp lệ thì trả null để nơi
  /// dùng tự quyết cách hiển thị, KHÔNG lặng lẽ rơi về 10 như cũ.
  double? get scoreSpan {
    final min = scoringScaleMin;
    final max = scoringScaleMax;
    if (min == null || max == null || max <= min) return null;
    return max - min;
  }

  /// Vị trí của [score] trong thang, 0..1. Dùng cho thanh điểm từng phần.
  double? ratioOf(double score) {
    final span = scoreSpan;
    if (span == null) return null;
    return ((score - scoringScaleMin!) / span).clamp(0.0, 1.0);
  }
  final ExamResultStatus status;
  final List<ExamCandidateResultSection> sections;
  final List<ExamCandidateResultItem> items;

  factory ExamCandidateResult.fromJson(Map<String, dynamic> json) {
    return ExamCandidateResult(
      id: json['id'] as String,
      scoreVisible: json['scoreVisible'] as bool? ?? false,
      totalScore: (json['totalScore'] as num?)?.toDouble(),
      scoringScaleMin: (json['scoringScaleMin'] as num?)?.toDouble(),
      scoringScaleMax: (json['scoringScaleMax'] as num?)?.toDouble(),
      status: ExamResultSummary.statusFromJson(json['status'] as String?),
      sections: (json['sections'] as List? ?? const [])
          .map((e) =>
              ExamCandidateResultSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List? ?? const [])
          .map((e) =>
              ExamCandidateResultItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
