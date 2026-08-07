import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/exam_detail.dart';

class TeacherExamRestApi {
  TeacherExamRestApi(this._client);

  final ApiClient _client;

  Future<ExamDetail> createClassTest({
    required String schoolClassId,
    required String name,
    String? description,
    DateTime? openAt,
    DateTime? closeAt,
    List<String>? questionIds,
    String? existingBlueprintId,
    String? existingBlueprintVersionId,
  }) async {
    final response = await _client.post(ApiEndpoints.classTests, data: {
      'schoolClassId': schoolClassId,
      'name': name,
      if (description != null) 'description': description,
      if (openAt != null) 'openAt': openAt.toUtc().toIso8601String(),
      if (closeAt != null) 'closeAt': closeAt.toUtc().toIso8601String(),
      if (questionIds != null) 'questionIds': questionIds,
      if (existingBlueprintId != null)
        'existingBlueprintId': existingBlueprintId,
      if (existingBlueprintVersionId != null)
        'existingBlueprintVersionId': existingBlueprintVersionId,
    });
    return ExamDetail.fromJson(
      response.data['exam'] as Map<String, dynamic>,
    );
  }

  Future<void> updateClassTest(
    String examId, {
    String? name,
    String? description,
    DateTime? openAt,
    DateTime? closeAt,
  }) {
    return _client.put(ApiEndpoints.classTestById(examId), data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (openAt != null) 'openAt': openAt.toUtc().toIso8601String(),
      if (closeAt != null) 'closeAt': closeAt.toUtc().toIso8601String(),
    });
  }

  Future<void> updateClassTestQuestions(
    String examId,
    List<String> questionIds,
  ) {
    return _client.put(
      ApiEndpoints.classTestQuestions(examId),
      data: {'questionIds': questionIds},
    );
  }

  Future<void> updateClassTestStatus(
    String examId,
    String action, {
    String? note,
  }) {
    return _client.patch(ApiEndpoints.classTestStatus(examId), data: {
      'action': action,
      if (note != null) 'note': note,
    });
  }

  Future<void> deleteClassTest(String examId) {
    return _client.delete(ApiEndpoints.classTestById(examId));
  }
}
