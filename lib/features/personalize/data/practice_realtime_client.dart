import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/api_endpoints.dart';

/// WebSocket client for a practice session's realtime channel
/// (`/realtime/practice-sessions/{id}`, served by the Python agents service, NOT the Java
/// backend -- see gói 11 mục 2.7b). Mirrors WPF's `RealtimeSessionClient.cs` in shape (connect
/// by id, binary audio frames + JSON text-frame protocol), not in code (different language).
///
/// No auth on this WebSocket -- deliberately mirrors exam's realtime WS, which has none either
/// today (see mục 2.3/2.7b: a pre-existing gap in exam, not something new introduced here).
class PracticeRealtimeClient {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventsController = StreamController<Map<String, dynamic>>.broadcast();

  /// Decoded JSON text frames from the server: question_start_ack, decision, correction,
  /// next_question, speak, vad_speech_start, vad_speech_end, partial_transcript,
  /// final_transcript, practice_end_ack, practice_session_ended, resume_ack, error.
  Stream<Map<String, dynamic>> get events => _eventsController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String practiceSessionId) async {
    final uri = Uri.parse(
      '${ApiEndpoints.aiServiceWsBaseUrl}/realtime/practice-sessions/$practiceSessionId',
    );
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _subscription = channel.stream.listen(
      _handleIncoming,
      onError: (Object error, StackTrace stackTrace) {
        _eventsController.add({'type': 'error', 'text': error.toString()});
      },
      onDone: () {
        _eventsController.add({'type': 'connection_closed'});
      },
    );
  }

  void _handleIncoming(dynamic data) {
    // The server only ever sends JSON text frames -- binary frames are client->server only
    // (mic audio). A non-String frame here would mean a protocol mismatch, not something to
    // silently swallow, but there's nothing useful to do with it either; ignore.
    if (data is! String) return;
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      _eventsController.add(decoded);
    }
  }

  /// One chunk of raw PCM16 mic audio (16kHz, mono -- matches
  /// voice_live_client.EXPECTED_SAMPLE_RATE server-side). Sent continuously once connected,
  /// not gated by the mic button (which only toggles mute, see practice_session_screen.dart).
  void sendAudioFrame(Uint8List pcm16) {
    _channel?.sink.add(pcm16);
  }

  /// One JSON control message: question_start, present_question, turn_end,
  /// speech_budget_progress, resume, practice_end.
  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    close();
    _eventsController.close();
  }
}
