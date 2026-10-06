import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai/ai_service.dart';
import '../services/audio/record_voice_recorder.dart';
import '../services/audio/voice_recorder.dart';
import '../services/ai/gemini_ai_service.dart';
import '../services/speech/flutter_tts_speech_service.dart';
import '../services/speech/speech_service.dart';
import '../services/storage/local_storage.dart';
import '../services/storage/shared_preferences_local_storage.dart';
import 'config/app_config.dart';

/// App-wide dependency wiring. Only cross-cutting services live here;
/// feature state lives in each feature's own providers. Tests override these
/// to swap implementations.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final localStorageProvider = Provider<LocalStorage>(
  (ref) => SharedPreferencesLocalStorage(SharedPreferencesAsync()),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final aiServiceProvider = Provider<AIService>(
  (ref) => GeminiAIService(
    ref.watch(appConfigProvider),
    ref.watch(httpClientProvider),
  ),
);

/// Reads text aloud with the device's voices. Tests swap it for a fake.
final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterTtsSpeechService();
  ref.onDispose(service.stop);
  return service;
});

/// Records the learner's voice messages. Tests swap it for a fake.
final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = RecordVoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
