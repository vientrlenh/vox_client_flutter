import '../../../core/network/graphql_client.dart';
import 'models/exam_detail.dart';
import 'models/school_class.dart';
import 'models/teacher_question.dart';

class TeacherExamGraphQLApi {
  TeacherExamGraphQLApi(this._client);

  final GraphQLClient _client;

  static const String _examFields = '''
    id code name description kind status openAt closeAt schoolClassId
    blueprintId blueprintVersionId
    members { userId role user { fullName } }
  ''';

  Future<List<SchoolClass>> getMySchoolClasses(String schoolId) async {
    final data = await _client.query(
      '''
      query MySchoolClasses(\$schoolId: ID!) {
        mySchoolClasses(schoolId: \$schoolId, status: "ACTIVE") {
          content { id name status }
        }
      }
    ''',
      variables: {'schoolId': schoolId},
    );

    final content =
        (data['mySchoolClasses'] as Map<String, dynamic>)['content'] as List;
    return content
        .map((e) => SchoolClass.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExamDetail>> getClassTests({String? schoolClassId}) async {
    final data = await _client.query(
      '''
      query ClassTests(\$schoolClassId: ID) {
        classTests(schoolClassId: \$schoolClassId, size: 100) {
          content { $_examFields }
        }
      }
    ''',
      variables: {'schoolClassId': schoolClassId},
    );

    final content =
        (data['classTests'] as Map<String, dynamic>)['content'] as List;
    return content
        .map((e) => ExamDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExamDetail>> getCentralizedExams({
    required String schoolId,
    required String myUserId,
  }) async {
    final data = await _client.query(
      '''
      query CentralizedExams(\$schoolId: ID) {
        exams(kind: CENTRALIZED, schoolId: \$schoolId, size: 100) {
          content { $_examFields }
        }
      }
    ''',
      variables: {'schoolId': schoolId},
    );

    final content = (data['exams'] as Map<String, dynamic>)['content'] as List;
    return content
        .map((e) => ExamDetail.fromJson(e as Map<String, dynamic>))
        .where((exam) => exam.members.any((m) => m.userId == myUserId))
        .toList();
  }

  /// All centralized exams in the school, unfiltered by exam-team membership.
  /// Used for the schedule tab, where "my exams" means "exams I proctor",
  /// which is checked separately via [ExamSchedule.proctors].
  Future<List<ExamDetail>> getSchoolCentralizedExams(String schoolId) async {
    final data = await _client.query(
      '''
      query SchoolCentralizedExams(\$schoolId: ID) {
        exams(kind: CENTRALIZED, schoolId: \$schoolId, size: 100) {
          content { $_examFields }
        }
      }
    ''',
      variables: {'schoolId': schoolId},
    );

    final content = (data['exams'] as Map<String, dynamic>)['content'] as List;
    return content
        .map((e) => ExamDetail.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExamDetail> getExamDetail(String id) async {
    final data = await _client.query(
      '''
      query ExamDetail(\$id: ID!) {
        exam(id: \$id) { $_examFields }
      }
    ''',
      variables: {'id': id},
    );

    return ExamDetail.fromJson(data['exam'] as Map<String, dynamic>);
  }

  Future<List<TeacherQuestion>> getQuestions({String? keyword}) async {
    final data = await _client.query(
      '''
      query MyQuestions(\$keyword: String) {
        questions(scope: MINE, keyword: \$keyword, size: 100) {
          content { id code questionText promptText type sharing status }
        }
      }
    ''',
      variables: {'keyword': keyword},
    );

    final content =
        (data['questions'] as Map<String, dynamic>)['content'] as List;
    return content
        .map((e) => TeacherQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
