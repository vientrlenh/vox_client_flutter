import '../../../core/network/graphql_client.dart';
import '../../schedule/data/models/exam_schedule.dart';

/// Fetches the current student's CLASS_TEST exams that have no submitted
/// attempt yet (no session, or the latest session is still IN_PROGRESS).
class HomeExamApi {
  HomeExamApi(this._client);

  final GraphQLClient _client;

  Future<List<ExamSchedule>> getIncompleteClassTests({int size = 50}) async {
    final examsData = await _client.query('''
      query MyClassTests(\$size: Int) {
        exams(kind: CLASS_TEST, size: \$size) {
          content { id name description kind status openAt closeAt }
        }
      }
    ''', variables: {'size': size});

    final content = (examsData['exams'] as Map<String, dynamic>)['content'] as List;
    final exams = content
        .map((e) => ExamSchedule.fromJson(e as Map<String, dynamic>))
        .toList();

    final results = await Future.wait(exams.map(_isIncomplete));
    return [
      for (var i = 0; i < exams.length; i++)
        if (results[i]) exams[i],
    ];
  }

  Future<bool> _isIncomplete(ExamSchedule exam) async {
    final data = await _client.query('''
      query MyExamCandidate(\$examId: ID!) {
        examCandidates(examId: \$examId) { sessions { status } }
      }
    ''', variables: {'examId': exam.id});

    final candidates = data['examCandidates'] as List;
    if (candidates.isEmpty) return true;

    final sessions = candidates.first['sessions'] as List;
    return !sessions.any((s) => s['status'] != 'IN_PROGRESS');
  }
}
