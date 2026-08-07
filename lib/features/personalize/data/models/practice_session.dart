/// Who produced a turn in the conversation.
enum Speaker { ai, student }

/// The kind of issue a correction points at. Drives icon and colour.
enum CorrectionType { grammar, vocabulary, pronunciation, fluency }

/// A live 1-1 speaking session with the AI partner.
///
/// Field names mirror the backend `examItemResponse.turns` shape already used
/// by [ExamItemResponse] so wiring the real API later is a drop-in change.
class PracticeSession {
  final String id;
  final String topicId;
  final String topicTitle;

  /// The scripted conversation. While the backend is missing, the screen
  /// reveals these one turn at a time as the learner records.
  final List<PracticeTurn> turns;

  const PracticeSession({
    required this.id,
    required this.topicId,
    required this.topicTitle,
    this.turns = const [],
  });

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession(
      id: json['id'] as String,
      topicId: json['topicId'] as String,
      topicTitle: json['topicTitle'] as String,
      turns: (json['turns'] as List<dynamic>? ?? const [])
          .map((e) => PracticeTurn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One bubble in the conversation.
class PracticeTurn {
  final String id;
  final int turnOrder;
  final Speaker speaker;
  final String text;

  /// Set for student turns once the AI has graded them, 0..10.
  final double? score;

  /// Character ranges inside [text] to underline, one per issue.
  final List<ErrorSpan> spans;

  /// The correction card rendered under a student turn.
  final List<Correction> corrections;

  /// Server đã chấm xong lượt này chưa.
  ///
  /// KHÁC với `corrections.isNotEmpty`: nói đúng hết cũng được chấm, chỉ là danh sách sửa
  /// rỗng. Không có cờ này thì không phân biệt được "chưa chấm xong" với "chấm rồi, không
  /// có gì sai" -- và thẻ sẽ im lặng ở cả hai trường hợp.
  final bool correctionsArrived;

  const PracticeTurn({
    required this.id,
    required this.turnOrder,
    required this.speaker,
    required this.text,
    this.score,
    this.spans = const [],
    this.corrections = const [],
    this.correctionsArrived = false,
  });

  factory PracticeTurn.fromJson(Map<String, dynamic> json) {
    return PracticeTurn(
      id: json['id'] as String,
      turnOrder: (json['turnOrder'] as num?)?.toInt() ?? 0,
      speaker: _speakerFromJson(json['speaker'] as String?),
      text: json['text'] as String? ?? json['transcript'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      spans: (json['spans'] as List<dynamic>? ?? const [])
          .map((e) => ErrorSpan.fromJson(e as Map<String, dynamic>))
          .toList(),
      corrections: (json['corrections'] as List<dynamic>? ?? const [])
          .map((e) => Correction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Speaker _speakerFromJson(String? value) {
    switch (value) {
      case 'STUDENT':
        return Speaker.student;
      case 'AI':
      default:
        return Speaker.ai;
    }
  }
}

/// A wavy-underlined range inside a student's transcript.
class ErrorSpan {
  final int start;
  final int length;
  final CorrectionType type;

  const ErrorSpan({
    required this.start,
    required this.length,
    required this.type,
  });

  int get end => start + length;

  factory ErrorSpan.fromJson(Map<String, dynamic> json) {
    return ErrorSpan(
      start: (json['start'] as num?)?.toInt() ?? 0,
      length: (json['length'] as num?)?.toInt() ?? 0,
      type: correctionTypeFromJson(json['type'] as String?),
    );
  }
}

/// One row inside the "SỬA NGAY" card.
class Correction {
  final CorrectionType type;

  /// What the learner said. Null for observations with nothing to strike out
  /// (e.g. a hesitation note).
  final String? before;

  /// The suggested replacement. Null for pure observations.
  final String? after;

  /// Headline used when [before]/[after] are absent.
  final String? headline;
  final String note;

  /// Set when this repeats a tracked weakness — renders the "lần thứ N" tag.
  final int? repeatCount;

  /// 0..1 accuracy for pronunciation rows, which show a meter instead.
  final double? accuracy;

  /// Âm vị phát âm kém nhất trong từ, ví dụ `z` -> hiện thành `/z/`.
  final String? worstPhoneme;

  /// Gợi ý NÂNG CẤP cách nói, không phải lỗi sai.
  ///
  /// Cần tách bạch vì cách hiển thị phải khác: câu của học sinh vốn đã đúng, gạch chân đỏ
  /// và gọi là "lỗi" sẽ nói sai điều mà hệ thống muốn truyền đạt.
  final bool isUpgrade;

  const Correction({
    required this.type,
    this.before,
    this.after,
    this.headline,
    required this.note,
    this.repeatCount,
    this.accuracy,
    this.worstPhoneme,
    this.isUpgrade = false,
  });

  factory Correction.fromJson(Map<String, dynamic> json) {
    return Correction(
      type: correctionTypeFromJson(json['type'] as String?),
      before: json['before'] as String?,
      after: json['after'] as String?,
      headline: json['headline'] as String?,
      note: json['note'] as String? ?? '',
      repeatCount: (json['repeatCount'] as num?)?.toInt(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      worstPhoneme: json['worstPhoneme'] as String?,
      isUpgrade: json['isUpgrade'] as bool? ?? false,
    );
  }
}

CorrectionType correctionTypeFromJson(String? value) {
  switch (value) {
    case 'VOCABULARY':
      return CorrectionType.vocabulary;
    case 'PRONUNCIATION':
      return CorrectionType.pronunciation;
    case 'FLUENCY':
      return CorrectionType.fluency;
    case 'GRAMMAR':
    default:
      return CorrectionType.grammar;
  }
}
