import 'exam_schedule.dart';

class ExamRoomSchedule {
  final String id;
  final String examId;
  final String? roomName;
  final String? roomCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String> proctorUserIds;

  /// Bài thi của ca này -- chỉ có khi query có hỏi field `exam` (luồng học sinh).
  /// Luồng giáo viên lấy bài thi từ nguồn khác nên để null.
  final ExamSchedule? exam;

  const ExamRoomSchedule({
    required this.id,
    required this.examId,
    this.roomName,
    this.roomCode,
    this.startDate,
    this.endDate,
    this.proctorUserIds = const [],
    this.exam,
  });

  factory ExamRoomSchedule.fromJson(Map<String, dynamic> json) {
    final room = json['room'] as Map<String, dynamic>?;
    final proctors = (json['proctors'] as List<dynamic>?) ?? const [];
    final exam = json['exam'] as Map<String, dynamic>?;
    return ExamRoomSchedule(
      id: json['id'] as String,
      examId: json['examId'] as String,
      roomName: room?['name'] as String?,
      roomCode: room?['code'] as String?,
      startDate: _parseDate(json['startDate'] as String?),
      endDate: _parseDate(json['endDate'] as String?),
      proctorUserIds: proctors
          .map((p) => ((p as Map<String, dynamic>)['teacher']
              as Map<String, dynamic>?)?['id'] as String?)
          .whereType<String>()
          .toList(),
      exam: exam == null ? null : ExamSchedule.fromJson(exam),
    );
  }

  static DateTime? _parseDate(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toLocal();
}
