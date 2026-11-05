import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Microphone dictation and spoken replies.
///
/// Uses the platform's own speech services (Web Speech API in Chrome and
/// Edge, Siri speech on iOS/macOS, Google on Android), so audio never
/// leaves the device through DSCVR.
class VoiceService extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _ready = false;
  bool _available = false;
  bool _listening = false;
  bool _speaking = false;
  String _words = '';
  String? _error;
  double _level = 0;
  void Function(String text)? _onFinal;

  bool get available => _available;
  bool get listening => _listening;
  bool get speaking => _speaking;

  /// Live transcript of what's being said.
  String get words => _words;
  String? get error => _error;

  /// Normalised microphone level (0-1) for the waveform.
  double get level => _level;

  Future<bool> init() async {
    if (_ready) return _available;
    _ready = true;
    try {
      _available = await _stt.initialize(
        onStatus: (s) {
          final listening = s == SpeechToText.listeningStatus;
          if (listening != _listening) {
            _listening = listening;
            if (!listening) _finish();
            notifyListeners();
          }
        },
        onError: (SpeechRecognitionError e) {
          _error = switch (e.errorMsg) {
            'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Try again.",
            'error_permission' || 'not-allowed' => 'Allow microphone access to use voice.',
            _ => 'Voice input stopped (${e.errorMsg}).',
          };
          _listening = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _available = false;
    }
    try {
      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        _speaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        _speaking = false;
        notifyListeners();
      });
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5);
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
    notifyListeners();
    return _available;
  }

  /// Starts listening. [onFinal] gets the full transcript when the speaker
  /// stops (or [stop] is called). [dictation] keeps listening through pauses.
  Future<bool> listen({required void Function(String text) onFinal, bool dictation = false}) async {
    if (!await init()) {
      _error = kIsWeb
          ? 'Voice needs Chrome, Edge or Safari with microphone access.'
          : 'Speech recognition is not available on this device.';
      notifyListeners();
      return false;
    }
    await stopSpeaking();
    _words = '';
    _error = null;
    _onFinal = onFinal;
    await _stt.listen(
      onResult: (r) {
        _words = r.recognizedWords;
        notifyListeners();
        if (r.finalResult) _finish();
      },
      onSoundLevelChange: (l) {
        // Platforms report different ranges; squash into 0-1.
        _level = ((l + 2) / 12).clamp(0.0, 1.0);
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: dictation ? ListenMode.dictation : ListenMode.confirmation,
        cancelOnError: true,
        autoPunctuation: true,
        listenFor: dictation ? const Duration(minutes: 10) : const Duration(seconds: 60),
        pauseFor: dictation ? const Duration(seconds: 30) : const Duration(seconds: 3),
      ),
    );
    _listening = true;
    notifyListeners();
    return true;
  }

  void _finish() {
    final cb = _onFinal;
    _onFinal = null;
    final text = _words.trim();
    if (cb != null && text.isNotEmpty) cb(text);
  }

  Future<void> stop() async {
    await _stt.stop();
    _listening = false;
    _level = 0;
    _finish();
    notifyListeners();
  }

  Future<void> cancel() async {
    _onFinal = null;
    await _stt.cancel();
    _listening = false;
    _words = '';
    notifyListeners();
  }

  /// Speaks [markdown] aloud after stripping formatting.
  Future<void> speak(String markdown) async {
    final text = plain(markdown);
    if (text.isEmpty) return;
    try {
      await _tts.stop();
      _speaking = true;
      notifyListeners();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS failed: $e');
      _speaking = false;
      notifyListeners();
    }
  }

  Future<void> stopSpeaking() async {
    if (!_speaking) return;
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
    notifyListeners();
  }

  /// Markdown to speakable text.
  static String plain(String md) => md
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'[*_>|]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  @override
  void dispose() {
    _stt.cancel();
    _tts.stop();
    super.dispose();
  }
}
