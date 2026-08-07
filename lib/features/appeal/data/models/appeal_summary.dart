class AppealSummary {
  const AppealSummary({
    required this.id,
    required this.className,
    required this.examName,
    required this.partLabels,
    required this.originalScore,
    required this.status,
    required this.requestedAt,
    required this.deadline,
    required this.overdue,
  });

  final String id;
  final String? className;
  final String examName;
  final List<String> partLabels;
  final double? originalScore;
  final String status;
  final DateTime requestedAt;
  final DateTime? deadline;
  final bool overdue;

  factory AppealSummary.fromJson(Map<String, dynamic> json) => AppealSummary(
        id: json['id'] as String,
        className: json['className'] as String?,
        examName: json['examName'] as String,
        partLabels: (json['partLabels'] as List).cast<String>(),
        originalScore: (json['originalScore'] as num?)?.toDouble(),
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        deadline: json['deadline'] == null
            ? null
            : DateTime.parse(json['deadline'] as String),
        overdue: json['overdue'] as bool,
      );
}
