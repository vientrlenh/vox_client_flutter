/// One turn within a (possibly multi-turn) answered item.
class ExamItemResponseTurn {
  const ExamItemResponseTurn({
    required this.id,
    required this.turnOrder,
    this.promptText,
    this.audioUrl,
    this.transcript,
    this.durationSeconds,
  });

  final String id;
  final int turnOrder;
  final String? promptText;
  final String? audioUrl;
  final String? transcript;
  final int? durationSeconds;

  factory ExamItemResponseTurn.fromJson(Map<String, dynamic> json) {
    return ExamItemResponseTurn(
      id: json['id'] as String,
      turnOrder: json['turnOrder'] as int,
      promptText: json['promptText'] as String?,
      audioUrl: json['audioUrl'] as String?,
      transcript: json['transcript'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}

/// Audio/transcript detail for one answered item
class ExamItemResponse {
  const ExamItemResponse({
    required this.id,
    required this.audioUrl,
    this.durationSeconds,
    this.transcript,
    this.submittedAt,
    this.turns = const [],
  });

  final String id;
  final String? audioUrl;
  final int? durationSeconds;
  final String? transcript;
  final DateTime? submittedAt;
  final List<ExamItemResponseTurn> turns;

  factory ExamItemResponse.fromJson(Map<String, dynamic> json) {
    final turnsJson = json['turns'] as List? ?? const [];
    return ExamItemResponse(
      id: json['id'] as String,
      audioUrl: json['audioUrl'] as String?,
      durationSeconds: json['durationSeconds'] as int?,
      transcript: json['transcript'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      turns: turnsJson
          .map((e) =>
              ExamItemResponseTurn.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
