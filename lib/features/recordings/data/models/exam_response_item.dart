class ExamResponseItem {
  const ExamResponseItem({
    required this.responseId,
    this.itemScore,
  });

  final String responseId;
  final double? itemScore;

  factory ExamResponseItem.fromJson(Map<String, dynamic> json) {
    return ExamResponseItem(
      responseId: json['responseId'] as String,
      itemScore: (json['itemScore'] as num?)?.toDouble(),
    );
  }
}
