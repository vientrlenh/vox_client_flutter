/// Một khung đánh giá học sinh chọn TRƯỚC khi chọn bậc.
///
/// [versionId] là bản đã ban hành mới nhất của khung, do server tự chọn — học sinh không phải
/// biết tới khái niệm phiên bản, và client cũng không được tự đoán bản nào mới nhất.
///
/// Vì sao cần chọn khung: hệ thống có thể có nhiều khung cùng ban hành (KNLNNVN 6 bậc, IELTS 9
/// bậc…). Trước đây server tự lấy một khung cho cả hệ, nên hai trường dùng hai khung khác nhau
/// thì một bên nhìn thấy thang của bên kia. Bậc chọn ở màn sau thuộc đúng khung này, và tầng
/// chấm suy khung từ chính bậc đó nên cả chuỗi tự nhất quán.
class PracticeFrameworkOption {
  final String versionId;
  final String code;
  final String name;

  /// Mô tả khung do quản trị soạn — thứ giúp học sinh phân biệt hai khung mà không phải đoán.
  final String? description;

  /// Số bậc của khung. Hiển thị để học sinh biết thang dài bao nhiêu trước khi mở danh sách.
  final int bandCount;

  const PracticeFrameworkOption({
    required this.versionId,
    required this.code,
    required this.name,
    required this.description,
    required this.bandCount,
  });

  factory PracticeFrameworkOption.fromJson(Map<String, dynamic> json) {
    return PracticeFrameworkOption(
      versionId: json['versionId'] as String,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      bandCount: (json['bandCount'] as num?)?.toInt() ?? 0,
    );
  }
}
