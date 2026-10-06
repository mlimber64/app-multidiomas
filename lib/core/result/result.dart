import '../errors/failure.dart';

/// Explicit success/failure outcome for operations that can fail for
/// expected reasons (storage, AI calls). Avoids leaking exceptions across
/// layer boundaries.
sealed class Result<T> {
  const Result();

  /// Convenience for pattern-free consumption.
  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      Failure<T>(failure: final f) => failure(f),
    };
  }
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);
  final AppFailure failure;
}
