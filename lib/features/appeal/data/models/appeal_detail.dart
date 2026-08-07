class AppealDetail {
  const AppealDetail({required this.id, required this.examName, required this.status, required this.requestedAt, required this.reason, required this.originalScore, this.className, this.deadline, this.notes, this.decisionNote, this.finalScore});
  final String id;
  final String examName;
  final String? className;
  final String status;
  final DateTime requestedAt;
  final DateTime? deadline;
  final String reason;
  final String? notes;
  final String? decisionNote;
  final double? originalScore;
  final double? finalScore;

  factory AppealDetail.fromJson(Map<String, dynamic> json) => AppealDetail(
        id: json['id'] as String,
        examName: json['examName'] as String,
        className: json['className'] as String?,
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String),
        deadline: json['deadline'] == null ? null : DateTime.tryParse(json['deadline'] as String),
        reason: json['reason'] as String,
        notes: json['notes'] as String?,
        decisionNote: json['decisionNote'] as String?,
        originalScore: (json['originalScore'] as num?)?.toDouble(),
        finalScore: (json['finalScore'] as num?)?.toDouble(),
      );
}
