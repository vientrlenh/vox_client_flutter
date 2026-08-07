import 'practice_topic.dart';

/// Everything the "Luyện nói" home tab renders in one shot.
///
/// No single GraphQL query returns this shape -- it's assembled in
/// `PersonalizeRepository.getDashboard()` from `myPracticeDashboardStats`,
/// `practiceTopicOffers` and the profile query, each a real call.
class PracticeDashboard {
  final String learnerName;
  final int streakDays;

  /// The top-ranked suggestion, also offered as today's session. Null when
  /// there are no offers yet (brand new student).
  final PracticeTopic? todayTopic;
  final int sessionsDone;
  final double averageScore;

  /// Real count of sessions started this calendar week (`myPracticeHistory`).
  /// No "/N" target shown -- the backend has no concept of a weekly goal.
  final int sessionsThisWeek;

  /// "GỢI Ý CHO BẠN" cards.
  final List<PracticeTopic> suggestions;

  const PracticeDashboard({
    required this.learnerName,
    required this.streakDays,
    this.todayTopic,
    required this.sessionsDone,
    required this.averageScore,
    required this.sessionsThisWeek,
    this.suggestions = const [],
  });
}
