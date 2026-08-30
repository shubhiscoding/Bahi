import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps speech-to-text (listening) and text-to-speech (spoken read-back)
/// for design.md rule 1: voice is the primary input, and what was heard
/// must be confirmed both visually AND audibly — never a silent checkmark.
class VoiceService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsInitialized = false;

  static Future<void> _ensureTtsInitialized() async {
    if (_ttsInitialized) return;
    await _tts.setLanguage('hi-IN');
    await _tts.setSpeechRate(0.45); // slower — this audience needs it clear, not fast
    _ttsInitialized = true;
  }

  /// Requests mic permission (via speech_to_text's own init flow) and
  /// returns whether speech recognition is available on this device.
  static Future<bool> initialize() async {
    return _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
    );
  }

  static bool get isListening => _speech.isListening;

  /// Starts listening; calls [onResult] with the recognized text once
  /// the user stops speaking (final result only — partials are ignored
  /// to avoid showing/confirming a half-finished sentence).
  static Future<void> listen({
    required void Function(String text) onResult,
  }) async {
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'hi_IN',
        partialResults: false,
        cancelOnError: true,
      ),
    );
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }

  /// Speaks text aloud in Hindi — the audible half of the "confirm both
  /// visually and audibly" requirement (rule 1).
  static Future<void> speak(String text) async {
    await _ensureTtsInitialized();
    await _tts.speak(text);
  }

  static Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}
