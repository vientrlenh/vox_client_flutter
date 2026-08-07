// FLAS/self-report onboarding question model removed client-side
// (2026-08-02) -- see onboarding_flow.dart doc comment. The backend
// `submitFlsaSelfReport` mutation still exists if this needs to come back.

/// A selectable topic chip on the interests step.
class InterestChoice {
  final String id;
  final String emoji;
  final String label;

  const InterestChoice({
    required this.id,
    required this.emoji,
    required this.label,
  });

  factory InterestChoice.fromJson(Map<String, dynamic> json) {
    return InterestChoice(
      id: json['id'] as String,
      emoji: json['emoji'] as String? ?? '',
      label: json['label'] as String,
    );
  }
}

/// One forced-choice triplet from the real `interestQuizItems` query — 3 short
/// everyday-activity statements, each secretly tagged to a different interest
/// dimension server-side (not exposed to the client).
class InterestQuizItem {
  final String id;
  final List<String> statements;

  const InterestQuizItem({required this.id, required this.statements});

  factory InterestQuizItem.fromJson(Map<String, dynamic> json) {
    return InterestQuizItem(
      id: json['id'] as String,
      statements: (json['statements'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

/// One answered triplet: index (0-2) of the statement that feels most/least
/// like the student. Maps 1:1 to `InterestQuizAnswerInput` on the backend.
class InterestQuizAnswer {
  final String itemId;
  final int mostStatementIndex;
  final int leastStatementIndex;

  const InterestQuizAnswer({
    required this.itemId,
    required this.mostStatementIndex,
    required this.leastStatementIndex,
  });

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'mostStatementIndex': mostStatementIndex,
    'leastStatementIndex': leastStatementIndex,
  };
}

/// One of the main goals the learner picks during onboarding.
class LearningGoal {
  final String id;
  final String title;
  final String subtitle;
  final String icon;

  const LearningGoal({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  factory LearningGoal.fromJson(Map<String, dynamic> json) {
    return LearningGoal(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      icon: json['icon'] as String? ?? 'flag_outlined',
    );
  }
}
