import '../../../schedule/data/models/exam_schedule.dart';

class ExamMemberRef {
  final String userId;
  final String role;
  final String? fullName;

  const ExamMemberRef({
    required this.userId,
    required this.role,
    this.fullName,
  });

  factory ExamMemberRef.fromJson(Map<String, dynamic> json) {
    return ExamMemberRef(
      userId: json['userId'] as String,
      role: json['role'] as String? ?? '',
      fullName: (json['user'] as Map<String, dynamic>?)?['fullName'] as String?,
    );
  }
}

class ExamDetail {
  final String id;
  final String? code;
  final String name;
  final String? description;
  final ExamKind kind;
  final ExamLifecycleStatus status;
  final DateTime? openAt;
  final DateTime? closeAt;
  final String? schoolClassId;
  final String? blueprintId;
  final String? blueprintVersionId;
  final List<ExamMemberRef> members;

  const ExamDetail({
    required this.id,
    this.code,
    required this.name,
    this.description,
    required this.kind,
    required this.status,
    this.openAt,
    this.closeAt,
    this.schoolClassId,
    this.blueprintId,
    this.blueprintVersionId,
    this.members = const [],
  });

  factory ExamDetail.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List<dynamic>?) ?? const [];
    return ExamDetail(
      id: json['id'] as String,
      code: json['code'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      kind: _kindFromJson(json['kind'] as String?),
      status: _statusFromJson(json['status'] as String?),
      openAt: _parseDate(json['openAt'] as String?),
      closeAt: _parseDate(json['closeAt'] as String?),
      schoolClassId: json['schoolClassId'] as String?,
      blueprintId: json['blueprintId'] as String?,
      blueprintVersionId: json['blueprintVersionId'] as String?,
      members: members
          .map((e) => ExamMemberRef.fromJson(e as Map<String, dynamic>))
          .toList(),
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
