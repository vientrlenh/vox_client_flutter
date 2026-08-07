/// Một bậc trên thang của khung trường đang dùng (VSTEP 6 bậc, CEFR, IELTS...), để học
/// sinh chọn làm ĐỘ KHÓ cho phiên luyện.
///
/// Thay cho `LearnerBand` cũ. Khác biệt không phải ở kiểu dữ liệu mà ở ý nghĩa: bản cũ trả
/// về "bậc của em" do hệ thống suy ra từ lịch sử chấm — tức lấy độ khó của CÂU HỎI gán
/// thành trình độ của NGƯỜI HỌC. Lớp này chỉ liệt kê các bậc có thật trong khung; không bậc
/// nào được đánh dấu là của học sinh, vì hệ thống không xếp bậc năng lực.
///
/// Không có nhãn CEFR kiểu "B1+" trong dữ liệu — `framework_result_bands` chỉ có `code`
/// (BAC_3), `label` ("Bậc 3") và `description`, nên đừng dựng nhãn CEFR ở client.
class PracticeBandOption {
  final String id;
  final String code;
  final String label;

  /// Mô tả bậc do trường soạn, ví dụ "mô tả được trải nghiệm quen thuộc...". Đây là thứ giúp
  /// học sinh chọn có cơ sở thay vì đoán "Bậc 3 là khó hay dễ".
  final String? description;

  /// Vị trí trên thang, 1 là thấp nhất.
  final int order;

  const PracticeBandOption({
    required this.id,
    required this.code,
    required this.label,
    required this.description,
    required this.order,
  });

  factory PracticeBandOption.fromJson(Map<String, dynamic> json) {
    return PracticeBandOption(
      id: json['id'] as String,
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
      order: (json['order'] as num?)?.toInt() ?? 1,
    );
  }
}
