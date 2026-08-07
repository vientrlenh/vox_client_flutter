/// The learner profile produced by onboarding and refreshed after each session.
class LearnerProfile {
  final String cefrLevel;
  final List<String> traits;
  final List<FlasScore> flas;
  final List<RubricCriterion> rubric;
  final List<RoadmapWeek> roadmap;

  const LearnerProfile({
    required this.cefrLevel,
    required this.traits,
    required this.flas,
    required this.rubric,
    required this.roadmap,
  });

  /// Trung bình có trọng số của [rubric], cùng thang 0..100 với từng tiêu chí.
  ///
  /// Thang là 0-100 vì `rubric_criterions.min_score/max_score` của trường là 0-100, và
  /// `final_score`/`item_score`/`overall_score` đều nằm trên thang đó. Chú thích cũ ghi 0..10
  /// và giao diện in "/10" -- nên điểm 62,3 hiện thành "62,3 / 10".
  double get overallScore {
    if (rubric.isEmpty) return 0;
    final totalWeight = rubric.fold<int>(0, (sum, c) => sum + c.weight);
    if (totalWeight == 0) return 0;
    final weighted = rubric.fold<double>(
      0,
      (sum, c) => sum + c.score * c.weight,
    );
    return weighted / totalWeight;
  }

  factory LearnerProfile.fromJson(Map<String, dynamic> json) {
    return LearnerProfile(
      cefrLevel: json['cefrLevel'] as String? ?? '—',
      traits: (json['traits'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      flas: (json['flas'] as List<dynamic>? ?? const [])
          .map((e) => FlasScore.fromJson(e as Map<String, dynamic>))
          .toList(),
      rubric: (json['rubric'] as List<dynamic>? ?? const [])
          .map((e) => RubricCriterion.fromJson(e as Map<String, dynamic>))
          .toList(),
      roadmap: (json['roadmap'] as List<dynamic>? ?? const [])
          .map((e) => RoadmapWeek.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One Foreign Language Anxiety Scale dimension, scored 0..100.
class FlasScore {
  final String label;
  final int value;

  /// `true` when a high [value] is a problem (anxiety) rather than a strength.
  final bool inverted;

  const FlasScore({
    required this.label,
    required this.value,
    this.inverted = false,
  });

  factory FlasScore.fromJson(Map<String, dynamic> json) {
    return FlasScore(
      label: json['label'] as String,
      value: (json['value'] as num?)?.toInt() ?? 0,
      inverted: json['inverted'] as bool? ?? false,
    );
  }
}

/// One of the five speaking-rubric criteria, scored 0..10 with a % weight.
class RubricCriterion {
  final String label;
  final int weight;
  final double score;

  const RubricCriterion({
    required this.label,
    required this.weight,
    required this.score,
  });

  /// Below this the bar turns amber, matching the design.
  bool get isWeak => score < 7.5;

  factory RubricCriterion.fromJson(Map<String, dynamic> json) {
    return RubricCriterion(
      label: json['label'] as String,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// One week of the suggested study plan.
class RoadmapWeek {
  final String badge;
  final String title;

  const RoadmapWeek({required this.badge, required this.title});

  factory RoadmapWeek.fromJson(Map<String, dynamic> json) {
    return RoadmapWeek(
      badge: json['badge'] as String,
      title: json['title'] as String,
    );
  }
}
