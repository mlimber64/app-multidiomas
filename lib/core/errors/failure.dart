/// Domain-level error types. Implementations translate provider/storage
/// exceptions into these so upper layers stay implementation-agnostic.
sealed class AppFailure {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Required configuration (e.g. an API key) is missing.
final class ConfigurationFailure extends AppFailure {
  const ConfigurationFailure(super.message);
}

/// Local persistence failed.
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message);
}

/// Why an exercise cannot be built from the available learning data. Normal
/// and expected (not every review item carries enough information), so it is
/// reported as a value instead of being thrown.
enum ExerciseUnavailableReason {
  /// The review item's source no longer exists in learning memory (or does not
  /// belong to the learner's learning language).
  sourceMissing,

  /// The source exists but lacks what a correct exercise needs.
  insufficientData,

  /// No exercise is defined for this kind of review item yet.
  unsupportedType,
}

final class ExerciseUnavailableFailure extends AppFailure {
  const ExerciseUnavailableFailure(this.reason, super.message);
  final ExerciseUnavailableReason reason;
}

/// Why an AI call failed, so the UI can pick a friendly message without
/// seeing provider details.
enum AIFailureKind {
  /// No API key / proxy configured, or the key was rejected.
  notConfigured,
  network,
  rateLimited,

  /// The provider declined to answer (safety filters).
  blocked,

  /// The provider answered, but not in a usable form.
  invalidResponse,
  unknown,
}

/// An AI provider call failed. [message] is for logs/debugging only and is
/// never shown to the user.
final class AIFailure extends AppFailure {
  const AIFailure(super.message, {this.kind = AIFailureKind.unknown});
  final AIFailureKind kind;
}
