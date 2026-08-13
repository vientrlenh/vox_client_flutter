package com.example.vox_client_flutter

import android.content.Context
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Cầu nối cho MỘT câu hỏi mà gói `record` không trả lời được: micro của app này có đang bị hệ
 * điều hành BỊT TIẾNG không.
 *
 * Từ Android 10 (API 29), khi một app khác giữ micro ở nguồn ưu tiên hơn -- Google Meet dùng
 * VOICE_COMMUNICATION lúc gọi hoặc chia sẻ màn hình -- hệ thống KHÔNG từ chối app thứ hai. Nó vẫn
 * mở luồng, vẫn trả khung dữ liệu, nhưng toàn số 0. Đo được trên máy thật bằng `dumpsys audio`:
 *
 *   pack:com.google.android.apps.tachyon  VOICE_COMMUNICATION  silenced:false
 *   pack:com.example.vox_client_flutter   MIC 16000Hz          silenced:true
 *
 * Nên phía Dart `startStream()` không hề ném, không có gì để bắt, và người dùng bấm nút nói mà
 * không hiểu vì sao chẳng có gì xảy ra.
 *
 * `isClientSilenced` là ĐÚNG cờ đó do hệ điều hành công bố -- không phải suy đoán từ biên độ, nên
 * không có ngưỡng nào để chỉnh sai và không báo nhầm khi học sinh chỉ đang im lặng nghĩ.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "vox/mic_status"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isMicSilenced" -> result.success(isMicSilenced(call.argument<Int>("sampleRate")))
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * @return true nếu micro của CHÍNH app này đang bị bịt; false nếu đang thu thật;
     *         null khi không kết luận được -- Android dưới 10 (không có API), hoặc app chưa mở
     *         micro nên chẳng có cấu hình ghi âm nào để soi.
     *
     * Trả null thay vì false có chủ đích: "không biết" khác hẳn "vẫn ổn", và phía Dart phải tự
     * quyết chứ không được ngầm hiểu là bình thường.
     */
    private fun isMicSilenced(sampleRate: Int?): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return null
        val all = audioManager.activeRecordingConfigurations
        if (all.isEmpty()) return null

        // PHẢI lọc về cấu hình của chính mình.
        //
        // Bản đầu tiên tin rằng danh sách này đã được hệ thống lọc sẵn theo từng app. Đo trên máy
        // thật (OPPO CPH2701, Android 16 / sdk 36) thì KHÔNG: nó trả về cả cấu hình của app khác.
        // Hậu quả là một lỗi tự phủ định -- bấm "Giành micro", ta thắng, Google Meet bị bịt lại,
        // rồi `any { isClientSilenced }` bắt phải cờ CỦA MEET và kết luận rằng ta thất bại:
        //
        //   pack:com.google.android.apps.tachyon  VOICE_COMMUNICATION 48000Hz  silenced:true
        //   pack:com.example.vox_client_flutter   VOICE_COMMUNICATION 16000Hz  silenced:false
        //
        // Càng thắng thì càng báo thua. AudioRecordingConfiguration không phơi uid/package cho
        // app thường, nên nhận diện bằng ĐỊNH DẠNG ta tự yêu cầu: 16 kHz là tần số phiên luyện
        // dùng, còn app gọi điện gần như luôn ở 48 kHz. Không tuyệt đối, nhưng sai theo hướng an
        // toàn -- không khớp cái nào thì trả null ("không biết") chứ không trả false ("vẫn ổn").
        val mine = if (sampleRate == null) all
                   else all.filter { it.clientFormat.sampleRate == sampleRate }
        if (mine.isEmpty()) return null

        return mine.any { it.isClientSilenced }
    }
}
