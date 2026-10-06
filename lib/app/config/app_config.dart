/// Runtime environment, selected at build time with
/// `--dart-define=APP_ENV=development|production` (default: development).
enum AppEnvironment {
  development,
  production;

  static AppEnvironment parse(String value) => AppEnvironment.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AppEnvironment.development,
  );
}

/// Build-time configuration. Values come from `--dart-define` (or
/// `--dart-define-from-file`), never from source code.
///
/// SECURITY: anything compiled into a client app can be extracted. A
/// `GEMINI_API_KEY` supplied here is acceptable only for a personal
/// development MVP. For production, route AI calls through a server-side
/// proxy and set [aiProxyUrl] instead (see docs/ARCHITECTURE.md).
class AppConfig {
  const AppConfig({
    required this.environment,
    this.geminiApiKey = '',
    this.geminiModel = defaultGeminiModel,
    this.aiProxyUrl = '',
  });

  /// Override at build time with `--dart-define=GEMINI_MODEL=...`.
  static const defaultGeminiModel = 'gemini-3.5-flash-lite';

  /// Reads the compile-time defines. `String.fromEnvironment` must be const.
  factory AppConfig.fromEnvironment() => AppConfig(
    environment: AppEnvironment.parse(
      const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    ),
    geminiApiKey: const String.fromEnvironment('GEMINI_API_KEY'),
    geminiModel: const String.fromEnvironment(
      'GEMINI_MODEL',
      defaultValue: defaultGeminiModel,
    ),
    aiProxyUrl: const String.fromEnvironment('AI_PROXY_URL'),
  );

  final AppEnvironment environment;
  final String geminiApiKey;
  final String geminiModel;

  /// Future server-side AI proxy endpoint. Not used yet: `GeminiAIService`
  /// calls Gemini directly with [geminiApiKey].
  final String aiProxyUrl;

  bool get hasAICredentials => geminiApiKey.isNotEmpty || aiProxyUrl.isNotEmpty;
}
