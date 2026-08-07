import 'dart:convert';

class PhonemeFeedback {
  const PhonemeFeedback({required this.phoneme, this.color, this.accuracyScore, this.note});
  final String phoneme;
  final String? color;
  final double? accuracyScore;
  final String? note;

  factory PhonemeFeedback.fromJson(Map<String, dynamic> json) => PhonemeFeedback(
        phoneme: json['phoneme'] as String? ?? '',
        color: json['color'] as String?,
        accuracyScore: (json['accuracyScore'] as num?)?.toDouble(),
        note: json['note'] as String?,
      );
}

class WordFeedback {
  const WordFeedback({required this.word, this.color, this.accuracyScore, this.errorNote, this.phonemes = const []});
  final String word;
  final String? color;
  final double? accuracyScore;
  final String? errorNote;
  final List<PhonemeFeedback> phonemes;

  factory WordFeedback.fromJson(Map<String, dynamic> json) => WordFeedback(
        word: json['word'] as String? ?? '',
        color: json['color'] as String?,
        accuracyScore: (json['accuracyScore'] as num?)?.toDouble(),
        errorNote: json['errorNote'] as String?,
        phonemes: (json['phonemes'] as List? ?? const []).map((item) => PhonemeFeedback.fromJson(item as Map<String, dynamic>)).toList(),
      );
}

class ExamItemCriterionScore {
  const ExamItemCriterionScore({required this.criterionCode, this.criterionName, this.finalScore, this.minScore, this.maxScore, this.rationale});
  final String criterionCode;
  final String? criterionName;
  final double? finalScore;
  final double? minScore;
  final double? maxScore;
  final String? rationale;

  factory ExamItemCriterionScore.fromJson(Map<String, dynamic> json) => ExamItemCriterionScore(
        criterionCode: json['criterionCode'] as String? ?? '',
        criterionName: json['criterionName'] as String?,
        finalScore: (json['finalScore'] as num?)?.toDouble(),
        minScore: (json['minScore'] as num?)?.toDouble(),
        maxScore: (json['maxScore'] as num?)?.toDouble(),
        rationale: json['rationale'] as String?,
      );
}

class ExamItemEvaluationTurn {
  const ExamItemEvaluationTurn({required this.id, required this.turnOrder, this.wordFeedback = const []});
  final String id;
  final int turnOrder;
  final List<WordFeedback> wordFeedback;

  factory ExamItemEvaluationTurn.fromJson(Map<String, dynamic> json) {
    final raw = json['wordFeedback'];
    dynamic decoded = raw;
    if (raw is String && raw.isNotEmpty) {
      try { decoded = jsonDecode(raw); } catch (_) { decoded = const []; }
    }
    return ExamItemEvaluationTurn(
      id: json['id'] as String,
      turnOrder: (json['turnOrder'] as num?)?.toInt() ?? 0,
      wordFeedback: (decoded as List? ?? const []).map((item) => WordFeedback.fromJson(item as Map<String, dynamic>)).toList(),
    );
  }
}

class ExamItemEvaluation {
  const ExamItemEvaluation({
    this.criteria = const [],
    this.turns = const [],
    this.feedbackSummary,
  });
  final List<ExamItemCriterionScore> criteria;
  final List<ExamItemEvaluationTurn> turns;

  /// Nhận xét chung AI viết cho cả câu. Schema đã có từ lâu (`ExamItemEvaluationDetails
  /// .feedbackSummary`) nhưng màn này chưa từng xin -- mà đây đúng là câu trả lời cho
  /// "AI chấm câu này thế nào", chứ điểm từng tiêu chí chỉ nói được phần nào.
  final String? feedbackSummary;

  factory ExamItemEvaluation.fromJson(Map<String, dynamic> json) => ExamItemEvaluation(
        criteria: (json['criteria'] as List? ?? const []).map((item) => ExamItemCriterionScore.fromJson(item as Map<String, dynamic>)).toList(),
        turns: (json['turns'] as List? ?? const []).map((item) => ExamItemEvaluationTurn.fromJson(item as Map<String, dynamic>)).toList(),
        feedbackSummary: json['feedbackSummary'] as String?,
      );
}
