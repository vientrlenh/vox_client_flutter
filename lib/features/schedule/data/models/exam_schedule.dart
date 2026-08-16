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

  /// Dựng từ một CA THI (`myExamSchedules`) thay vì từ kỳ thi.
  ///
  /// Khác biệt quan trọng nằm ở thời gian: `openAt`/`closeAt` của kỳ thi là cửa sổ cho phép
  /// làm bài của CẢ kỳ, còn `startDate`/`endDate` của ca là giờ thi THẬT của chính học sinh
  /// này. Trang chủ hỏi "sắp thi lúc nào" nên phải dùng giờ của ca.
  ///
  /// `id` lấy của KỲ THI chứ không phải của ca: mọi màn phía sau đều điều hướng theo examId,
  /// và một học sinh chỉ có một ca cho mỗi kỳ nên không mất thông tin.
  factory ExamSchedule.fromScheduleJson(Map<String, dynamic> json) {
    final exam = json['exam'] as Map<String, dynamic>?;
    return ExamSchedule(
      id: (exam?['id'] ?? json['id']) as String,
      name: (exam?['name'] as String?) ?? '',
      description: exam?['description'] as String?,
      kind: _kindFromJson(exam?['kind'] as String?),
      status: _statusFromJson(exam?['status'] as String?),
      openAt: _parseDate(json['startDate'] as String?),
      closeAt: _parseDate(json['endDate'] as String?),
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
