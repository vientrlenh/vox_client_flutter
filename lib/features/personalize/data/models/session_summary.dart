/// Everything shown on the "Tổng kết buổi nói" screen.
class SessionSummary {
  final String sessionId;
  final String topicTitle;
  final int minutes;
  final double score;

  /// Difference against the previous session, e.g. `+0.4`.
  final double? delta;
  final List<SessionRubricCriterion> rubric;
  final List<RepeatedError> repeatedErrors;

  /// Từ phát âm chưa đạt trong buổi, đã gộp và xếp từ sai nặng nhất.
  final List<MispronouncedWord> mispronounced;

  /// Estimated minutes for the "Luyện lại N lỗi này" drill.
  final int drillMinutes;

  /// Số câu đã nói nhưng chưa có bản chấm. > 0 nghĩa là kết quả còn đang được tổng hợp:
  /// chấm chạy bất đồng bộ và về sau khi phiên đã đóng vài chục giây.
  final int pendingEvaluations;

  /// Trung bình độ khó các câu đã trả lời. null khi chưa có câu nào.
  ///
  /// Hiện cạnh điểm vì điểm MỘT MÌNH không đọc được: nó neo vào bậc mục tiêu, còn độ khó câu
  /// lại bám theo bậc hiện tại của học sinh. Em giỏi lên thì câu khó lên và điểm đứng yên —
  /// "6,5 ở bậc 3" và "6,5 ở bậc 4" là hai chuyện khác hẳn.
  final double? difficultyRank;

  /// Thang chấm của CHÍNH phiên này. Từ V13 phiên luyện là 0-100; phiên cũ theo thang rubric
  /// đã áp lúc đó (0-10, hoặc 5-10...).
  ///
  /// Phải đọc từ backend chứ không viết cứng: trước 2026-08-07 màn tổng kết in " / 100" và
  /// chia thanh tỉ lệ cho 100, trong khi dữ liệu là 0-10 -- ra "7.8 / 100" và năm thanh gần
  /// như trống. Hai loại phiên còn cùng tồn tại lâu dài nên không có mẫu số nào đúng cho cả hai.
  final double scoreScaleMin;
  final double scoreScaleMax;

  const SessionSummary({
    required this.sessionId,
    required this.topicTitle,
    required this.minutes,
    required this.score,
    required this.delta,
    this.rubric = const [],
    this.repeatedErrors = const [],
    this.mispronounced = const [],
    this.drillMinutes = 4,
    this.pendingEvaluations = 0,
    this.scoreScaleMin = 0,
    this.scoreScaleMax = 100,
    this.difficultyRank,
  });

  bool get stillGrading => pendingEvaluations > 0;

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['sessionId'] as String,
      topicTitle: json['topicTitle'] as String,
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      delta: (json['delta'] as num?)?.toDouble() ?? 0,
      rubric: (json['rubric'] as List<dynamic>? ?? const [])
          .map(
            (e) => SessionRubricCriterion.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      repeatedErrors: (json['repeatedErrors'] as List<dynamic>? ?? const [])
          .map((e) => RepeatedError.fromJson(e as Map<String, dynamic>))
          .toList(),
      drillMinutes: (json['drillMinutes'] as num?)?.toInt() ?? 4,
    );
  }
}

/// How a repeated error trended within the session.
class SessionRubricCriterion {
  final String label;
  final double score;

  const SessionRubricCriterion({required this.label, required this.score});

  factory SessionRubricCriterion.fromJson(Map<String, dynamic> json) =>
      SessionRubricCriterion(
        label: json['label'] as String,
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}

/// Một từ phát âm chưa đạt trong buổi, kèm âm vị yếu nhất của nó.
///
/// Gộp theo TỪ trên cả buổi chứ không tách theo từng câu: mở tổng kết ra là muốn biết "buổi
/// này mình hay sai âm gì", chứ không phải lần theo từng câu để tự cộng lại.
class MispronouncedWord {
  final String word;
  final double accuracy;

  /// Âm vị kém nhất trong từ — đây chính là "sai ở chỗ nào". Null khi Azure không trả
  /// chi tiết âm vị cho từ đó.
  final String? worstPhoneme;
  final double? worstPhonemeAccuracy;

  /// Số lần từ này bị chấm dưới ngưỡng trong buổi.
  final int times;

  const MispronouncedWord({
    required this.word,
    required this.accuracy,
    this.worstPhoneme,
    this.worstPhonemeAccuracy,
    this.times = 1,
  });
}

/// One row of "LỖI LẶP LẠI TRONG BUỔI".
///
/// [examples] là các lỗi THẬT đã ghi trong buổi, không phải chỉ con số. Bản trước chỉ đếm
/// `category` rồi vứt hết phần còn lại, nên màn tổng kết ghi "ngữ pháp ×3" mà không nói được
/// sai ở đâu -- một con số như vậy không sửa được gì: học sinh biết mình sai ngữ pháp ba lần
/// nhưng không biết ba lần đó là câu nào.
class RepeatedError {
  final String label;
  final int count;
  final List<SessionCorrection> examples;

  const RepeatedError({
    required this.label,
    required this.count,
    this.examples = const [],
  });

  factory RepeatedError.fromJson(Map<String, dynamic> json) {
    return RepeatedError(
      label: json['label'] as String,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Một lỗi cụ thể đã được sửa trong buổi: em nói gì, đúng phải là gì, vì sao.
///
/// Cả ba trường này GraphQL vốn đã trả về theo từng lượt (`corrections { category
/// originalText correctedText explanation }`) -- không cần thêm truy vấn hay bảng nào.
class SessionCorrection {
  final String category;
  final String originalText;
  final String correctedText;
  final String explanation;

  const SessionCorrection({
    required this.category,
    required this.originalText,
    required this.correctedText,
    required this.explanation,
  });

  factory SessionCorrection.fromJson(Map<String, dynamic> json) {
    return SessionCorrection(
      category: (json['category'] as String? ?? '').trim(),
      originalText: (json['originalText'] as String? ?? '').trim(),
      correctedText: (json['correctedText'] as String? ?? '').trim(),
      explanation: (json['explanation'] as String? ?? '').trim(),
    );
  }
}
