import 'models/exam_detail.dart';
import 'models/school_class.dart';
import 'models/teacher_question.dart';
import 'teacher_exam_graphql_api.dart';
import 'teacher_exam_rest_api.dart';

class TeacherExamRepository {
  TeacherExamRepository(this._graphqlApi, this._restApi);

  final TeacherExamGraphQLApi _graphqlApi;
  final TeacherExamRestApi _restApi;

  Future<List<SchoolClass>> getMySchoolClasses(String schoolId) =>
      _graphqlApi.getMySchoolClasses(schoolId);

  Future<List<ExamDetail>> getClassTests({String? schoolClassId}) =>
      _graphqlApi.getClassTests(schoolClassId: schoolClassId);

  Future<List<ExamDetail>> getCentralizedExams({
    required String schoolId,
    required String myUserId,
  }) =>
      _graphqlApi.getCentralizedExams(schoolId: schoolId, myUserId: myUserId);

  Future<ExamDetail> getExamDetail(String id) =>
      _graphqlApi.getExamDetail(id);

  Future<List<TeacherQuestion>> getQuestions({String? keyword}) =>
      _graphqlApi.getQuestions(keyword: keyword);

  Future<ExamDetail> createClassTest({
    required String schoolClassId,
    required String name,
    String? description,
    DateTime? openAt,
    DateTime? closeAt,
    List<String>? questionIds,
    String? existingBlueprintId,
    String? existingBlueprintVersionId,
  }) =>
      _restApi.createClassTest(
        schoolClassId: schoolClassId,
        name: name,
        description: description,
        openAt: openAt,
        closeAt: closeAt,
        questionIds: questionIds,
        existingBlueprintId: existingBlueprintId,
        existingBlueprintVersionId: existingBlueprintVersionId,
      );

  Future<void> updateClassTest(
    String examId, {
    String? name,
    String? description,
    DateTime? openAt,
    DateTime? closeAt,
  }) =>
      _restApi.updateClassTest(
        examId,
        name: name,
        description: description,
        openAt: openAt,
        closeAt: closeAt,
      );

  Future<void> updateClassTestQuestions(
    String examId,
    List<String> questionIds,
  ) =>
      _restApi.updateClassTestQuestions(examId, questionIds);

  Future<void> updateClassTestStatus(String examId, String action, {String? note}) =>
      _restApi.updateClassTestStatus(examId, action, note: note);

  Future<void> deleteClassTest(String examId) =>
      _restApi.deleteClassTest(examId);
}
