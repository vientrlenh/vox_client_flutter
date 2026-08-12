import 'dart:convert';

import '../../../core/network/graphql_client.dart';
import '../../profile/data/profile_api.dart';
import 'models/practice_band_option.dart';
import 'models/onboarding_question.dart';
import 'models/practice_dashboard.dart';
import 'models/practice_history_entry.dart';
import 'models/practice_session.dart';
import 'models/practice_topic.dart';
import 'models/session_summary.dart';
import 'personalize_api.dart';

/// Data source for the personalized-practice feature.
///
/// Every method here is either a real GraphQL call or a documented
/// client-side aggregation of a few real calls (`getDashboard`/`getProgress`)
/// — see each method's doc comment.
class PersonalizeRepository {
  PersonalizeRepository({PersonalizeApi? api, ProfileApi? profileApi})
    : _api = api ?? PersonalizeApi(GraphQLClient()),
      _profileApi = profileApi ?? ProfileApi(GraphQLClient());

  final PersonalizeApi _api;
  final ProfileApi _profileApi;

  /// No single query returns this shape -- assembled from real
  /// `myPracticeDashboardStats`, `practiceTopicOffers` (bucket FOR_YOU) and
  /// `profile { fullName }`. `sessionsThisWeek` is a
  /// real count of `myPracticeHistory` entries since the start of this
  /// calendar week (Monday) -- there's no "weekly goal target" anywhere in
  /// the backend, so no "/N" is shown (see conversation: confirmed no such
  /// field exists rather than guessing a number).
  ///
  /// Trước đây còn một lượt `myWeaknessProfile` nữa, chỉ để dựng dải "Tập trung tuần này".
  /// Bỏ dải đó thì bớt luôn một request tuần tự mỗi lần mở tab.
  /// Ba con số ở đầu trang Hồ sơ: số buổi đã xong, điểm trung bình, chuỗi ngày liên tiếp.
  ///
  /// Gọi thẳng `myPracticeDashboardStats` chứ KHÔNG dùng lại [getDashboard]: hàm kia chạy 4
  /// lượt tuần tự (stats + lô chào + lịch sử + hồ sơ) và một lượt trong đó có thể phải chờ AI
  /// sinh chủ đề -- quá đắt cho một màn chỉ hiển thị 3 số.
  Future<({int sessionsDone, double averageScore, int streakDays})>
      getPracticeStats() async {
    final json = await _api.getDashboardStats();
    return (
      sessionsDone: (json['sessionsDone'] as num?)?.toInt() ?? 0,
      averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0,
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PracticeDashboard> getDashboard() async {
    final stats = await _api.getDashboardStats();
    final offers = await _api.getTopicOffers(bucket: 'FOR_YOU');
    final history = await getPracticeHistory(limit: 50);
    final profile = await _profileApi.getProfile();

    // Trang chủ CŨNG là một lô chào thật: `todayTopic` + 4 `suggestions` đều lấy từ cùng một
    // lượt `practiceTopicOffers`. Học sinh nhìn 5 chủ đề rồi chọn 1 -- 4 chủ đề còn lại là
    // thông tin ÂM, đúng như lô chào ở màn chọn chủ đề.
    //
    // Thiếu đoạn này thì backend nhận offeredTopicIds rỗng và hai thứ cùng hỏng:
    //   1. InterestVectorService không ghi được sự kiện OFFERED_NOT_CHOSEN nào
    //   2. BuildPracticePaperUseCase.resolveOrigin đòi offeredTopicIds.contains(topicId) làm
    //      điều kiện tiên quyết, nên thẻ ε-greedy vào từ đây KHÔNG BAO GIỜ được ghi
    //      origin=EPSILON -- ghi SELECTED là dương giả (tín hiệu 0,95 như học sinh tự chọn),
    //      và van chặn thăm dò không bao giờ đóng vì không phiếu nào mang EPSILON.
    //
    // Đo trên DB 2026-08-05 trước khi sửa: cả 3 phiếu đều có offered_topic_ids_json = [],
    // 0 dòng OFFERED_NOT_CHOSEN, 0 phiếu EPSILON.
    final offered = offers.map(PracticeTopic.fromOffer).toList();
    final offeredIds = [for (final topic in offered) topic.id];
    final topics = [
      for (final topic in offered) topic.copyWith(offeredTopicIds: offeredIds),
    ];
    final now = DateTime.now();
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final sessionsThisWeek = history
        .where(
          (e) => e.startedAt != null && !e.startedAt!.isBefore(startOfWeek),
        )
        .length;

    return PracticeDashboard(
      learnerName: profile.fullName ?? '',
      streakDays: (stats['streakDays'] as num?)?.toInt() ?? 0,
      todayTopic: topics.isEmpty ? null : topics.first,
      sessionsDone: (stats['sessionsDone'] as num?)?.toInt() ?? 0,
      averageScore: (stats['averageScore'] as num?)?.toDouble() ?? 0,
      sessionsThisWeek: sessionsThisWeek,
      suggestions: topics.skip(1).take(4).toList(),
    );
  }

  /// `forYou` maps to the only remaining ranking bucket on `practiceTopicOffers`;
  /// `saved` calls `mySavedTopics`.
  /// [round] và [excludeTopicIds] là đường dẫn của nút "Đổi gợi ý".
  ///
  /// Backend đọc `round >= 2` để nâng tỉ lệ thăm dò ε từ 0,10 lên 0,30 (xem
  /// `ViewPracticeTopicOffersUseCase`), còn `excludeTopicIds` loại thẳng những chủ đề học
  /// sinh vừa từ chối khỏi lô mới. Trước đây client không truyền hai tham số này bao giờ,
  /// nên bấm "đổi" (nếu có) cũng chỉ ra đúng lô cũ — và cơ chế thăm dò kẹt vĩnh viễn ở 0,10.
  ///
  /// Việc bị bỏ qua CŨNG là tín hiệu: chủ đề nằm trong lô mà học sinh không chọn sẽ bị hạ
  /// điểm quan tâm (0,30 lô này / 0,20 lô trước) khi phiên sau đóng lại.
  Future<List<PracticeTopic>> getTopics(
    TopicFilter filter, {
    int round = 1,
    List<String> excludeTopicIds = const [],
  }) async {
    if (filter == TopicFilter.saved) {
      final saved = await _api.getSavedTopics();
      return saved
          .map((json) => PracticeTopic.fromOffer(json, bucket: filter))
          .toList();
    }
    final offers = await _api.getTopicOffers(
      bucket: 'FOR_YOU',
      round: round,
      excludeTopicIds: excludeTopicIds,
    );
    return offers
        .map((json) => PracticeTopic.fromOffer(json, bucket: filter))
        .toList();
  }

  /// Full topic list, unfiltered — used by the search field. `canGenerate`
  /// mirrors `TopicSearchResult.canGenerate` (schema) so the search screen
  /// can offer "create this topic" instead of a plain empty state.
  Future<({List<PracticeTopic> topics, bool canGenerate})> searchTopics(
    String query,
  ) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      final topics = await getTopics(TopicFilter.forYou);
      return (topics: topics, canGenerate: false);
    }
    final result = await _api.searchTopics(keyword);
    return (
      topics: result.topics.map(PracticeTopic.fromOffer).toList(),
      canGenerate: result.canGenerate,
    );
  }

  /// Tìm theo NGỮ NGHĨA — gọi SONG SONG với [searchTopics], không nối tiếp.
  ///
  /// Nuốt mọi lỗi thành danh sách rỗng có chủ đích: đây là nguồn BỔ SUNG. Agents chết thì ô tìm
  /// kiếm vẫn chạy bằng kết quả tìm theo chuỗi, người dùng không thấy lỗi nào — suy giảm êm thay
  /// vì hỏng cả màn hình.
  Future<List<PracticeTopic>> searchTopicsSemantic(String query) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }
    try {
      final rows = await _api.searchTopicsSemantic(keyword);
      return rows.map(PracticeTopic.fromOffer).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Maps to `generateTopicFromKeyword` — called when the learner accepts
  /// the "create this topic" offer surfaced by `canGenerate`. Returns the
  /// created/matched topic, or null if the AI rejected the keyword
  /// (`REJECTED_UNSUITABLE`/`OUT_OF_EXAM_SCOPE`).
  /// Lối C -- học sinh tự gõ từ khoá, tín hiệu mạnh nhất (1.00) nên gắn `KEYWORD`.
  Future<PracticeTopic?> generateTopicFromKeyword(String keyword) async {
    final result = await _api.generateTopicFromKeyword(keyword);
    if (result.topic == null) return null;
    return PracticeTopic.fromOffer(result.topic!, origin: 'KEYWORD');
  }

  // GỠ 2026-08-06: getPendingTopicSuggestions / respondToTopicSuggestion. Cả hai chỉ phục vụ
  // gợi ý suy ra TỪ LỜI HỌC SINH NÓI, đã bỏ ở backend. generateTopicFromKeyword ngay bên trên
  // là đường khác -- học sinh chủ động gõ -- và vẫn chạy.

  /// Bao lâu thì hỏi lại kết quả dựng đề, và bỏ cuộc sau bao lâu. Dựng đề chậm là khi phải
  /// nhờ AI sinh câu mới; pipeline fast bên Python thường xong trong ~5-8s nên 45s là dư
  /// nhưng vẫn đủ ngắn để không treo học sinh vô hạn nếu có sự cố.
  static const _draftPollInterval = Duration(seconds: 2);
  static const _draftTimeout = Duration(seconds: 45);

  /// Builds the first MAIN question + starts a real practice session (gói 11 mục 2.2/2.7b):
  /// `buildPracticePaper` -> `startPracticeSession`. `session.id` is also the realtime
  /// WebSocket's practiceSessionId; `firstQuestion` is the raw `PracticePaperQuestion` JSON,
  /// handed back so the caller can send it as the WS `question_start` payload.
  ///
  /// `buildPracticePaper` giờ là 2 pha (xem `PracticePaperDraft` phía backend): trả về ngay,
  /// nếu còn PREPARING thì hỏi lại cho tới khi READY/FAILED. [onPreparing] được gọi khi phải
  /// chờ, để UI hiện trạng thái "đang chuẩn bị" thay vì đứng im.
  /// `budgetSeconds` là trần NÓI của cả phiên — nền cho thanh tiến độ "đã nói / ngân sách".
  /// Lấy từ đề vì lượt đầu chưa nộp nên chưa có kết quả nộp lượt nào để lấy con số này ra.
  Future<
    ({
      PracticeSession session,
      Map<String, dynamic> firstQuestion,
      int budgetSeconds,
    })
  >
  startSession(
    PracticeTopic topic, {
    required String targetFrameworkBandId,
    void Function()? onPreparing,
  }) async {
    final paper = await _buildPaper(
      topic,
      targetFrameworkBandId: targetFrameworkBandId,
      onPreparing: onPreparing,
    );
    final questions = (paper['questions'] as List).cast<Map<String, dynamic>>();
    final firstQuestion = questions.first;
    final sessionJson = await _api.startPracticeSession(paper['id'] as String);
    final session = PracticeSession(
      id: sessionJson['id'] as String,
      topicId: (sessionJson['topicId'] as String?) ?? topic.id,
      topicTitle: (sessionJson['topicName'] as String?) ?? topic.title,
      turns: const [],
    );
    return (
      session: session,
      firstQuestion: firstQuestion,
      budgetSeconds: (paper['sessionBudgetSeconds'] as int?) ?? 0,
    );
  }

  /// Chạy luồng dựng đề 2 pha tới khi có đề thật, ném lỗi đọc được nếu backend báo FAILED.
  Future<Map<String, dynamic>> _buildPaper(
    PracticeTopic topic, {
    required String targetFrameworkBandId,
    void Function()? onPreparing,
  }) async {
    // origin đi theo chủ đề (xem PracticeTopic.origin), KHÔNG cứng 'SELECTED': chủ đề do hệ
    // thống bấm hộ ("chọn giúp tôi") mà ghi như học sinh tự chọn là dương giả.
    var draft = await _api.buildPracticePaper(
      topicId: topic.id,
      targetFrameworkBandId: targetFrameworkBandId,
      origin: topic.origin,
      // Lô chào đi kèm chủ đề (xem PracticeTopic.offeredTopicIds): thiếu hai danh sách này
      // thì backend không có gì để ghi tín hiệu ÂM, và hồ sơ sở thích chỉ học được từ chủ đề
      // ĐƯỢC chọn -- mất hẳn một nửa thông tin mà thiết kế đã tính tới.
      offeredTopicIds: topic.offeredTopicIds,
      previousOfferedTopicIds: topic.previousOfferedTopicIds,
    );
    if (draft['status'] == 'READY') {
      return draft['paper'] as Map<String, dynamic>;
    }
    if (draft['status'] == 'FAILED') {
      throw Exception(draft['reason'] ?? 'Không dựng được đề luyện.');
    }

    onPreparing?.call();
    final draftId = draft['draftId'] as String;
    final deadline = DateTime.now().add(_draftTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_draftPollInterval);
      draft = await _api.practicePaperDraft(draftId);
      if (draft['status'] == 'READY') {
        return draft['paper'] as Map<String, dynamic>;
      }
      if (draft['status'] == 'FAILED') {
        throw Exception(draft['reason'] ?? 'Không dựng được đề luyện.');
      }
    }
    throw Exception('Chuẩn bị câu hỏi lâu hơn dự kiến, vui lòng thử lại.');
  }

  /// Maps to `endPracticeSession` — called AFTER the WS practice_end/practice_end_ack
  /// handshake and socket close (gói 11 mục 2.9 điểm 2), never before.
  Future<void> endPracticeSession({
    required String sessionId,
    required int helpRequestCount,
    required int longPauseCount,
  }) {
    return _api.endPracticeSession(
      sessionId: sessionId,
      helpRequestCount: helpRequestCount,
      longPauseCount: longPauseCount,
    );
  }

  /// Maps to `myLearnerProfile { goalType }` — current EXAM_PREP/ABILITY_IMPROVEMENT goal.
  /// Defaults to `ABILITY_IMPROVEMENT` if the learner has never set one (matches the
  /// backend's own default fallback).
  Future<String> getPracticeGoal() async {
    final goal = await _api.getPracticeGoal();
    return goal ?? 'ABILITY_IMPROVEMENT';
  }

  /// Maps to `setPracticeGoal(goalType)` — returns the goal actually persisted.
  Future<String> setPracticeGoal(String goalType) =>
      _api.setPracticeGoal(goalType);

  /// Thang bậc của khung đang áp, cho ô chọn ĐỘ KHÓ trước mỗi phiên, kèm mã bậc mục tiêu
  /// của trường để chọn sẵn một mục.
  ///
  /// Thay cho `getLearnerBand()` cũ. Hệ thống không còn ước lượng "bậc của em" từ lịch sử
  /// chấm nữa — học sinh tự chọn độ khó muốn luyện, mỗi phiên chọn lại.
  Future<({List<PracticeBandOption> options, String? defaultCode})>
      getPracticeBandOptions() => _api.getPracticeBandOptions();

  /// Maps to `interestQuizItems` — real AI-generated forced-choice triplets,
  /// NOT `PersonalizeDemoData` (this is the cold-start interest inventory).
  Future<List<InterestQuizItem>> getInterestQuizItems() async {
    final items = await _api.getInterestQuizItems();
    return items.map(InterestQuizItem.fromJson).toList();
  }

  /// Maps to `submitInterestQuiz` — scores answers into the real
  /// `dimension_interest_score` vector server-side.
  Future<void> submitInterestQuiz(List<InterestQuizAnswer> answers) {
    return _api.submitInterestQuiz(answers.map((a) => a.toJson()).toList());
  }

  Future<SessionSummary> getSessionSummary(String sessionId) async {
    final results = await Future.wait([
      _api.getPracticeSessionDetail(sessionId),
      _api.getPracticeHistory(50),
    ]);
    final detail = results[0] as Map<String, dynamic>;
    final historyRows =
        (results[1] as List<Map<String, dynamic>>)
            .map(PracticeHistoryEntry.fromJson)
            .toList()
          ..sort(
            (a, b) => (a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
    final currentIndex = historyRows.indexWhere(
      (entry) => entry.id == sessionId,
    );
    // KHÔNG `?? 0`: NULL nghĩa là chưa có điểm tổng, không phải được 0 điểm. Xem
    // SessionSummary.score.
    final currentScore = (detail['overallScore'] as num?)?.toDouble();
    final previousScore = currentIndex > 0
        ? historyRows[currentIndex - 1].overallScore
        : null;

    // Giữ NGUYÊN VĂN lỗi, không chỉ đếm: xem chú thích RepeatedError.examples.
    final correctionsByCategory = <String, List<SessionCorrection>>{};
    final mispronounced = <String, MispronouncedWord>{};
    for (final turn in (detail['turns'] as List? ?? const [])) {
      final turnMap = turn as Map<String, dynamic>;
      for (final correction in (turnMap['corrections'] as List? ?? const [])) {
        final row = SessionCorrection.fromJson(
          correction as Map<String, dynamic>,
        );
        if (row.category.isEmpty) continue;
        correctionsByCategory
            .putIfAbsent(row.category, () => <SessionCorrection>[])
            .add(row);
      }
      _collectMispronounced(
        turnMap['wordFeedbackJson'] as String?,
        mispronounced,
      );
    }
    final mispronouncedRows = mispronounced.values.toList()
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return SessionSummary(
      sessionId: detail['sessionId'] as String,
      topicTitle: detail['topicName'] as String? ?? '',
      minutes: ((detail['durationSeconds'] as num?)?.toInt() ?? 0) ~/ 60,
      score: currentScore,
      // Thiếu một trong hai đầu thì không có chênh lệch nào để nói.
      delta: previousScore == null || currentScore == null
          ? null
          : currentScore - previousScore,
      // Thang chấm đọc từ CHÍNH phiên, không viết cứng: phiên từ V13 là 0-100, phiên cũ theo
      // thang rubric đã áp lúc đó. Mặc định 0/100 chỉ để đọc được payload cũ chưa có trường này.
      scoreScaleMin: (detail['scoreScaleMin'] as num?)?.toDouble() ?? 0,
      scoreScaleMax: (detail['scoreScaleMax'] as num?)?.toDouble() ?? 100,
      // GỘP theo tiêu chí. `criterionScores` trả về một dòng cho mỗi (bài chấm × tiêu chí),
      // nên buổi có 2 câu đã chấm sẽ ra 10 dòng và màn hình hiện "Ngữ pháp" hai lần với hai
      // điểm khác nhau -- trong khi nhãn thẻ ghi "5 tiêu chí". Trung bình cộng các câu, cùng
      // cách overall_score được tính (AVG item_score).
      rubric: _averageByCriterion(detail['criterionScores'] as List?),
      repeatedErrors:
          correctionsByCategory.entries
              .map(
                (entry) => RepeatedError(
                  label: _criterionLabel(entry.key),
                  count: entry.value.length,
                  // Bỏ những dòng không có cả câu gốc lẫn câu sửa -- chúng không nói được
                  // "sai ở đâu", để lại chỉ làm loãng thẻ.
                  examples: entry.value
                      .where(
                        (c) =>
                            c.originalText.isNotEmpty ||
                            c.correctedText.isNotEmpty,
                      )
                      .toList(),
                ),
              )
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count)),
      mispronounced: mispronouncedRows,
      pendingEvaluations:
          (detail['pendingEvaluationCount'] as num?)?.toInt() ?? 0,
      difficultyRank: (detail['difficultyRank'] as num?)?.toDouble(),
    );
  }

  /// Trung bình điểm theo từng tiêu chí trên cả buổi, giữ thứ tự gặp đầu tiên.
  static List<SessionRubricCriterion> _averageByCriterion(List? rows) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    for (final row in rows ?? const []) {
      final map = row as Map<String, dynamic>;
      final code = (map['criterionCode'] as String? ?? '').trim();
      if (code.isEmpty) continue;
      sums[code] = (sums[code] ?? 0) + ((map['score'] as num?)?.toDouble() ?? 0);
      counts[code] = (counts[code] ?? 0) + 1;
    }
    return sums.entries
        .map(
          (entry) => SessionRubricCriterion(
            label: _criterionLabel(entry.key),
            score: entry.value / counts[entry.key]!,
          ),
        )
        .toList();
  }

  /// Bóc từ phát âm chưa đạt ra khỏi `wordFeedbackJson` của một lượt, gộp theo TỪ vào [into].
  ///
  /// JSON này là `pronunciation_result` do PronunciationNode bên Python ghi lúc học sinh nói,
  /// đã lưu sẵn ở `practice_response_turn.word_feedback_json` và GraphQL đã trả về cùng mỗi
  /// lượt — trước đây màn tổng kết tải về rồi bỏ không dùng.
  ///
  /// Cùng một từ sai ở nhiều lượt thì giữ lần TỆ NHẤT và đếm số lần: học sinh cần biết mình
  /// hay vấp từ nào, không phải xem cùng một từ liệt kê lặp ba dòng.
  static void _collectMispronounced(
    String? json,
    Map<String, MispronouncedWord> into,
  ) {
    if (json == null || json.trim().isEmpty) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    for (final entry in (decoded['words'] as List? ?? const [])) {
      if (entry is! Map<String, dynamic>) continue;
      final word = (entry['word'] as String? ?? '').trim();
      final accuracy = (entry['accuracy_score'] as num?)?.toDouble();
      if (word.isEmpty ||
          accuracy == null ||
          accuracy >= _weakPronunciationScore) {
        continue;
      }

      // Âm vị kém nhất trong từ — "sai ở chỗ nào".
      String? worstPhoneme;
      double? worstAccuracy;
      for (final item in (entry['phonemes'] as List? ?? const [])) {
        if (item is! Map<String, dynamic>) continue;
        final value = (item['accuracy_score'] as num?)?.toDouble();
        if (value == null) continue;
        if (worstAccuracy == null || value < worstAccuracy) {
          worstAccuracy = value;
          worstPhoneme = item['phoneme'] as String?;
        }
      }

      final key = word.toLowerCase();
      final seen = into[key];
      if (seen == null) {
        into[key] = MispronouncedWord(
          word: word,
          accuracy: accuracy,
          worstPhoneme: worstPhoneme,
          worstPhonemeAccuracy: worstAccuracy,
        );
      } else {
        into[key] = MispronouncedWord(
          word: seen.word,
          accuracy: accuracy < seen.accuracy ? accuracy : seen.accuracy,
          worstPhoneme: accuracy < seen.accuracy
              ? worstPhoneme
              : seen.worstPhoneme,
          worstPhonemeAccuracy: accuracy < seen.accuracy
              ? worstAccuracy
              : seen.worstPhonemeAccuracy,
          times: seen.times + 1,
        );
      }
    }
  }

  /// Cùng ngưỡng với `_PRONUNCIATION_WEAK_THRESHOLD` của realtimeCorrectionGraph — thẻ sửa
  /// lúc đang nói và bản tổng kết cuối buổi phải coi cùng một từ là "chưa đạt", không thì
  /// học sinh thấy một từ bị bắt lỗi lúc nói rồi biến mất khỏi tổng kết.
  static const double _weakPronunciationScore = 70.0;

  static String _criterionLabel(String code) {
    switch (code.trim().toUpperCase()) {
      case 'GRAMMAR':
        return 'Ngữ pháp';
      case 'VOCABULARY':
        return 'Từ vựng';
      case 'COHERENCE':
        return 'Mạch lạc';
      case 'FLUENCY':
        return 'Độ trôi chảy';
      case 'PRONUNCIATION':
        return 'Phát âm';
      default:
        if (code.isEmpty) return 'Khác';
        return code
            .replaceAll('_', ' ')
            .toLowerCase()
            .split(' ')
            .map(
              (part) => part.isEmpty
                  ? part
                  : '${part[0].toUpperCase()}${part.substring(1)}',
            )
            .join(' ');
    }
  }

  /// Maps to `saveTopic(topicId)`.
  Future<void> saveTopic(String topicId) => _api.saveTopic(topicId);

  /// Maps to `unsaveTopic(topicId)`.
  Future<void> unsaveTopic(String topicId) => _api.unsaveTopic(topicId);

  /// Maps to `dismissTopicOffer(topicId)` — "không thích chủ đề này".
  Future<void> dismissTopicOffer(String topicId) => _api.dismissTopicOffer(topicId);

  /// Maps to `pickRandomTopic` — lối B "chọn giúp tôi". Gắn `EXPLORATION` để tín hiệu sở
  /// thích ghi 0.60 thay vì 0.95: hệ thống chọn hộ thì không phải học sinh thích chủ đề đó.
  Future<PracticeTopic> pickRandomTopic() async {
    final json = await _api.pickRandomTopic();
    return PracticeTopic.fromOffer(json, origin: 'EXPLORATION');
  }

  /// Maps to `myPracticeHistory(limit)`.
  Future<List<PracticeHistoryEntry>> getPracticeHistory({
    int limit = 20,
  }) async {
    final rows = await _api.getPracticeHistory(limit);
    return rows.map(PracticeHistoryEntry.fromJson).toList();
  }

  /// Server có ghi nhận đã làm xong quiz sở thích không -- xem [PersonalizeApi].
  Future<bool> isInterestQuizCompleted() => _api.isInterestQuizCompleted();
}
