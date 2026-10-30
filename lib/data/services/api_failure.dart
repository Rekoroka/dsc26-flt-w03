/// Everything that can go wrong when fetching practice questions.
///
/// [isTransient] failures may succeed if tried again later; the others will
/// not, so they must not be retried.
sealed class ApiFailure {
  const ApiFailure();

  bool get isTransient;
}

/// No connection (`http.ClientException`).
final class Offline extends ApiFailure {
  const Offline();

  @override
  bool get isTransient => true;

  @override
  String toString() => 'Offline()';
}

/// The server did not answer within the timeout.
final class TimedOut extends ApiFailure {
  const TimedOut();

  @override
  bool get isTransient => true;

  @override
  String toString() => 'TimedOut()';
}

/// 500-599.
final class ServerError extends ApiFailure {
  const ServerError(this.statusCode);

  final int statusCode;

  @override
  bool get isTransient => true;

  @override
  String toString() => 'ServerError($statusCode)';
}

/// 429. [retryAfter] comes from the Retry-After header (whole seconds).
final class RateLimited extends ApiFailure {
  const RateLimited(this.retryAfter);

  final Duration retryAfter;

  @override
  bool get isTransient => true;

  @override
  String toString() => 'RateLimited($retryAfter)';
}

/// 401: the session expired; the student must sign in again.
final class Unauthorized extends ApiFailure {
  const Unauthorized();

  @override
  bool get isTransient => false;

  @override
  String toString() => 'Unauthorized()';
}

/// 404.
final class NotFound extends ApiFailure {
  const NotFound();

  @override
  bool get isTransient => false;

  @override
  String toString() => 'NotFound()';
}

/// 200, but the body is not what the API promises.
final class BadResponse extends ApiFailure {
  const BadResponse(this.reason);

  final String reason;

  @override
  bool get isTransient => false;

  @override
  String toString() => 'BadResponse($reason)';
}

/// Any other status code.
final class UnexpectedStatus extends ApiFailure {
  const UnexpectedStatus(this.statusCode);

  final int statusCode;

  @override
  bool get isTransient => false;

  @override
  String toString() => 'UnexpectedStatus($statusCode)';
}
