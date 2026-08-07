enum ExamKind { centralized, classTest }

enum ExamLifecycleStatus { draft, scheduled, inProgress, closed, resultsPublished, cancelled }

class ExamSchedule {
  final String id;
  final String name;
  final String? description;
  final ExamKind kind;
  final ExamLifecycleStatus status;
  final DateTime? openAt;
  final DateTime? closeAt;

  const ExamSchedule({
    required this.id,
    required this.name,
    this.description,
    required this.kind,
    required this.status,
    this.openAt,
    this.closeAt,
  });

  factory ExamSchedule.fromJson(Map<String, dynamic> json) {
    return ExamSchedule(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      kind: _kindFromJson(json['kind'] as String?),
      status: _statusFromJson(json['status'] as String?),
      openAt: _parseDate(json['openAt'] as String?),
      closeAt: _parseDate(json['closeAt'] as String?),
    );
  }

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();

  static ExamKind _kindFromJson(String? value) {
    switch (value) {
      case 'CLASS_TEST':
        return ExamKind.classTest;
      case 'CENTRALIZED':
      default:
        return ExamKind.centralized;
    }
  }

  static ExamLifecycleStatus _statusFromJson(String? value) {
    switch (value) {
      case 'DRAFT':
        return ExamLifecycleStatus.draft;
      case 'IN_PROGRESS':
        return ExamLifecycleStatus.inProgress;
      case 'CLOSED':
        return ExamLifecycleStatus.closed;
      case 'RESULTS_PUBLISHED':
        return ExamLifecycleStatus.resultsPublished;
      case 'CANCELLED':
        return ExamLifecycleStatus.cancelled;
      case 'SCHEDULED':
      default:
        return ExamLifecycleStatus.scheduled;
    }
  }
}
