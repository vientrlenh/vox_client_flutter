enum QuestionType { readAloud, shortAnswer, longAnswer, opinion, description }

QuestionType _typeFromJson(String? value) {
  switch (value) {
    case 'SHORT_ANSWER':
      return QuestionType.shortAnswer;
    case 'LONG_ANSWER':
      return QuestionType.longAnswer;
    case 'OPINION':
      return QuestionType.opinion;
    case 'DESCRIPTION':
      return QuestionType.description;
    case 'READ_ALOUD':
    default:
      return QuestionType.readAloud;
  }
}

class TeacherQuestion {
  final String id;
  final String? code;
  final String questionText;
  final String? promptText;
  final QuestionType type;
  final String? sharing;
  final String? status;

  const TeacherQuestion({
    required this.id,
    this.code,
    required this.questionText,
    this.promptText,
    required this.type,
    this.sharing,
    this.status,
  });

  factory TeacherQuestion.fromJson(Map<String, dynamic> json) {
    return TeacherQuestion(
      id: json['id'] as String,
      code: json['code'] as String?,
      questionText: json['questionText'] as String? ?? '',
      promptText: json['promptText'] as String?,
      type: _typeFromJson(json['type'] as String?),
      sharing: json['sharing'] as String?,
      status: json['status'] as String?,
    );
  }
}
