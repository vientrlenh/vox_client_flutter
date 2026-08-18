import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:record/record.dart';

import '../../../app/theme.dart';
import '../../../app/widgets.dart';
import '../../../core/network/graphql_client.dart';
import '../../../core/platform/mic_status.dart';
import '../../../l10n/app_localizations.dart';
import '../data/models/practice_session.dart';
import '../data/models/practice_topic.dart';
import '../data/personalize_repository.dart';
import '../data/practice_realtime_client.dart';
import 'correction_card.dart';
import 'personalize_styles.dart';
import 'session_summary_screen.dart';

/// What the mic control is doing right now.
enum _RecorderState { idle, recording, processing }

/// Silence-timeout tuning mirrors WPF's SpeechTurnCoordinator.CaptureAsync
/// (DesktopApp/VoxOralExam/.../Services/ExamFlow/Turn/SpeechTurnCoordinator.cs) --
/// Chỉ còn MỘT mốc: khoảng ân hạn sau `vad_speech_end`, đủ để dung thứ một quãng ngập ngừng
/// giữa câu trước khi thực sự khép lượt.
///
/// Mốc "im lặng ban đầu 8s" (mục 2.8, còn dùng ở luồng THI) đã bỏ khỏi luyện tập: ở đó hỏi
/// xong mà học sinh chưa kịp mở lời là chết lượt và bị hỏi lại ngay. Luyện tập cho phép nghĩ
/// bao lâu tuỳ ý -- lượt chỉ khép sau khi đã thực sự nói.
/// 5s chứ không 3s như bên thi: luyện tập không tính giờ thi, học sinh hay ngập ngừng giữa
/// câu để nghĩ từ. Cắt sớm là chốt lượt khi họ mới nói được nửa ý.
const _kSpeechEndGracePeriod = Duration(seconds: 5);

/// Nghe xong câu hỏi mà im quá chừng này thì tính là MỘT lần khựng.
///
/// Không phải hết giờ: lượt vẫn mở, học sinh nghĩ bao lâu cũng được (xem `_armGracePeriodTimer`).
/// Đây thuần tuý là **đo**, không can thiệp.
///
/// Chọn 10 giây: bên thi cắt lượt ở 8 giây im lặng đầu, nên dưới mốc đó là khoảng nghĩ bình
/// thường ai cũng có. Trên 10 giây mà chưa cất tiếng thì thường là chưa nghĩ ra gì để nói,
/// không phải đang soạn câu. **Hằng số này chưa có nguồn nghiên cứu** -- cần hiệu chỉnh khi
/// có dữ liệu thật.
const _kLongThinkingPause = Duration(seconds: 10);

/// Design `1c` — the live 1-1 speaking session with inline corrections.
///
/// Real realtime backend (gói 11): continuous PCM16 mic streaming over
/// `PracticeRealtimeClient`, server-driven turn/question flow. Click-to-continue —
/// the mic button only mutes/unmutes; advancing to the next prompt (follow-up or a new
/// MAIN question alike) always waits for the student to tap "Tiếp tục" on the correction
/// card. UI/widgets below are unchanged from the original mock on purpose; only the
/// state/data layer is real now.
class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({
    super.key,
    required this.topic,
    required this.targetFrameworkBandId,
  });

  final PracticeTopic topic;

  /// Bậc học sinh chọn ở trang xác nhận ngay trước khi vào phiên -- xem `TopicIntroScreen`.
  final String targetFrameworkBandId;

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen>
    with TickerProviderStateMixin {
  final _repository = PersonalizeRepository();
  final _recorder = AudioRecorder();
  final _realtimeClient = PracticeRealtimeClient();
  final _scrollController = ScrollController();
  final _tts = FlutterTts();

  // Both only run while the mic is live — an idle session should not keep a
  // 60 fps ticker alive.
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<Uint8List>? _audioStreamSub;
  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  Timer? _clock;
  Timer? _turnTimer;

  bool _loading = true;

  /// True khi backend báo PREPARING (đang nhờ AI sinh câu mới cho chủ đề này).
  bool _preparingQuestions = false;
  String? _error;

  /// Trường hết gói subscription -- retry vô nghĩa với lỗi này (khác mọi lỗi tải khác ở [_error]),
  /// nên tách cờ riêng để không hiện nút "Thử lại".
  bool _planLimitExceeded = false;

  /// Lỗi MỞ MICRO -- tách khỏi [_error] có chủ đích.
  ///
  /// [_error] làm cả màn hình thành trang lỗi; nhưng mic hỏng thì phiên vẫn sống, WebSocket vẫn
  /// nối, và người dùng chỉ cần đóng ứng dụng đang giữ mic rồi thử lại. Dựng nguyên trang lỗi ở
  /// đây là vứt bỏ một phiên còn dùng được.
  String? _micError;

  /// Dò micro bị Android BỊT TIẾNG -- xem [_armSilencedMicWatchdog].
  Timer? _silencedMicWatchdog;

  /// Đã leo thang sang nguồn thu của ứng dụng gọi điện chưa -- xem [_recordConfig].
  ///
  /// Một chiều: đã giành thì giữ nguyên tới hết phiên. Tự hạ xuống khi thấy hết bị bịt sẽ làm
  /// chất lượng âm thanh đổi giữa chừng, mà bài chấm thì trải dài cả phiên.
  bool _preferCallAudio = false;

  /// Người dùng đã tự đóng băng cảnh báo micro bị bịt.
  ///
  /// Tôn trọng lựa chọn đó -- có người CHỦ Ý vừa họp vừa mở bài để xem đề. Nhưng đóng không có
  /// nghĩa là đồng ý im mãi: hễ họ bấm nói (xem [_startTalking]) thì cờ này bị gỡ và cảnh báo
  /// hiện lại, vì đó đúng là lúc việc micro bị bịt gây hậu quả.
  bool _micWarningDismissed = false;

  PracticeSession? _session;

  /// Turns revealed so far — grows as real WS events arrive, no scripted list anymore.
  final List<PracticeTurn> _visible = [];
  int _nextTurnOrder = 1;

  _RecorderState _recorderState = _RecorderState.idle;

  /// Mic mute toggle — independent of `_recorderState` (continuous-listen model, see
  /// module docstring): muted just streams silence instead of stopping the connection,
  /// mirrors WPF's ToggleMuteCommand/TurnAudioRecorder.IsMuted.
  /// Mặc định TẮT: push-to-talk nên chỉ mở tiếng trong lúc học sinh giữ nút. Bắt đầu ở
  /// trạng thái mở là mic thu luôn câu hỏi do loa phát ra (xem _startTalking).
  bool _muted = true;

  /// True once speech has been detected for the CURRENT turn (silence-timeout bookkeeping).
  bool _speakingNow = false;
  bool _hasSpokenThisTurn = false;

  /// First `vad_speech_start` / latest `vad_speech_end` for the CURRENT turn — the gap between
  /// them is the actual spoken duration sent as `turn_end.duration_seconds`, which Java uses to
  /// consume the student's PRACTICE quota (see SubmitPracticeTurnUseCase). Reset every time a
  /// new turn starts (mirrors WPF's SpeechTurnCoordinator.CaptureAsync.DurationSeconds).
  DateTime? _speechStartedAt;
  DateTime? _speechEndedAt;

  /// Mốc AI nói xong câu hỏi -- gốc để đo "học sinh nghĩ bao lâu mới cất tiếng".
  ///
  /// Phải tính từ đây chứ không từ lúc câu hỏi được đẩy xuống: khoảng AI đang đọc đề thì
  /// học sinh chưa nghe hết câu hỏi, im lặng lúc đó là bình thường chứ không phải bí.
  DateTime? _promptFinishedAt;

  /// Số lần học sinh bấm "Gợi ý" trong cả phiên.
  ///
  /// Đây là tín hiệu **chủ động**: em tự nói ra rằng em bí. Rõ hơn nhiều so với suy từ điểm.
  int _helpRequestCount = 0;

  /// Số lượt mà học sinh im quá [_kLongThinkingPause] sau khi nghe xong câu hỏi.
  ///
  /// Đếm tối đa một lần mỗi lượt -- muốn đo "có bao nhiêu câu làm em khựng lại", không phải
  /// "im lặng tổng cộng bao lâu".
  int _longPauseCount = 0;
  Timer? _thinkingTimer;

  /// Ý gợi ý cho câu hiện tại (`PracticePaperQuestion.suggestedIdeas`). Rỗng thì nút gợi ý
  /// vẫn bấm được và vẫn đếm là một lần xin trợ giúp -- việc em bí là có thật kể cả khi hệ
  /// thống không có gì hay để mách.
  List<String> _currentIdeas = const [];

  /// Buffered from final_transcript events for the turn currently being answered.
  final StringBuffer _liveTranscript = StringBuffer();

  /// Buffered next prompt, ready for when "Tiếp tục" is tapped -- either the follow-up
  /// prompt (from `decision.next_prompt_text`, arrives fast) or a brand-new MAIN question's
  /// text (from `next_question`, arrives async once Java/LLM resolves it). Null means
  /// "not ready yet" -- CorrectionCard's continue action shows a loading state then.
  String? _pendingPromptText;

  /// Question the student is currently on -- needed to send `resume` after a dropped WS
  /// reconnects (mục 2.4c: "exam có cơ chế reconnect", mirrored here). Updated on the initial
  /// question_start and every subsequent next_question push.
  String? _currentQuestionId;
  bool _reconnecting = false;

  bool _sessionEnded = false;
  bool _endingSession = false;

  /// Distinct from `_sessionEnded` (which only means "UI should show the finish state" and
  /// gets set by `_handleSessionEndedByServer` too): guards `_endSession` so the
  /// `endPracticeSession` mutation still runs exactly once even when the server ended the
  /// session first (budget/quota exhausted) and the student taps "Hoàn tất" afterwards.
  bool _javaSessionClosed = false;

  /// Normalised 0..1 mic level driving the waveform.
  double _level = 0.35;

  /// Tổng số giây học sinh ĐÃ NÓI trong phiên, theo server — cập nhật qua `session_budget`
  /// sau mỗi lượt nộp. Cố ý KHÔNG phải đồng hồ đếm từ lúc mở phiên như trước: quota chỉ trừ
  /// đúng khoảng VAD nghe thấy tiếng, nên lúc AI nói / học sinh nghĩ / chờ chấm đều không
  /// tính. Đồng hồ cũ trông như đang đếm hạn mức mà thật ra không liên quan gì tới hạn mức.
  int _spokenSeconds = 0;

  /// Trần nói của cả phiên (giây): chỗ hẹp hơn giữa hạn mức gói và trần bậc năng lực.
  /// 0 nghĩa là chưa biết — header lùi về nhãn cũ thay vì vẽ một mẫu số bịa.
  int _budgetSeconds = 0;

  /// Phần đang nói của lượt hiện tại, server chưa chốt. Chỉ chạy khi VAD báo có tiếng, đúng
  /// bằng quy tắc server dùng để trừ quota, nên lúc reconcile không nhảy giật.
  int _liveSpokenSeconds = 0;

  bool get _isComplete => _sessionEnded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _silencedMicWatchdog?.cancel();
    _amplitudeSub?.cancel();
    _audioStreamSub?.cancel();
    _eventsSub?.cancel();
    _clock?.cancel();
    _turnTimer?.cancel();
    _thinkingTimer?.cancel();
    _wave.dispose();
    _pulse.dispose();
    _scrollController.dispose();
    _recorder.dispose();
    _realtimeClient.dispose();
    _tts.stop();
    super.dispose();
  }

  /// Actually speaks the AI's turns out loud -- mirrors WPF's
  /// `QuestionPresentationService.HandleSpeakRequested` -> `_avatarSpeaker.SpeakAsync(...)`.
  /// Without this, `speak` events only ever produced a silent text bubble.
  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    _tts.setCompletionHandler(_onAiSpeechDone);
    _tts.setCancelHandler(_onAiSpeechDone);
    _tts.setErrorHandler((_) => _onAiSpeechDone());
  }

  /// The silence-timeout window for the student's response only starts once the AI has
  /// actually finished speaking the prompt -- mirrors WPF pausing `SpeechTurnCoordinator`
  /// while `AvatarSpeakingChanged` is true. Guarded on `recording` so a stray/late
  /// completion (e.g. after the farewell utterance) doesn't arm a timer post-session.
  void _onAiSpeechDone() {
    if (!mounted) return;
    // Chỉ báo cho Python biết cửa sổ phát TTS đã đóng để nó dọn buffer audio của lượt
    // (xem ready_to_answer trong connection.py). KHÔNG hẹn giờ im lặng nữa: học sinh muốn
    // nghĩ bao lâu tuỳ ý, lượt chỉ bắt đầu khi họ bấm giữ nút.
    if (_recorderState == _RecorderState.recording && !_hasSpokenThisTurn) {
      _realtimeClient.send({'type': 'ready_to_answer'});
      _startThinkingWatch();
    }
  }

  /// Bắt đầu đo khoảng nghĩ của lượt này. Chỉ ĐO, không cắt lượt.
  void _startThinkingWatch() {
    _thinkingTimer?.cancel();
    _promptFinishedAt = DateTime.now();
    _thinkingTimer = Timer(_kLongThinkingPause, () {
      // Tới đây mà chưa có vad_speech_start nào cho lượt này -> một lần khựng.
      if (!mounted || _hasSpokenThisTurn) return;
      _longPauseCount++;
    });
  }

  /// Học sinh đã cất tiếng (hoặc lượt kết thúc) -> thôi đo.
  void _stopThinkingWatch() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
    _promptFinishedAt = null;
  }

  static List<String> _ideasFrom(Map<String, dynamic>? question) {
    final raw = question?['suggestedIdeas'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Học sinh bấm "Gợi ý".
  ///
  /// Đếm TRƯỚC khi kiểm có ý nào để hiện hay không: hành vi xin trợ giúp là thứ cần đo, còn
  /// việc hệ thống có sẵn gợi ý hay không là chuyện của hệ thống.
  void _requestHelp() {
    _helpRequestCount++;
    final ideas = _currentIdeas;
    final elapsed = _promptFinishedAt == null
        ? null
        : DateTime.now().difference(_promptFinishedAt!);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gợi ý cho câu này',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              if (ideas.isEmpty)
                const Text(
                  'Câu này chưa có gợi ý sẵn. Cứ nói những gì em nghĩ ra trước đã — '
                  'nói sai vẫn tốt hơn im lặng, và phần chấm sẽ chỉ ra chỗ cần sửa.',
                  style: TextStyle(fontSize: 13.5, height: 1.45),
                )
              else
                for (final idea in ideas) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          idea,
                          style: const TextStyle(fontSize: 13.5, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              if (elapsed != null && elapsed > _kLongThinkingPause) ...[
                const SizedBox(height: 6),
                const Text(
                  'Câu này hơi khó với em phải không? Buổi sau em chọn mức dễ hơn cũng được.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _speakAi(String text, {String? rate}) async {
    if (text.trim().isEmpty) {
      _onAiSpeechDone();
      return;
    }
    await _tts.setSpeechRate(rate == '-20%' ? 0.36 : 0.48);
    await _tts.speak(text);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _planLimitExceeded = false;
    });
    try {
      await _initTts();
      final started = await _repository.startSession(
        widget.topic,
        targetFrameworkBandId: widget.targetFrameworkBandId,
        // Chỉ chạy khi kho chưa có câu phù hợp và AI phải sinh mới -- đổi nhãn để học
        // sinh biết đang chờ cái gì thay vì nhìn spinner trống vài chục giây.
        onPreparing: () {
          if (mounted) setState(() => _preparingQuestions = true);
        },
      );
      if (!mounted) return;
      setState(() {
        _session = started.session;
        _visible.clear();
        _nextTurnOrder = 1;
        // Ngân sách phải có NGAY từ đây: lượt đầu chưa nộp nên chưa có `session_budget` nào
        // từ server, mà học sinh thì đã nhìn thấy header rồi.
        _budgetSeconds = started.budgetSeconds;
        _spokenSeconds = 0;
        _liveSpokenSeconds = 0;
        _currentIdeas = _ideasFrom(started.firstQuestion);
      });
      _eventsSub = _realtimeClient.events.listen(_handleRealtimeEvent);
      _currentQuestionId = started.firstQuestion['questionId']?.toString();
      await _realtimeClient.connect(started.session.id);
      _realtimeClient.send({
        'type': 'question_start',
        'question_id': started.firstQuestion['questionId'],
        'paper_item_id': started.firstQuestion['slot']?.toString(),
        'question': {
          'question_text': started.firstQuestion['questionText'],
          // Sàn/trần: SignalNode bên Python cần SÀN để biết trả lời đã đủ chưa. Câu đầu tiên đi
          // qua đường này chứ không qua `next_question`, nên thiếu ở đây là riêng nó bị đo lệch.
          'min_response_seconds': started.firstQuestion['minResponseSeconds'],
          'max_response_seconds': started.firstQuestion['maxResponseSeconds'],
        },
        'language': 'en-US',
      });
      // Audio must actually be streaming (recorderState == recording) BEFORE the first
      // prompt is presented -- otherwise, if TTS finishes speaking while the mic-permission
      // dialog is still open, _onAiSpeechDone sees recorderState != recording and never arms
      // the silence timer, leaving the first turn waiting forever.
      await _startAudioStream();
      // First prompt of the session has nothing to "continue" from -- present it right
      // away instead of waiting for a tap (mirrors the mock's _leadingAiTurns behaviour).
      _realtimeClient.send({
        'type': 'present_question',
        'prompt_text': started.firstQuestion['questionText'],
      });
      _startClock();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _planLimitExceeded = e is GraphQLException && e.code == 'PLAN_LIMIT_EXCEEDED';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startAudioStream() async {
    final l10n = AppLocalizations.of(context)!;
    if (!await _recorder.hasPermission()) {
      if (mounted) _toast(l10n.pzSessionMicDenied);
      return;
    }
    // startStream MỞ THIẾT BỊ, khác hẳn hasPermission() ở trên vốn chỉ hỏi "đã cấp quyền chưa".
    // Được phép không có nghĩa là thiết bị rảnh: Google Meet / Zoom khi đang chia sẻ màn hình
    // giữ độc quyền micro, và hệ điều hành từ chối ứng dụng thứ hai. Lúc đó hasPermission() vẫn
    // trả true rồi startStream ném PlatformException.
    //
    // Bản cũ không bắt, nên ngoại lệ thoát lên catch của _start() và làm chết luôn hai bước sau
    // nó -- present_question (AI không được yêu cầu đọc câu hỏi) và _startClock(). Phiên mở,
    // WebSocket nối, nhưng bấm nói không có gì xảy ra và người dùng chỉ thấy một chuỗi lỗi thô.
    final Stream<Uint8List> stream;
    try {
      // Dừng luồng cũ trước: đổi cấu hình (xem [_recordConfig]) chỉ có tác dụng khi thiết bị
      // được mở lại từ đầu. Bọc try vì stop() lúc chưa thu là vô hại nhưng không phải bản nào
      // cũng im lặng bỏ qua.
      try {
        await _recorder.stop();
      } on Exception catch (_) {}
      stream = await _recorder.startStream(_recordConfig);
    } on Exception catch (error) {
      if (!mounted) return;
      // Nuốt ngoại lệ có chủ đích để _start() chạy tiếp: phiên vẫn dựng được, chỉ thiếu mic.
      // Người dùng đóng Meet rồi bấm "Thử lại" là vào được, không phải tạo phiên mới.
      setState(() {
        _micError = l10n.pzSessionMicBusy;
        _recorderState = _RecorderState.idle;
      });
      debugPrint('[practice] khong mo duoc micro: $error');
      return;
    }
    _audioStreamSub = stream.listen(_handleAudioChunk);
    if (mounted) setState(() => _micError = null);

    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amplitude) {
          if (!mounted) return;
          setState(() => _level = _normalise(amplitude.current));
        });

    if (!mounted) return;
    _wave.repeat();
    _pulse.repeat(reverse: true);
    // Silence-timeout arms once the AI finishes speaking the first prompt (see
    // _onAiSpeechDone), not immediately -- the student can't answer a question they
    // haven't heard yet.
    setState(() => _recorderState = _RecorderState.recording);
    _armSilencedMicWatchdog();
  }

  /// Bắt ca micro MỞ ĐƯỢC nhưng Android trả về toàn im lặng.
  ///
  /// Hỏi THẲNG hệ điều hành qua `AudioRecordingConfiguration.isClientSilenced` (API 29+, xem
  /// MainActivity.kt) -- đúng cờ `silenced` mà `dumpsys audio` hiển thị. Không suy từ biên độ:
  /// suy thì phải chọn ngưỡng dB, mà ngưỡng nào cũng có máy báo nhầm, và im lặng thật của người
  /// đang nghĩ trông y hệt luồng bị bịt.
  ///
  /// Kiểm ĐỊNH KỲ chứ không một lần: người dùng có thể mở Google Meet GIỮA phiên luyện, lúc đó
  /// micro đang thu bình thường bỗng bị bịt. Ngược lại, thoát Meet ra thì cờ tự tắt và băng cảnh
  /// báo phải biến mất mà không cần bấm gì.
  void _armSilencedMicWatchdog() {
    _silencedMicWatchdog?.cancel();
    // Kiểm NGAY một lần, đừng bắt người dùng chờ hết nhịp đầu: học sinh vừa vào bài mà micro đã
    // bị bịt sẵn thì phải biết trước khi bấm nói lần đầu, không phải sau khi đã nói hụt một câu.
    unawaited(_probeSilencedMic());
    _silencedMicWatchdog =
        Timer.periodic(_silencedMicProbe, (_) => unawaited(_probeSilencedMic()));
  }

  /// Một lượt hỏi hệ điều hành, và dựng/gỡ băng cảnh báo theo kết quả.
  ///
  /// @return true nếu micro ĐANG BỊ BỊT (đã chắc chắn). `false` bao gồm cả trường hợp không kết
  /// luận được -- nơi gọi coi như bình thường và cứ để người dùng nói.
  Future<bool> _probeSilencedMic({bool force = false}) async {
    final silenced = await MicStatus.isSilenced(sampleRate: _kSampleRate);
    if (!mounted || silenced == null) return false;
    // Người dùng đã tự đóng băng cảnh báo -> im lặng cho tới lần bấm nói kế tiếp (force). Không
    // có chỗ này thì watchdog dựng lại băng sau 3 giây và cái nút đóng thành ra vô nghĩa.
    if (silenced && _micWarningDismissed && !force) return true;
    if (force) _micWarningDismissed = false;
    final l10n = AppLocalizations.of(context)!;
    // Đã giành mà vẫn bị bịt thì lời khuyên "thoát app kia" không còn là bước tiếp theo hữu ích
    // nữa -- phải nói thẳng rằng cách duy nhất còn lại nằm ở phía Google Meet.
    final message = _preferCallAudio
        ? l10n.pzSessionMicClaimFailed
        : l10n.pzSessionMicSilenced;
    // Chỉ đụng vào _micError khi CHÍNH nó là thứ ta đặt, để không xoá mất thông báo của một lỗi
    // khác (mất quyền, thiết bị bận) mà nhánh catch bên _startAudioStream đã dựng.
    if (silenced && _micError != message) {
      setState(() => _micError = message);
    } else if (!silenced && _micSilencedNow(l10n)) {
      setState(() => _micError = null);
    }
    return silenced;
  }

  /// Cấu hình thu âm. Bình thường dùng nguồn mặc định; sau khi người dùng bấm "Giành micro" thì
  /// leo thang lên nguồn của ứng dụng GỌI ĐIỆN.
  ///
  /// Vì sao không dùng nguồn gọi điện ngay từ đầu: `voiceCommunication` bật chuỗi xử lý tín hiệu
  /// của thoại (khử vọng, nén ồn, tự chỉnh gain) và kéo cả máy sang `MODE_IN_COMMUNICATION`.
  /// Nó thay đổi chính thứ mà hệ thống mang đi CHẤM phát âm và độ trôi chảy, nên chỉ đáng đánh
  /// đổi khi lựa chọn còn lại là không thu được gì cả.
  ///
  /// Vì sao nó có thể giành được: giữa hai ứng dụng cùng ở mức ưu tiên "đang thoại", Android xử
  /// cho bên VÀO SAU. Đây đúng là cơ chế khiến cuộc gọi Zalo cướp được micro khi bạn đang họp
  /// Meet. Không có gì bảo đảm -- ứng dụng đặc quyền (trợ lý, trợ năng) vẫn thắng, và một số máy
  /// nhà sản xuất chỉnh khác đi.
  RecordConfig get _recordConfig => RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _kSampleRate,
        numChannels: 1,
        androidConfig: _preferCallAudio
            ? const AndroidRecordConfig(
                audioSource: AndroidAudioSource.voiceCommunication,
                audioManagerMode: AudioManagerMode.modeInCommunication,
              )
            : const AndroidRecordConfig(),
      );

  /// Băng đang hiển thị có phải là cảnh báo BỊ BỊT TIẾNG không (khác với mic bận / mất quyền).
  ///
  /// So theo nội dung vì `_micError` là một chuỗi dùng chung cho mọi loại lỗi micro; hai thông
  /// điệp này là những chuỗi duy nhất do [_probeSilencedMic] đặt.
  bool _micSilencedNow(AppLocalizations l10n) =>
      _micError == l10n.pzSessionMicSilenced ||
      _micError == l10n.pzSessionMicClaimFailed;

  /// Mở lại micro ở mức ưu tiên cao hơn -- nút "Giành micro" trên băng cảnh báo.
  ///
  /// Không hứa hẹn gì: nếu vẫn thua, watchdog sẽ đổi băng sang [pzSessionMicClaimFailed] trong
  /// vòng một nhịp và chỉ đường còn lại (tắt micro bên Meet).
  Future<void> _claimMicrophone() async {
    setState(() {
      _preferCallAudio = true;
      _micWarningDismissed = false;
      _micError = null;
    });
    await _startAudioStream();
    // Chấm ngay kết quả thay vì đợi nhịp watchdog: người vừa bấm một cái nút thì cần biết nó ăn
    // hay không, chứ không phải nhìn màn hình trống ba giây rồi tự đoán.
    if (mounted) await _probeSilencedMic(force: true);
  }


  void _handleAudioChunk(Uint8List chunk) {
    _realtimeClient.sendAudioFrame(_muted ? Uint8List(chunk.length) : chunk);
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      // CHỈ chạy khi VAD đang nghe thấy tiếng -- đúng bằng thứ server trừ quota. Trước đây
      // tick vô điều kiện nên header đếm cả lúc AI nói và lúc học sinh ngồi nghĩ.
      if (!mounted || !_speakingNow) return;
      setState(() => _liveSpokenSeconds++);
    });
  }

  /// Server chốt lại "đã nói / ngân sách" sau mỗi lượt nộp và mỗi câu hỏi mới.
  void _handleSessionBudget(Map<String, dynamic> event) {
    final spoken = (event['spoken_seconds'] as num?)?.round();
    final budget = (event['budget_seconds'] as num?)?.round();
    if (spoken == null || budget == null) return;
    setState(() {
      _spokenSeconds = spoken;
      _budgetSeconds = budget;
      // Phần đếm tại chỗ giờ đã nằm trong con số server -- giữ lại là cộng đúp.
      _liveSpokenSeconds = 0;
    });
  }

  // ── Realtime protocol ────────────────────────────────────────────────────

  void _handleRealtimeEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'speak':
        final text = (event['text'] as String?) ?? '';
        _appendAiTurn(text);
        _speakAi(text, rate: event['rate'] as String?);
      case 'vad_speech_start':
        _handleSpeechStart();
      case 'vad_speech_end':
        _handleSpeechEnd();
      case 'final_transcript':
        final text = event['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          if (_liveTranscript.isNotEmpty) _liveTranscript.write(' ');
          _liveTranscript.write(text.trim());
        }
      case 'decision':
        _handleDecision(event['decision'] as Map<String, dynamic>? ?? const {});
      case 'correction':
        _handleCorrection(event);
      case 'session_budget':
        _handleSessionBudget(event);
      case 'next_question':
        final question = event['question'] as Map<String, dynamic>?;
        _currentQuestionId = question?['questionId']?.toString();
        setState(() {
          _pendingPromptText = question?['questionText'] as String?;
          _currentIdeas = _ideasFrom(question);
        });
      case 'resume_ack':
        _handleResumeAck(event);
      case 'practice_session_ended':
        _handleSessionEndedByServer(event['reason'] as String?);
      case 'connection_closed':
        _handleConnectionDropped();
      case 'error':
        // Surfaced via _toast rather than _error so a mid-session drop doesn't blow away
        // the conversation already rendered.
        if (mounted) {
          _toast('${event['text'] ?? event['type']}');
        }
    }
  }

  void _appendAiTurn(String text) {
    if (text.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      _visible.add(
        PracticeTurn(
          id: 'ai-${_visible.length}',
          turnOrder: _nextTurnOrder,
          speaker: Speaker.ai,
          text: text,
        ),
      );
    });
    _scrollToEnd();
  }

  void _handleSpeechStart() {
    _turnTimer?.cancel();
    _stopThinkingWatch();
    _speakingNow = true;
    _hasSpokenThisTurn = true;
    _speechStartedAt ??= DateTime.now();
    // Barge-in: học sinh cất tiếng lúc AI còn đang nói thì cắt lời AI ngay.
    _tts.stop();
  }

  void _handleSpeechEnd() {
    _speakingNow = false;
    _speechEndedAt = DateTime.now();
    _armGracePeriodTimer();
  }

  /// Sau khi học sinh NGỪNG nói mới đếm ân hạn rồi chốt lượt.
  ///
  /// Cố ý KHÔNG có bộ đếm cho khoảng im lặng TRƯỚC khi học sinh nói: bên thi có
  /// _kInitialSilenceTimeout (8s) nên hỏi xong mà chưa kịp trả lời là chết lượt và bị hỏi
  /// lại ngay. Luyện tập thì học sinh được nghĩ bao lâu tuỳ ý -- lượt chỉ khép lại sau khi
  /// đã thực sự nói.
  void _armGracePeriodTimer() {
    _turnTimer?.cancel();
    _turnTimer = Timer(_kSpeechEndGracePeriod, () {
      if (!_speakingNow) _sendTurnEnd();
    });
  }

  void _sendTurnEnd() {
    if (_recorderState != _RecorderState.recording) return;
    _turnTimer?.cancel();
    final transcript = _liveTranscript.toString();
    _liveTranscript.clear();

    final start = _speechStartedAt;
    final end = _speechEndedAt;
    final durationSeconds = (start != null && end != null && end.isAfter(start))
        ? end.difference(start).inMilliseconds / 1000.0
        : 0.0;
    _speechStartedAt = null;
    _speechEndedAt = null;

    if (!mounted) return;
    setState(() {
      _recorderState = _RecorderState.processing;
      _visible.add(
        PracticeTurn(
          id: 'student-$_nextTurnOrder',
          turnOrder: _nextTurnOrder,
          speaker: Speaker.student,
          text: transcript,
        ),
      );
      _nextTurnOrder++;
    });
    _scrollToEnd();
    _realtimeClient.send({
      'type': 'turn_end',
      'duration_seconds': durationSeconds,
    });
  }

  void _handleDecision(Map<String, dynamic> decision) {
    if (decision['should_continue'] == true) {
      _pendingPromptText = decision['next_prompt_text'] as String?;
    } else {
      _pendingPromptText = null;
    }
  }

  /// Server's reply to `resume` (see `_handleConnectionDropped`) -- mirrors WPF's own
  /// resume_ack handling (RealtimeSessionClient.cs): if a `decision` is attached, Python
  /// finished processing a turn that was still in flight when the connection dropped, so
  /// apply it exactly like a normal `decision` event to keep state consistent.
  void _handleResumeAck(Map<String, dynamic> event) {
    final decision = event['decision'] as Map<String, dynamic>?;
    if (decision != null) {
      _handleDecision(decision);
      if (mounted) setState(() => _recorderState = _RecorderState.idle);
    } else {
      final promptToSpeak = event['prompt_to_speak'] as String?;
      if (promptToSpeak != null && promptToSpeak.trim().isNotEmpty) {
        // Reconnected while idle (nothing was mid-flight) -- the server tells us the prompt
        // that was active; re-send present_question with it exactly like any other
        // transition, which re-triggers TTS + arms the silence timer once it finishes.
        _realtimeClient.send({
          'type': 'present_question',
          'prompt_text': promptToSpeak,
        });
        _hasSpokenThisTurn = false;
        _speakingNow = false;
        _speechStartedAt = null;
        _speechEndedAt = null;
        _stopThinkingWatch();
        if (mounted) setState(() => _recorderState = _RecorderState.recording);
      }
    }
    _reconnecting = false;
  }

  /// An unexpected WS drop mid-session (network blip, not a deliberate exit/server-initiated
  /// end) -- reconnect to the SAME session and tell the server to `resume` from the question
  /// the student was already on, instead of losing progress. Mirrors the explicitly-designed
  /// split from mục 2.4c: transient disconnect resumes, only a deliberate exit ends the session.
  Future<void> _handleConnectionDropped() async {
    if (!mounted || _sessionEnded || _endingSession || _reconnecting) return;
    final session = _session;
    final questionId = _currentQuestionId;
    if (session == null || questionId == null) return;
    _reconnecting = true;
    _turnTimer?.cancel();
    _tts.stop();

    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _realtimeClient.connect(session.id);
        _realtimeClient.send({'type': 'resume', 'question_id': questionId});
        return;
      } catch (_) {
        if (attempt == maxAttempts) break;
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }
    // Couldn't get back on the WS after retrying -- don't leave the student stuck mid-session
    // forever. The server-side heartbeat sweep (PracticeSessionHeartbeatCleanupJob) closes the
    // Java session as stale on its own, so just reflect that locally.
    _reconnecting = false;
    if (!mounted) return;
    _toast(AppLocalizations.of(context)!.pzSessionReconnectFailed);
    setState(() {
      _sessionEnded = true;
      _recorderState = _RecorderState.idle;
    });
  }

  void _handleCorrection(Map<String, dynamic> event) {
    if (!mounted) return;
    final rawCorrections = (event['corrections'] as List?) ?? const [];
    final corrections = rawCorrections
        .cast<Map<String, dynamic>>()
        .map(_correctionFromJson)
        .toList();
    setState(() {
      final index = _visible.lastIndexWhere(
        (t) => t.speaker == Speaker.student,
      );
      if (index != -1) {
        final turn = _visible[index];
        _visible[index] = PracticeTurn(
          id: turn.id,
          turnOrder: turn.turnOrder,
          speaker: turn.speaker,
          text: turn.text,
          score: turn.score,
          spans: _spansFor(turn.text, corrections),
          corrections: corrections,
          // Đánh dấu ĐÃ CHẤM kể cả khi danh sách sửa rỗng -- thẻ vẫn phải hiện để nói
          // "tốt, không có gì sửa" hoặc "lượt này chưa nói gì".
          correctionsArrived: true,
        );
      }
      _recorderState = _RecorderState.idle;
    });
    _scrollToEnd();
  }

  /// Định vị từng chỗ được sửa trong transcript để gạch chân sóng ngay trong bong bóng.
  ///
  /// Server không gửi vị trí ký tự -- nó chỉ nói "chỗ này sai" bằng chính đoạn văn bản
  /// (`original_text`), nên client phải tự dò. Dò KHÔNG phân biệt hoa thường vì bộ nhận
  /// dạng giọng nói viết hoa đầu câu còn LLM thì trả lại nguyên dạng nó đọc được.
  ///
  /// Mỗi chỗ chỉ khớp MỘT lần và không cho chồng lấn: một từ dính hai lỗi thì hai đường gạch
  /// đè lên nhau, nhìn thành một vệt dày khó hiểu.
  List<ErrorSpan> _spansFor(String text, List<Correction> corrections) {
    if (text.isEmpty) return const [];
    final lower = text.toLowerCase();
    final taken = <int, int>{};
    final spans = <ErrorSpan>[];
    for (final correction in corrections) {
      final needle = correction.before?.trim();
      if (needle == null || needle.isEmpty) continue;
      var from = 0;
      while (true) {
        final at = lower.indexOf(needle.toLowerCase(), from);
        if (at < 0) break;
        final end = at + needle.length;
        final overlaps = taken.entries.any((e) => at < e.value && end > e.key);
        if (!overlaps) {
          taken[at] = end;
          spans.add(
            ErrorSpan(start: at, length: needle.length, type: correction.type),
          );
          break;
        }
        from = at + 1;
      }
    }
    spans.sort((a, b) => a.start.compareTo(b.start));
    return spans;
  }

  Correction _correctionFromJson(Map<String, dynamic> json) {
    final type = _correctionTypeFromCategory(json['category'] as String?);
    final word = json['original_text'] as String?;
    final phoneme = json['worst_phoneme'] as String?;
    // Server trả accuracy thang 0..100 (Azure), model dùng 0..1 cho thanh đo.
    final rawAccuracy = (json['accuracy'] as num?)?.toDouble();

    // Dòng phát âm KHÔNG dùng dạng "trước → sau": từ viết đúng, chỉ đọc chưa chuẩn, nên
    // mũi tên sẽ trỏ từ chính nó vào chính nó. Dựng thành một tiêu đề chỉ rõ âm sai.
    if (type == CorrectionType.pronunciation) {
      return Correction(
        type: type,
        // `before` có giá trị để _spansFor gạch chân được từ đó trong bong bóng, nhưng
        // `after` để trống -- _CorrectionRow chỉ vẽ dạng "trước → sau" khi có ĐỦ cả hai,
        // nên dòng này rơi về `headline`, đúng ý: từ viết không sai, chỉ đọc chưa chuẩn.
        before: word,
        headline: phoneme != null && phoneme.isNotEmpty
            ? '"$word" — âm /$phoneme/ chưa rõ'
            : '"$word" — phát âm chưa rõ',
        note: (json['explanation'] as String?) ?? '',
        accuracy: rawAccuracy == null ? null : rawAccuracy / 100.0,
        worstPhoneme: phoneme,
      );
    }

    return Correction(
      type: type,
      before: word,
      after: json['corrected_text'] as String?,
      note: (json['explanation'] as String?) ?? '',
      isUpgrade: json['is_upgrade'] as bool? ?? false,
    );
  }

  CorrectionType _correctionTypeFromCategory(String? category) {
    switch (category) {
      case 'vocabulary':
        return CorrectionType.vocabulary;
      case 'pronunciation':
        return CorrectionType.pronunciation;
      case 'fluency':
        return CorrectionType.fluency;
      default:
        return CorrectionType.grammar;
    }
  }

  /// Footer action of the (relabelled) CorrectionCard — the ONE new user action in this
  /// screen (mục 2.7b): advance to whatever's next (follow-up or a new MAIN question
  /// alike, same handling either way), only once it's actually buffered.
  Future<void> _handleContinue() async {
    final promptText = _pendingPromptText;
    if (promptText == null) {
      // Still resolving (bậc 4 / LLM taking a moment) -- CorrectionCard shows a loading
      // state for this tap instead of doing nothing silently, see correction_card.dart.
      return;
    }
    _pendingPromptText = null;
    _realtimeClient.send({
      'type': 'present_question',
      'prompt_text': promptText,
    });
    _hasSpokenThisTurn = false;
    _speakingNow = false;
    _speechStartedAt = null;
    _speechEndedAt = null;
    _stopThinkingWatch();
    if (!mounted) return;
    // Silence-timeout arms once the AI finishes speaking this prompt (see
    // _onAiSpeechDone), not immediately.
    setState(() => _recorderState = _RecorderState.recording);
  }

  bool get _continueReady => _pendingPromptText != null;

  void _handleSessionEndedByServer(String? reason) {
    _turnTimer?.cancel();
    _tts.stop();
    _audioStreamSub?.cancel();
    _recorder.stop();
    if (!mounted) return;
    // quota_exceeded/failed (submit_turn couldn't save or Java rejected the last turn, see
    // connection.py._after_turn) mean the last turn is unrecoverable -- end the session outright
    // rather than let "Tiếp tục" silently proceed past data loss (mục 2.4c). Tell the student why
    // instead of leaving them guessing.
    final l10n = AppLocalizations.of(context)!;
    if (reason == 'quota_exceeded') {
      _toast(l10n.pzSessionEndedQuotaExceeded);
    } else if (reason == 'failed') {
      _toast(l10n.pzSessionTurnSaveFailed);
    }
    setState(() {
      _sessionEnded = true;
      _recorderState = _RecorderState.idle;
    });
  }

  // ── Mic mute toggle (NOT start/stop recording anymore) ──────────────────

  /// Push-to-talk: chỉ gửi tiếng khi học sinh ĐANG giữ nút.
  ///
  /// Trước đây mic gửi liên tục và `_muted` mặc định false, nên loa phát câu hỏi ra thì mic
  /// thu lại chính giọng AI và đẩy lên server làm câu trả lời. Cơ chế `ready_to_answer` chỉ
  /// dọn buffer SAU khi AI nói xong, không chặn được tiếng lọt vào lúc đang nói.
  ///
  /// Giữ nút = mở tiếng. Thả ra là im ngay, kể cả khi AI đang nói, nên không còn đường nào
  /// để tiếng loa quay ngược vào bản ghi.
  /// Giữ nút = mở mic. Chỉ điều khiển ĐƯỜNG TIẾNG, không quyết định ranh giới lượt nói --
  /// việc đó vẫn do VAD + thời gian ân hạn lo (xem _handleSpeechEnd).
  void _startTalking() {
    if (_recorderState == _RecorderState.processing) return;
    // Chưa ở trạng thái ghi thì KHÔNG có luồng âm thanh nào tồn tại: `_audioStreamSub` chưa được
    // tạo nên `_handleAudioChunk` không bao giờ chạy. Bản trước vẫn đổi cờ `_muted` trong tình
    // huống đó, nên nút bấm được mà tuyệt đối không có gì xảy ra -- người dùng tưởng app đơ.
    if (_recorderState != _RecorderState.recording) {
      _toast(_micError ?? AppLocalizations.of(context)!.pzSessionMicBusy);
      return;
    }
    setState(() => _muted = false);
    // Hỏi lại NGAY tại mỗi lần bấm nói, không đợi nhịp watchdog kế tiếp.
    //
    // Người dùng có quyền bỏ qua băng cảnh báo lúc vào bài -- nhưng nếu họ vẫn bấm nói trong khi
    // micro đang bị bịt thì đó chính là lúc lời cảnh báo có ích nhất, và cũng là lúc nút "Giành
    // micro" phải xuất hiện trở lại. Không chặn việc nói: nếu hệ điều hành trả "không biết" thì
    // cứ để họ nói, chặn nhầm còn tệ hơn.
    unawaited(_probeSilencedMic(force: true));
  }

  void _stopTalking() {
    if (!_muted) setState(() => _muted = true);
  }

  /// dBFS (roughly -45..0) → 0..1.
  /// Tần số thu. Cũng là dấu hiệu nhận ra cấu hình của chính app trong danh sách ghi âm mà
  /// Android trả về (app gọi điện gần như luôn 48 kHz) -- xem MainActivity.isMicSilenced.
  static const int _kSampleRate = 16000;

  /// Nhịp hỏi hệ điều hành xem micro có đang bị bịt không. 3 giây đủ nhanh để người dùng biết
  /// trước khi nói hết một câu, mà vẫn rẻ -- mỗi lượt chỉ là một lời gọi AudioManager.
  static const Duration _silencedMicProbe = Duration(seconds: 3);

  double _normalise(double dbfs) {
    const floor = 45.0;
    return ((dbfs + floor) / floor).clamp(0.05, 1.0);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Navigation / ending the session ──────────────────────────────────────

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    _clock?.cancel();
    await _endSession(clientInitiated: false);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            SessionSummaryScreen(sessionId: session.id),
      ),
    );
  }

  /// Mirrors ExamAttemptRunner.RequestSubmit()'s exact ordering (mục 2.9 điểm 2): WS
  /// practice_end -> await practice_end_ack -> close WS -> THEN endPracticeSession mutation.
  /// clientInitiated=false skips the WS handshake (server already ended the session itself,
  /// e.g. budget_exhausted) and just tidies up + calls the mutation.
  Future<void> _endSession({required bool clientInitiated}) async {
    if (_endingSession || _javaSessionClosed) return;
    _endingSession = true;
    _turnTimer?.cancel();
    await _audioStreamSub?.cancel();
    try {
      await _recorder.stop();
    } catch (_) {
      // Best-effort -- the session is ending either way.
    }

    if (clientInitiated && _realtimeClient.isConnected) {
      final ack = _realtimeClient.events
          .firstWhere((e) => e['type'] == 'practice_end_ack')
          .timeout(const Duration(seconds: 5), onTimeout: () => const {});
      _realtimeClient.send({'type': 'practice_end'});
      await ack;
    }
    await _realtimeClient.close();

    final session = _session;
    if (session != null) {
      try {
        await _repository.endPracticeSession(
          sessionId: session.id,
          // Số đếm THẬT. Trước đây hai con số này gửi cứng 0, khiến
          // SessionDiagnosisPolicy thoái hoá thành ngưỡng điểm thuần: "chán" bị suy ra từ
          // ĐIỂM CAO, còn hai vế hành vi trong luật thì không bao giờ đúng.
          helpRequestCount: _helpRequestCount,
          longPauseCount: _longPauseCount,
        );
      } catch (_) {
        // Ending the local session view must not get stuck on a network hiccup here --
        // the server independently expires stale IN_PROGRESS sessions.
      }
    }
    _javaSessionClosed = true;
    _sessionEnded = true;
  }

  Future<bool> _confirmExit() async {
    if (_visible.every((t) => t.speaker == Speaker.ai)) return true;
    final l10n = AppLocalizations.of(context)!;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pzSessionExitTitle),
        content: Text(l10n.pzSessionExitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.pzSessionExitStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.pzSessionExitLeave),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Thoát phiên. Đã nói được ít nhất một lượt thì ĐI TỚI MÀN TỔNG KẾT, không quay lui.
  ///
  /// Trước đây luôn `pop()`, nên học sinh nói xong bấm thoát là mất luôn phần kết quả --
  /// màn tổng kết chỉ tới được khi SERVER tự kết thúc phiên (hết quota, hoặc lưu lượt hỏng),
  /// tức chỉ ở những đường không ai mong muốn. Nói xong rồi rời đi là đường bình thường
  /// nhất, mà lại là đường duy nhất không xem được mình làm thế nào.
  ///
  /// Chưa nói câu nào thì vẫn quay lui: không có gì để tổng kết, mở ra một màn trống chỉ
  /// khiến học sinh phải bấm thêm một lần nữa để thoát.
  Future<void> _handleExitRequest() async {
    final leave = await _confirmExit();
    if (!mounted || !leave) return;
    final spoke = _visible.any((t) => t.speaker == Speaker.student);
    await _endSession(clientInitiated: true);
    if (!mounted) return;
    if (!spoke) {
      Navigator.of(context).pop();
      return;
    }
    await _finish();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExitRequest();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFCFCFD),
        body: SafeArea(
          child: Column(
            children: [
              _SessionHeader(
                title: widget.topic.title,
                spokenSeconds: _spokenSeconds + _liveSpokenSeconds,
                budgetSeconds: _budgetSeconds,
                onClose: _handleExitRequest,
              ),
              Expanded(child: _buildBody(l10n)),
              if (_micError != null) _buildMicErrorBanner(l10n),
              if (!_loading && _error == null) _buildComposer(l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// Thẻ báo sự cố micro, kèm hành động sửa NGAY TẠI CHỖ.
  ///
  /// Đặt ngay trên thanh soạn để người dùng thấy vì sao bấm nói không ăn.
  ///
  /// Xếp DỌC chứ không dồn một hàng ngang: bản đầu nhét chữ, nút hành động và nút đóng vào cùng
  /// một Row, nên hai cái nút chiếm hết bề ngang và phần chữ bị ép thành một cột hẹp gãy vụn
  /// thành sáu bảy dòng. Tách thành ba tầng -- lời báo, gạch phân cách, hàng nút -- thì chữ
  /// được trọn bề ngang còn nút vẫn nổi.
  Widget _buildMicErrorBanner(AppLocalizations l10n) {
    final silenced = _micSilencedNow(l10n);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.chipOrangeBg,
        borderRadius: BorderRadius.circular(14),
        // Viền cùng tông đậm hơn nền: nền cam rất nhạt (#FFF7ED) gần như trắng, không có viền
        // thì thẻ chìm vào nền trang và trông như chữ rơi vãi chứ không phải một khối cảnh báo.
        border: Border.all(color: AppColors.chipOrangeFg.withValues(alpha: 0.22)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.mic_off_rounded, size: 18, color: AppColors.chipOrangeFg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _micError!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: AppColors.chipOrangeFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Đóng được thẻ: có người CỐ Ý vừa họp vừa mở bài để xem đề, ép họ nhìn cảnh báo
              // mãi là phiền. Bấm nói lần sau nó tự hiện lại (xem [_micWarningDismissed]).
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.chipOrangeFg.withValues(alpha: 0.7),
                  ),
                  onPressed: () => setState(() {
                    _micWarningDismissed = true;
                    _micError = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.chipOrangeFg.withValues(alpha: 0.14),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            // Bị BỊT TIẾNG khác với mở KHÔNG ĐƯỢC, nên hành động gợi ý cũng phải khác: mở lại y
            // hệt cấu hình cũ thì chắc chắn lại bị bịt tiếp.
            //
            // Vẫn mời "Giành micro" cả khi lần trước đã thua: Android xử cho bên mở SAU CÙNG,
            // nên bấm lại vào thời điểm khác hoàn toàn có thể thắng (Meet vừa nhả, người dùng
            // vừa tắt mic bên đó). Chặn lại sau một lần thua là lấy mất của họ đúng cái nút
            // đang cần.
            child: TextButton.icon(
              onPressed: silenced
                  ? () => unawaited(_claimMicrophone())
                  : () => unawaited(_startAudioStream()),
              icon: Icon(
                silenced ? Icons.mic_rounded : Icons.refresh_rounded,
                size: 17,
              ),
              label: Text(
                silenced ? l10n.pzSessionMicClaim : l10n.pzSessionMicRetry,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.chipOrangeFg,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_preparingQuestions) ...[
              const SizedBox(height: 16),
              Text(
                l10n.pzPreparingQuestions,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textFaint,
                ),
              ),
            ],
          ],
        ),
      );
    }
    if (_planLimitExceeded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 32, color: AppColors.textFaint),
              const SizedBox(height: 12),
              Text(
                l10n.pzPlanLimitExceeded,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textFaint,
                ),
              ),
              // Không có nút "Thử lại": lỗi này chỉ hết khi nhà trường gia hạn gói, bấm lại vô ích.
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.pzLoadError}\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textFaint,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: Text(l10n.pzRetry)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      itemCount: _visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final turn = _visible[index];
        if (turn.speaker == Speaker.ai) return _AiBubble(text: turn.text);
        // Real backend always sends a `correction` message after a student turn (even
        // with an empty corrections list) -- show the card (with its now-"Tiếp tục"
        // footer) once that's arrived, not gated on corrections being non-empty like the
        // old scripted mock, or there'd be no way to advance on a clean turn.
        final isLatestStudentTurn =
            index ==
            _visible.lastIndexWhere((t) => t.speaker == Speaker.student);
        // Footer điều hướng chỉ thuộc về lượt mới nhất...
        final showContinue =
            isLatestStudentTurn &&
            _recorderState == _RecorderState.idle &&
            !_sessionEnded;
        // ...còn THẺ SỬA thì mọi lượt đã được chấm đều giữ lại. Trước đây cả thẻ gắn với
        // `showContinue`, nên bấm "Tiếp tục" là phần sửa của những câu trước biến mất khỏi
        // màn hình dù dữ liệu vẫn còn trong _visible -- học sinh không xem lại được.
        final hasCorrectionCard = turn.correctionsArrived;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StudentBubble(turn: turn),
            if (hasCorrectionCard) ...[
              const SizedBox(height: 12),
              CorrectionCard(
                turn: turn,
                showContinue: showContinue,
                onContinue: _handleContinue,
                continueReady: _continueReady,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildComposer(AppLocalizations l10n) {
    if (_isComplete) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
        child: GradientButton(
          label: l10n.pzSessionFinish,
          icon: Icons.arrow_forward,
          onTap: _finish,
        ),
      );
    }

    final recording = _recorderState == _RecorderState.recording && !_muted;
    final processing = _recorderState == _RecorderState.processing;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Nút KẾT THÚC & xem kết quả. Chỗ này trước là một hình tròn `more_horiz` chết,
          // không gắn hành động nào -- nên trong lúc luyện học sinh không có cách nào chủ
          // động nộp bài, phải chờ server tự kết thúc phiên mới thấy được kết quả.
          Semantics(
            button: true,
            label: 'Kết thúc phiên và xem kết quả',
            child: GestureDetector(
              onTap: processing ? null : _handleExitRequest,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: processing ? AppColors.fieldBg : AppColors.chipBlueBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 21,
                  color: processing ? AppColors.textGhost : AppColors.indigo,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (recording)
                    SizedBox(
                      height: 24,
                      child: AnimatedBuilder(
                        animation: _wave,
                        builder: (_, _) => CustomPaint(
                          size: const Size(double.infinity, 24),
                          painter: WaveformPainter(
                            _wave.value,
                            level: _level,
                            bars: 16,
                            colors: const [AppColors.danger, Color(0xFFFCA5A5)],
                          ),
                        ),
                      ),
                    )
                  else if (processing)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    recording
                        ? l10n.pzSessionRecording
                        : processing
                        ? l10n.pzSessionThinking
                        : l10n.pzSessionTapToSpeak,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: recording ? AppColors.danger : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Nút xin gợi ý. Mỗi lần bấm là một tín hiệu "em bí" do chính học sinh phát ra --
          // rõ hơn nhiều so với suy từ điểm số, và là nguồn của helpRequestCount gửi lên
          // lúc đóng phiên (xem SessionDiagnosisPolicy phía Java).
          IconButton(
            onPressed: _sessionEnded ? null : _requestHelp,
            icon: const Icon(Icons.lightbulb_outline),
            color: AppColors.warnFg,
            tooltip: 'Gợi ý',
          ),
          const SizedBox(width: 4),
          _MicButton(
            pulse: _pulse,
            recording: recording,
            enabled: !processing,
            onPressStart: _startTalking,
            onPressEnd: _stopTalking,
          ),
        ],
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.title,
    required this.spokenSeconds,
    required this.budgetSeconds,
    required this.onClose,
  });

  final String title;

  /// Số giây học sinh THẬT SỰ nói, không phải thời gian trôi từ lúc mở phiên.
  final int spokenSeconds;

  /// Trần nói của phiên; 0 = chưa biết, lúc đó chỉ hiện số đã nói, không vẽ mẫu số/thanh.
  final int budgetSeconds;

  final VoidCallback onClose;

  /// Đổi màu từ 85% ngân sách để học sinh kịp gói ý lại, thay vì phiên đóng đột ngột.
  bool get _nearBudget =>
      budgetSeconds > 0 && spokenSeconds >= budgetSeconds * 0.85;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.indigo, AppColors.secondary],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 19,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  budgetSeconds > 0
                      ? l10n.pzSessionSpoken(
                          formatClock(spokenSeconds),
                          formatClock(budgetSeconds),
                        )
                      : l10n.pzSessionLive(formatClock(spokenSeconds)),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _nearBudget ? AppColors.warning : AppColors.success,
                  ),
                ),
                if (budgetSeconds > 0) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (spokenSeconds / budgetSeconds).clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        _nearBudget ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 22, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.indigo, AppColors.secondary],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.graphic_eq, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentBubble extends StatelessWidget {
  const _StudentBubble({required this.turn});
  final PracticeTurn turn;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.chipBlueBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: TranscriptText(
          text: turn.text,
          spans: turn.spans,
          baseStyle: const TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: Color(0xFF312E81),
          ),
        ),
      ),
    );
  }
}

/// Nút giữ-để-nói (push-to-talk).
///
/// Dùng onTapDown/onTapUp/onTapCancel chứ không onTap: cần biết lúc NHẤN và lúc THẢ, còn
/// onTap chỉ báo sau khi đã thả nên không mở được tiếng trong lúc giữ. onTapCancel bắt trường
/// hợp học sinh kéo ngón ra khỏi nút -- thiếu nó thì mic kẹt ở trạng thái mở.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.pulse,
    required this.recording,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
  });

  final Animation<double> pulse;
  final bool recording;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: enabled ? (_) => onPressStart() : null,
      onTapUp: enabled ? (_) => onPressEnd() : null,
      onTapCancel: enabled ? onPressEnd : null,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (_, child) {
          final t = recording ? pulse.value : 0.0;
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? AppColors.danger : AppColors.textGhost,
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.35 * (1 - t)),
                  blurRadius: 8,
                  spreadRadius: 12 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        // mic khi ĐANG thu (giữ nút), mic_none khi đang im -- nút `stop` cũ mang nghĩa "bấm
        // để dừng", sai với push-to-talk vì thả tay là dừng chứ không bấm lần nữa.
        child: Icon(
          recording ? Icons.mic : Icons.mic_none,
          size: 26,
          color: Colors.white,
        ),
      ),
    );
  }
}
