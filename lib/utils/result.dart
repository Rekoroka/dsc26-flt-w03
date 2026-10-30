import '../data/services/api_failure.dart';

/// The result of a data-layer call: a value or a typed failure.
/// The data layer returns these instead of throwing.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Called `Err` (not `Error`) so it does not shadow Dart's own `Error` class.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final ApiFailure failure;

  @override
  String toString() => 'Err($failure)';
}
