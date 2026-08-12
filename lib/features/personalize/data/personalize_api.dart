import '../../../core/network/graphql_client.dart';
import 'models/practice_band_option.dart';

/// Real GraphQL calls backing [PersonalizeRepository] — topic-selection
/// queries plus saved-topics and dashboard stats (`practice-planning.graphqls`).
/// See gói 11 mục 2.6b for the field-by-field mapping this mirrors.
class PersonalizeApi {
  PersonalizeApi(this._client);

  final GraphQLClient _client;

  static const _offerFields = '''
    topicId
    name
    dimension
    savedByMe
    matchPercent
    minutes
    rationale
    reasons
  ''';

  /// Maps to `practiceTopicOffers(excludeTopicIds, round, bucket)`.
  Future<List<Map<String, dynamic>>> getTopicOffers({
    List<String> excludeTopicIds = const [],
    int round = 1,
    String bucket = 'FOR_YOU',
  }) async {
    final data = await _client.query(
      '''
      query PracticeTopicOffers(\$excludeTopicIds: [ID!], \$round: Int, \$bucket: TopicOfferBucket) {
        practiceTopicOffers(excludeTopicIds: \$excludeTopicIds, round: \$round, bucket: \$bucket) {
          $_offerFields
        }
      }
    ''',
      variables: {
        'excludeTopicIds': excludeTopicIds,
        'round': round,
        'bucket': bucket,
      },
    );

    final offers = data['practiceTopicOffers'] as List;
    return offers.cast<Map<String, dynamic>>();
  }

  /// Maps to `mySavedTopics` — topics the learner explicitly saved.
  Future<List<Map<String, dynamic>>> getSavedTopics() async {
    final data = await _client.query('''
      query MySavedTopics {
        mySavedTopics {
          $_offerFields
        }
      }
    ''');

    final topics = data['mySavedTopics'] as List;
    return topics.cast<Map<String, dynamic>>();
  }

  /// Maps to `myPracticeDashboardStats` — `sessionsDone`/`averageScore`/`streakDays`.
  Future<Map<String, dynamic>> getDashboardStats() async {
    final data = await _client.query('''
      query MyPracticeDashboardStats {
        myPracticeDashboardStats {
          sessionsDone
          averageScore
          streakDays
        }
      }
    ''');

    return data['myPracticeDashboardStats'] as Map<String, dynamic>;
  }

  /// Maps to `searchPracticeTopics(keyword)` — full `TopicSearchResult` shape
  /// (`topics` + `canGenerate`), not just the topic list, so callers can
  /// offer "create this topic" the same way the schema intends.
  Future<({List<Map<String, dynamic>> topics, bool canGenerate})> searchTopics(
    String keyword,
  ) async {
    final data = await _client.query(
      '''
      query SearchPracticeTopics(\$keyword: String!) {
        searchPracticeTopics(keyword: \$keyword) {
          topics {
            $_offerFields
          }
          canGenerate
        }
      }
    ''',
      variables: {'keyword': keyword},
    );

    final result = data['searchPracticeTopics'] as Map<String, dynamic>;
    final topics = result['topics'] as List;
    return (
      topics: topics.cast<Map<String, dynamic>>(),
      canGenerate: result['canGenerate'] as bool? ?? false,
    );
  }

  /// Maps to `searchPracticeTopicsSemantic(keyword)` — tìm theo NGỮ NGHĨA.
  ///
  /// Query RIÊNG với [searchTopics] để gọi song song được: đường này phải nhúng từ khoá bằng
  /// OpenAI rồi hỏi Chroma nên chậm hơn hàng chục lần. Trả rỗng khi dịch vụ AI không sẵn sàng --
  /// backend đã nuốt lỗi, nơi gọi chỉ cần coi rỗng là "chưa có gì thêm".
  Future<List<Map<String, dynamic>>> searchTopicsSemantic(String keyword) async {
    final data = await _client.query(
      '''
      query SearchPracticeTopicsSemantic(\$keyword: String!) {
        searchPracticeTopicsSemantic(keyword: \$keyword) {
          $_offerFields
        }
      }
    ''',
      variables: {'keyword': keyword},
    );
    return (data['searchPracticeTopicsSemantic'] as List)
        .cast<Map<String, dynamic>>();
  }

  /// Maps to `generateTopicFromKeyword(keyword)` — full `TopicFromKeywordResult`
  /// shape (`topic` + `outcome`), used when `searchTopics` comes back with
  /// `canGenerate: true` and the learner asks to create the topic.
  Future<({Map<String, dynamic>? topic, String outcome})>
  generateTopicFromKeyword(String keyword) async {
    final data = await _client.query(
      '''
      mutation GenerateTopicFromKeyword(\$keyword: String!) {
        generateTopicFromKeyword(keyword: \$keyword) {
          topic {
            $_offerFields
          }
          outcome
        }
      }
    ''',
      variables: {'keyword': keyword},
    );

    final result = data['generateTopicFromKeyword'] as Map<String, dynamic>;
    return (
      topic: result['topic'] as Map<String, dynamic>?,
      outcome: result['outcome'] as String,
    );
  }

  static const _paperQuestionFields = '''
    questionId
    slot
    questionText
    criterionCode
    subAttribute
    difficultyRank
    minResponseSeconds
    maxResponseSeconds
    suggestedIdeas
  ''';

  static const _paperDraftFields =
      '''
    draftId
    status
    reason
    paper {
      id
      topicId
      origin
      plannedSeconds
      reservedQuotaSeconds
      sessionBudgetSeconds
      questions {
        $_paperQuestionFields
      }
    }
  ''';

  /// Maps to `buildPracticePaper(input)` — builds ONLY the first MAIN question (gói 11 mục 2.2);
  /// later MAIN questions are pushed over the realtime WS during the session, not fetched here.
  ///
  /// Pha 1 của luồng 2 pha: trả về ngay `PracticePaperDraft`. `status=READY` khi kho câu hỏi đã
  /// có sẵn câu phù hợp (đường thường gặp, vài chục ms); `status=PREPARING` khi phải nhờ AI sinh
  /// câu mới (10-20s) -- lúc đó gọi tiếp [practicePaperDraft] để hỏi lại.
  ///
  /// [targetFrameworkBandId] là bậc học sinh chọn ở ô độ khó. Bắt buộc: hệ thống không còn
  /// tự suy ra bậc từ điểm bài chấm nữa, nên không có giá trị nào đúng thay cho học sinh.
  Future<Map<String, dynamic>> buildPracticePaper({
    required String topicId,
    required String targetFrameworkBandId,
    required String origin,
    String? fromSubAttribute,
    List<String>? offeredTopicIds,
    List<String>? previousOfferedTopicIds,
  }) async {
    final data = await _client.query(
      '''
      mutation BuildPracticePaper(\$input: StartPracticeSessionInput!) {
        buildPracticePaper(input: \$input) {
          $_paperDraftFields
        }
      }
    ''',
      variables: {
        'input': {
          'topicId': topicId,
          'targetFrameworkBandId': targetFrameworkBandId,
          'origin': origin,
          'fromSubAttribute': fromSubAttribute,
          'offeredTopicIds': offeredTopicIds,
          'previousOfferedTopicIds': previousOfferedTopicIds,
        },
      },
    );

    return data['buildPracticePaper'] as Map<String, dynamic>;
  }

  /// Pha 2: hỏi lại kết quả dựng đề đã khởi động ở [buildPracticePaper].
  Future<Map<String, dynamic>> practicePaperDraft(String draftId) async {
    final data = await _client.query(
      '''
      query PracticePaperDraft(\$draftId: ID!) {
        practicePaperDraft(draftId: \$draftId) {
          $_paperDraftFields
        }
      }
    ''',
      variables: {'draftId': draftId},
    );

    return data['practicePaperDraft'] as Map<String, dynamic>;
  }

  static const _sessionFields = '''
    id
    paperId
    topicId
    topicName
    origin
    status
    abandonDiagnosis
    overallScore
    gradedSeconds
    startedAt
    endedAt
  ''';

  /// Maps to `startPracticeSession(paperId)` — mints the real session id, which is also the
  /// realtime WebSocket's practiceSessionId (`/realtime/practice-sessions/{id}`).
  Future<Map<String, dynamic>> startPracticeSession(String paperId) async {
    final data = await _client.query(
      '''
      mutation StartPracticeSession(\$paperId: ID!) {
        startPracticeSession(paperId: \$paperId) {
          $_sessionFields
        }
      }
    ''',
      variables: {'paperId': paperId},
    );

    return data['startPracticeSession'] as Map<String, dynamic>;
  }

  /// Maps to `endPracticeSession(input)` — called AFTER the WS practice_end/practice_end_ack
  /// handshake and socket close (gói 11 mục 2.9 điểm 2), never before.
  Future<Map<String, dynamic>> endPracticeSession({
    required String sessionId,
    required int helpRequestCount,
    required int longPauseCount,
  }) async {
    final data = await _client.query(
      '''
      mutation EndPracticeSession(\$input: EndPracticeSessionInput!) {
        endPracticeSession(input: \$input) {
          $_sessionFields
        }
      }
    ''',
      variables: {
        'input': {
          'sessionId': sessionId,
          'helpRequestCount': helpRequestCount,
          'longPauseCount': longPauseCount,
        },
      },
    );

    return data['endPracticeSession'] as Map<String, dynamic>;
  }

  /// Đã làm xong quiz sở thích chưa -- hỏi SERVER, không hỏi máy.
  ///
  /// `quiz_completed_at` là sự thật; cờ trong SharedPreferences chỉ là bộ nhớ đệm của một
  /// thiết bị. Cài lại app, đổi máy, hay xoá dữ liệu ứng dụng là cờ mất, và học sinh bị bắt
  /// làm lại một bài quiz mà server đã có -- làm lại còn ghi đè điểm sở thích đang dùng để
  /// xếp chủ đề.
  Future<bool> isInterestQuizCompleted() async {
    final data = await _client.query('''
      query MyLearnerProfile {
        myLearnerProfile {
          quizCompletedAt
        }
      }
    ''');
    final profile = data['myLearnerProfile'] as Map<String, dynamic>?;
    return (profile?['quizCompletedAt'] as String?)?.isNotEmpty ?? false;
  }

  /// Maps to `myLearnerProfile { goalType }` — current EXAM_PREP/ABILITY_IMPROVEMENT goal.
  Future<String?> getPracticeGoal() async {
    final data = await _client.query('''
      query MyLearnerProfile {
        myLearnerProfile {
          goalType
        }
      }
    ''');

    final profile = data['myLearnerProfile'] as Map<String, dynamic>?;
    return profile?['goalType'] as String?;
  }

  /// Maps to `myPracticeBandOptions` + `myLearnerProfile { targetFrameworkBandCode }`.
  ///
  /// Trả về cả thang bậc của khung đang áp (cho ô chọn độ khó) và mã bậc mục tiêu của
  /// trường (để chọn sẵn một mục thay vì bắt học sinh nhìn danh sách trống).
  Future<({List<PracticeBandOption> options, String? defaultCode})>
      getPracticeBandOptions() async {
    final data = await _client.query('''
      query MyPracticeBandOptions {
        myPracticeBandOptions {
          id
          code
          label
          description
          order
        }
        myLearnerProfile {
          targetFrameworkBandCode
        }
      }
    ''');

    final rows = (data['myPracticeBandOptions'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(PracticeBandOption.fromJson)
        .toList();
    final profile = data['myLearnerProfile'] as Map<String, dynamic>?;
    return (
      options: rows,
      defaultCode: profile?['targetFrameworkBandCode'] as String?,
    );
  }

  /// Maps to `setPracticeGoal(goalType)` — goalType is `EXAM_PREP` or `ABILITY_IMPROVEMENT`.
  Future<String> setPracticeGoal(String goalType) async {
    final data = await _client.query(
      '''
      mutation SetPracticeGoal(\$goalType: PracticeGoalType!) {
        setPracticeGoal(goalType: \$goalType) {
          goalType
        }
      }
    ''',
      variables: {'goalType': goalType},
    );

    final profile = data['setPracticeGoal'] as Map<String, dynamic>;
    return profile['goalType'] as String;
  }

  /// Maps to `interestQuizItems` — forced-choice triplets for the cold-start
  /// interest inventory (AI-generated, diversified per student).
  Future<List<Map<String, dynamic>>> getInterestQuizItems() async {
    final data = await _client.query('''
      query InterestQuizItems {
        interestQuizItems {
          id
          statements
        }
      }
    ''');

    final items = data['interestQuizItems'] as List;
    return items.cast<Map<String, dynamic>>();
  }

  /// Maps to `submitInterestQuiz(input)` — scores the answers into the
  /// student's dimension_interest_score vector server-side.
  Future<Map<String, dynamic>> submitInterestQuiz(
    List<Map<String, dynamic>> answers,
  ) async {
    final data = await _client.query(
      '''
      mutation SubmitInterestQuiz(\$answers: [InterestQuizAnswerInput!]!) {
        submitInterestQuiz(input: {answers: \$answers}) {
          goalType
          quizCompletedAt
        }
      }
    ''',
      variables: {'answers': answers},
    );

    return data['submitInterestQuiz'] as Map<String, dynamic>;
  }

  /// Maps to `saveTopic(topicId)`.
  Future<void> saveTopic(String topicId) async {
    await _client.query(
      '''
      mutation SaveTopic(\$topicId: ID!) {
        saveTopic(topicId: \$topicId)
      }
    ''',
      variables: {'topicId': topicId},
    );
  }

  /// Maps to `unsaveTopic(topicId)`.
  Future<void> unsaveTopic(String topicId) async {
    await _client.query(
      '''
      mutation UnsaveTopic(\$topicId: ID!) {
        unsaveTopic(topicId: \$topicId)
      }
    ''',
      variables: {'topicId': topicId},
    );
  }

  /// Maps to `dismissTopicOffer(topicId)` — học sinh bấm loại một thẻ chủ đề.
  ///
  /// Khác `excludeTopicIds`: cái đó chỉ giấu thẻ trong lượt duyệt hiện tại, còn cái này ghi
  /// tín hiệu sở thích âm 0,15 (bằng mức "bỏ dở vì chán") nên có hiệu lực ở mọi lần mở sau.
  Future<void> dismissTopicOffer(String topicId) async {
    await _client.query(
      '''
      mutation DismissTopicOffer(\$topicId: ID!) {
        dismissTopicOffer(topicId: \$topicId)
      }
    ''',
      variables: {'topicId': topicId},
    );
  }

  /// Maps to `pickRandomTopic`.
  Future<Map<String, dynamic>> pickRandomTopic() async {
    final data = await _client.query('''
      mutation PickRandomTopic {
        pickRandomTopic {
          $_offerFields
        }
      }
    ''');

    return data['pickRandomTopic'] as Map<String, dynamic>;
  }

  // FLAS/self-report onboarding step removed client-side (2026-08-02, no
  // question-generation mechanism ever consumed flsaScore — see
  // onboarding_flow.dart doc comment). The `submitFlsaSelfReport` mutation
  // still exists on the backend if this needs to be re-added later.

  /// Maps to `myPracticeHistory(limit)`.
  Future<List<Map<String, dynamic>>> getPracticeHistory(int limit) async {
    final data = await _client.query(
      '''
      query MyPracticeHistory(\$limit: Int) {
        myPracticeHistory(limit: \$limit) {
          $_sessionFields
        }
      }
    ''',
      variables: {'limit': limit},
    );

    final sessions = data['myPracticeHistory'] as List;
    return sessions.cast<Map<String, dynamic>>();
  }

  /// Bai cua CHINH HOC SINH dang dang nhap -- KHONG phai studentPracticeSessionDetail,
  /// cai do la endpoint cua giao vien (@PreAuthorize hasRole('TEACHER')) nen goi vao se
  /// dinh Access Denied ngay khi hoc sinh bam "Hoan tat".
  Future<Map<String, dynamic>> getPracticeSessionDetail(
    String sessionId,
  ) async {
    final data = await _client.query(
      '''
      query MyPracticeSessionDetail(\$sessionId: ID!) {
        myPracticeSessionDetail(sessionId: \$sessionId) {
          sessionId
          topicName
          startedAt
          durationSeconds
          itemCount
          overallScore
          scoreScaleMin
          scoreScaleMax
          completed
          pendingEvaluationCount
          difficultyRank
          criterionScores { criterionCode score }
          turns {
            turnOrder transcript audioUrl wordFeedbackJson turnScore
            corrections { category originalText correctedText explanation correctAudioUrl }
          }
        }
      }
    ''',
      variables: {'sessionId': sessionId},
    );
    return data['myPracticeSessionDetail'] as Map<String, dynamic>;
  }

  // GỠ 2026-08-06: myPendingTopicSuggestions / respondToTopicSuggestion. Hai thao tác GraphQL
  // này đã bị xoá khỏi schema cùng đường suy chủ đề từ lời học sinh nói.
}
