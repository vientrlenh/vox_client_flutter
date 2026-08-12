// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get profileTitle => 'Hồ sơ';

  @override
  String get defaultUserName => 'Người dùng';

  @override
  String get statusActive => 'Hoạt động';

  @override
  String get roleSystemAdmin => 'Quản trị hệ thống';

  @override
  String get roleSchoolAdmin => 'Quản trị trường';

  @override
  String get roleTeacher => 'Giáo viên';

  @override
  String get roleStudent => 'Học sinh';

  @override
  String get statPracticesDone => 'Bài đã luyện';

  @override
  String get statAverageScore => 'Điểm trung bình';

  @override
  String get statDayStreak => 'Chuỗi ngày';

  @override
  String get sectionAccount => 'Tài khoản';

  @override
  String get sectionSettings => 'Cài đặt';

  @override
  String get menuMyResults => 'Kết quả của tôi';

  @override
  String get menuRecordings => 'Bản ghi âm';

  @override
  String get menuAppeals => 'Khiếu nại & Chấm lại';

  @override
  String get menuLanguage => 'Ngôn ngữ';

  @override
  String get menuNotifications => 'Thông báo';

  @override
  String get menuLogOut => 'Đăng xuất';

  @override
  String get profileLoadError => 'Không thể tải thông tin hồ sơ.';

  @override
  String get chooseLanguage => 'Chọn ngôn ngữ';

  @override
  String get languageEnglish => 'Tiếng Anh';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get navHome => 'Trang chủ';

  @override
  String get navSchedule => 'Lịch';

  @override
  String get navProfile => 'Hồ sơ';

  @override
  String get greetingLateNight => 'Luyện tập khuya nhỉ?';

  @override
  String get greetingMorning => 'Buổi sáng tốt lành';

  @override
  String get greetingAfternoon => 'Chào buổi chiều';

  @override
  String get greetingEvening => 'Chào buổi tối';

  @override
  String get homeContinueLearning => 'Tiếp tục với';

  @override
  String get homeExamsToComplete => 'Bài cần hoàn thành';

  @override
  String get homeNoExamsLeft => 'Không còn bài nào cần hoàn thành';

  @override
  String get homeNoDateSet => 'Chưa có ngày';

  @override
  String get homeNotCompleted => 'Chưa hoàn thành';

  @override
  String get homeSearchLessons => 'Tìm bài học…';

  @override
  String get homeResume => 'Tiếp tục →';

  @override
  String get notificationsTitle => 'Thông báo';

  @override
  String get notificationsMarkAllRead => 'Đánh dấu đã đọc tất cả';

  @override
  String get notificationsGroupNew => 'Mới';

  @override
  String get notificationsGroupEarlier => 'Trước đó';

  @override
  String get scheduleTitle => 'Lịch của bạn';

  @override
  String scheduleLoadError(String error) {
    return 'Không thể tải lịch của bạn.\n$error';
  }

  @override
  String get scheduleRetry => 'Thử lại';

  @override
  String scheduleToday(String date) {
    return 'Hôm nay · $date';
  }

  @override
  String get scheduleNoSessionsToday => 'Không có buổi nào hôm nay.';

  @override
  String scheduleTomorrow(String date) {
    return 'Ngày mai · $date';
  }

  @override
  String get scheduleNoSessionsTomorrow => 'Không có buổi nào ngày mai.';

  @override
  String scheduleOnDate(String weekday, String date) {
    return '$weekday · $date';
  }

  @override
  String get scheduleNoSessionsOnDate => 'Không có buổi nào ngày này.';

  @override
  String get scheduleKindCentralized => 'Kiểm tra tập trung';

  @override
  String get scheduleKindClassTest => 'Kiểm tra trên lớp';

  @override
  String get scheduleTimeUnset => '--:--';

  @override
  String get scheduleJumpToday => 'Hôm nay';

  @override
  String get scheduleLegendHasSession => 'Có buổi kiểm tra';

  @override
  String scheduleRoomLabel(String room) {
    return 'Phòng $room';
  }

  @override
  String get scheduleStatusOpen => 'Đang diễn ra';

  @override
  String get scheduleStatusUpcoming => 'Sắp tới';

  @override
  String get scheduleStatusClosed => 'Đã kết thúc';

  @override
  String get teacherExamClassTestsTab => 'Kiểm tra trên lớp';

  @override
  String get teacherExamCentralizedTab => 'Tập trung';

  @override
  String get teacherExamKindClassTest => 'Kiểm tra trên lớp';

  @override
  String get teacherExamCentralizedSection => 'Kiểm tra tập trung';

  @override
  String get teacherExamNoClassTests => 'Chưa có bài kiểm tra nào.';

  @override
  String get teacherExamNoCentralizedExams =>
      'Bạn chưa được phân công kiểm tra tập trung nào.';

  @override
  String get teacherExamStatusDraft => 'Bản nháp';

  @override
  String get teacherExamStatusScheduled => 'Đã lên lịch';

  @override
  String get teacherExamStatusInProgress => 'Đang diễn ra';

  @override
  String get teacherExamStatusClosed => 'Đã đóng';

  @override
  String get teacherExamStatusResultsPublished => 'Đã công bố kết quả';

  @override
  String get teacherExamStatusCancelled => 'Đã hủy';

  @override
  String get teacherExamActionSchedule => 'Lên lịch';

  @override
  String get teacherExamActionCancel => 'Hủy';

  @override
  String get teacherExamActionStart => 'Bắt đầu';

  @override
  String get teacherExamActionClose => 'Đóng';

  @override
  String get teacherExamActionPublishResults => 'Công bố kết quả';

  @override
  String get classTestUpdateStatusError => 'Không thể cập nhật trạng thái.';

  @override
  String get classTestDeleteTitle => 'Xóa bài kiểm tra?';

  @override
  String classTestDeleteBody(String name) {
    return 'Thao tác này sẽ xóa vĩnh viễn \"$name\".';
  }

  @override
  String get classTestCancel => 'Hủy';

  @override
  String get classTestDelete => 'Xóa';

  @override
  String get classTestDeleteError => 'Không thể xóa bài kiểm tra.';

  @override
  String get classTestOpens => 'Mở lúc';

  @override
  String get classTestCloses => 'Đóng lúc';

  @override
  String get classTestNotSet => 'Chưa đặt';

  @override
  String get classTestActions => 'Hành động';

  @override
  String get classTestNameRequired => 'Tên là bắt buộc.';

  @override
  String get classTestSelectClass => 'Chọn một lớp.';

  @override
  String get classTestSelectQuestion => 'Chọn ít nhất một câu hỏi.';

  @override
  String get classTestSaveError => 'Không thể lưu bài kiểm tra.';

  @override
  String get classTestEditTitle => 'Chỉnh sửa bài kiểm tra';

  @override
  String get classTestNewTitle => 'Bài kiểm tra mới';

  @override
  String get classTestNameLabel => 'Tên';

  @override
  String get classTestDescriptionLabel => 'Mô tả';

  @override
  String get classTestClassLabel => 'Lớp';

  @override
  String get classTestOpensAt => 'Mở lúc';

  @override
  String get classTestClosesAt => 'Đóng lúc';

  @override
  String get classTestQuestions => 'Câu hỏi';

  @override
  String classTestQuestionsSelected(int count) {
    return 'Đã chọn $count';
  }

  @override
  String get classTestSaveButton => 'Lưu';

  @override
  String get classTestCreateButton => 'Tạo bài kiểm tra';

  @override
  String get centralizedExamBlueprint => 'Đề thi mẫu';

  @override
  String get centralizedExamMembers => 'Thành viên';

  @override
  String get centralizedExamNoMembers => 'Chưa có thành viên nào.';

  @override
  String get questionPickerLoadError => 'Không thể tải câu hỏi.';

  @override
  String get questionPickerTitle => 'Chọn câu hỏi';

  @override
  String questionPickerDone(int count) {
    return 'Xong ($count)';
  }

  @override
  String get questionPickerSearchHint => 'Tìm kiếm câu hỏi';

  @override
  String get navPractice => 'Luyện nói';

  @override
  String get pzPreparingQuestions =>
      'Đang chuẩn bị câu hỏi riêng cho chủ đề này…\nMất khoảng 10-20 giây cho lần đầu.';

  @override
  String get pzRetry => 'Thử lại';

  @override
  String get pzLoadError => 'Không thể tải phần ôn luyện cá nhân hoá.';

  @override
  String get pzSeeAll => 'Tất cả';

  @override
  String pzMinutes(int count) {
    return '$count phút';
  }

  @override
  String get pzHomeSessionToday => 'PHIÊN HÔM NAY';

  @override
  String get pzHomePersonalizedBadge => 'CÁ NHÂN HOÁ';

  @override
  String get pzHomeSessionMeta => 'Hội thoại 1-1 với AI';

  @override
  String get pzHomeStartSpeaking => 'Bắt đầu nói';

  @override
  String get pzHomeChangeTopic => 'Đổi chủ đề';

  @override
  String get pzHomeStatSessions => 'Buổi đã nói';

  @override
  String get pzHomeStatAverage => 'Điểm TB';

  @override
  String get pzHomeStatWeeklyGoal => 'Buổi tuần này';

  @override
  String get pzHomeNoTopicYet =>
      'Chưa có gợi ý nào — chọn 1 chủ đề để bắt đầu nhé';

  @override
  String get pzHomeSuggestions => 'Gợi ý cho bạn';

  @override
  String get pzPreparingTopics => 'Đang tìm chủ đề hợp với bạn…';

  @override
  String get pzPreparingHint => 'Lần đầu có thể lâu hơn chút vì đang soạn mới.';

  @override
  String get pzHomePreparingTitle => 'Đang soạn chủ đề riêng cho bạn';

  @override
  String get pzHomePreparingBody =>
      'Hệ thống đang dựa trên bài khảo sát sở thích để soạn chủ đề. Việc này mất khoảng 1 phút — bạn quay lại sau nhé, màn hình sẽ tự hiện khi xong.';

  @override
  String get pzTopicsPreparing => 'AI đang tổng hợp sở thích cho bạn';

  @override
  String get pzTopicsPreparingBody =>
      'Vui lòng đợi trong giây lát. Màn hình sẽ tự hiện chủ đề khi soạn xong.';

  @override
  String get pzTopicsRefresh => 'Tải lại';

  @override
  String get pzTopicsTitle => 'Chủ đề luyện nói';

  @override
  String get pzTopicsSearchHint => 'Tìm chủ đề, kỹ năng…';

  @override
  String get pzTopicsFilterForYou => 'Cho bạn';

  @override
  String get pzTopicsFilterSaved => 'Đã lưu';

  @override
  String get pzTopicsRandom => 'Chọn ngẫu nhiên';

  @override
  String get pzTopicsSave => 'Lưu chủ đề';

  @override
  String get pzTopicsUnsave => 'Bỏ lưu';

  @override
  String get pzTopicsPriority => 'ƯU TIÊN #1';

  @override
  String pzTopicsMatch(int percent) {
    return 'Khớp $percent%';
  }

  @override
  String get pzTopicsSpeakThis => 'Nói chủ đề này';

  @override
  String get pzTopicsOtherSuggestions => 'Gợi ý khác';

  @override
  String get pzTopicsSemanticSection => 'Chủ đề gần nghĩa';

  @override
  String get pzTopicsSemanticLoading => 'Đang tìm thêm chủ đề gần nghĩa…';

  @override
  String get pzTopicsEmpty => 'Chưa có chủ đề nào trong danh sách này.';

  @override
  String get pzTopicsFooterTip =>
      'Danh sách này tự đổi sau mỗi buổi nói — dựa trên chủ đề bạn hào hứng và điểm số gần đây.';

  @override
  String get pzTopicsWhy => 'Vì sao?';

  @override
  String pzSessionSpoken(String spoken, String budget) {
    return 'Đã nói · $spoken / $budget';
  }

  @override
  String pzSessionLive(String time) {
    return 'Đang nói · $time';
  }

  @override
  String pzSessionCorrectNow(int count) {
    return 'SỬA NGAY · $count ĐIỂM';
  }

  @override
  String pzSessionKnownWeakness(int count) {
    return 'Điểm yếu đã biết · lần thứ $count';
  }

  @override
  String get pzSessionHearCorrect => 'Nghe câu đúng';

  @override
  String get pzSessionContinue => 'Tiếp tục';

  @override
  String get pzSessionRecording => 'Đang ghi âm câu trả lời…';

  @override
  String get pzSessionTapToSpeak => 'Bấm mic để trả lời';

  @override
  String get pzSessionThinking => 'Đang nghe bạn nói…';

  @override
  String get pzSessionFinish => 'Kết thúc buổi';

  @override
  String get pzSessionMicBusy =>
      'Micro đang được ứng dụng khác sử dụng (Google Meet, Zoom…). Hãy đóng ứng dụng đó rồi bấm Thử lại.';

  @override
  String get pzSessionMicRetry => 'Thử lại';

  @override
  String get pzSessionMicDenied =>
      'Cần quyền micro để ghi âm câu trả lời của bạn.';

  @override
  String get pzSessionRecordError =>
      'Không bắt đầu ghi âm được. Vui lòng thử lại.';

  @override
  String get pzSessionExitTitle => 'Thoát buổi nói?';

  @override
  String get pzSessionExitBody => 'Tiến trình của buổi này sẽ không được lưu.';

  @override
  String get pzSessionExitStay => 'Nói tiếp';

  @override
  String get pzSessionExitLeave => 'Thoát';

  @override
  String get pzSessionPlaybackUnavailable => 'Chưa có bản ghi âm nào.';

  @override
  String get pzSessionNoSampleAudio => 'Chưa có audio mẫu cho câu này.';

  @override
  String get pzSessionTurnSaveFailed =>
      'Không lưu được lượt trả lời vừa rồi. Vui lòng thử lại.';

  @override
  String get pzSessionEndedQuotaExceeded =>
      'Bạn đã dùng hết hạn mức luyện tập. Buổi luyện đã kết thúc.';

  @override
  String get pzSessionReconnectFailed =>
      'Mất kết nối và không thể kết nối lại. Buổi luyện đã kết thúc.';

  @override
  String get pzSummaryTitle => 'Tổng kết buổi nói';

  @override
  String pzSummaryHeader(String topic, int minutes) {
    return '$topic · $minutes PHÚT';
  }

  @override
  String pzSummaryDelta(String delta) {
    return '$delta so với buổi trước';
  }

  @override
  String get pzSummaryRubric => 'Rubric · 5 tiêu chí';

  @override
  String get pzSummaryRubricLegend => 'trọng số · điểm /10';

  @override
  String get pzSummaryPronunciation => 'Từ phát âm chưa đạt';

  @override
  String get pzSummaryPronunciationEmpty =>
      'Không có từ nào bị chấm dưới ngưỡng trong buổi này.';

  @override
  String pzSummaryWorstPhoneme(String phoneme, String percent) {
    return 'Âm /$phoneme/ · $percent%';
  }

  @override
  String get pzSummaryRepeatedErrors => 'Lỗi lặp lại trong buổi';

  @override
  String pzSummaryDrill(int count, int minutes) {
    return 'Luyện lại $count lỗi này · $minutes phút';
  }

  @override
  String get pzSummaryReplay => 'Nghe lại ghi âm';

  @override
  String get pzLearningProfile => 'Hồ sơ học tập';

  @override
  String get pzLearningProfileHint => 'Điểm trung bình và các buổi gần đây';

  @override
  String get pzHistoryTitle => 'Lịch sử luyện tập';

  @override
  String get pzHistoryEmpty => 'Chưa có phiên luyện tập nào';

  @override
  String get pzOnboardingIntroTitle => 'Cùng dựng hồ sơ nói của bạn';

  @override
  String get pzOnboardingIntroBody =>
      'Trả lời vài câu hỏi nhanh để mỗi buổi luyện đều được chọn riêng cho bạn — đúng trình độ, đúng sở thích, đúng điểm yếu.';

  @override
  String get pzOnboardingIntroStart => 'Bắt đầu';

  @override
  String get pzOnboardingIntroDuration =>
      'Khoảng 3 phút · không có đáp án đúng';

  @override
  String get pzOnboardingQuizTitle => 'Phong cách học của bạn';

  @override
  String pzOnboardingProgress(int current, int total) {
    return '$current/$total';
  }

  @override
  String get pzOnboardingQuizTip =>
      'Không có đáp án đúng — trả lời thật để lộ trình bám đúng bạn.';

  @override
  String get pzOnboardingBack => 'Quay lại';

  @override
  String get pzOnboardingContinue => 'Tiếp tục';

  @override
  String get pzOnboardingSkip => 'Bỏ qua';

  @override
  String get pzOnboardingInterestsTitle => 'Sở thích & mục tiêu';

  @override
  String get pzOnboardingInterestsHeading => 'Bạn muốn nói về điều gì?';

  @override
  String get pzOnboardingInterestsBody =>
      'Chọn ít nhất 3 chủ đề. Mình sẽ lấy đúng những thứ này làm nội dung luyện nói — và tự cập nhật khi bạn nói nhiều hơn về chủ đề khác.';

  @override
  String get pzOnboardingMainGoal => 'Mục tiêu chính';

  @override
  String pzOnboardingContinueWithCount(int count) {
    return 'Tiếp tục · đã chọn $count chủ đề';
  }

  @override
  String get pzOnboardingPickThree => 'Chọn ít nhất 3 chủ đề';

  @override
  String get pzOnboardingProfileHeader => 'HỒ SƠ HỌC TẬP CỦA BẠN';

  @override
  String get pzOnboardingCefr => 'CEFR ước lượng';

  @override
  String get pzOnboardingFlas => 'Thái độ & động lực (FLAS)';

  @override
  String get pzOnboardingRoadmap => 'Lộ trình 4 tuần đề xuất';

  @override
  String get pzOnboardingStartFirst => 'Bắt đầu buổi đầu tiên';

  @override
  String get pzOnboardingRestart => 'Làm lại onboarding luyện nói';

  @override
  String get pzGoalTitle => 'Mục tiêu luyện tập';

  @override
  String get pzGoalExamPrep => 'Luyện thi';

  @override
  String get pzGoalAbilityImprovement => 'Tăng kỹ năng';

  @override
  String get pzGoalUpdateError =>
      'Không thể đổi mục tiêu luyện tập, thử lại nhé';

  @override
  String get pzInterestQuizTitle => 'Khám phá sở thích của bạn';

  @override
  String get pzInterestQuizHeading => 'Trong 3 việc dưới đây…';

  @override
  String get pzInterestQuizBody =>
      'Chọn việc giống mình nhất và việc ít giống mình nhất. Không có đáp án đúng.';

  @override
  String get pzInterestQuizMostLike => 'Giống mình nhất';

  @override
  String get pzInterestQuizLeastLike => 'Ít giống mình nhất';

  @override
  String get pzInterestQuizSubmitError =>
      'Không gửi được câu trả lời, thử lại nhé';
}
