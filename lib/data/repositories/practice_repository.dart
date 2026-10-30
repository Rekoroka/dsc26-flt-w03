import '../../domain/models/question.dart';
import '../../utils/result.dart';
import '../services/question_api.dart';

/// The source of truth for practice questions. Owns the retry policy.
///
/// Keep the constructor and the signature of [nextQuestions] exactly.
class PracticeRepository {
  PracticeRepository({
    required QuestionApi api,
    required Future<void> Function(Duration) sleep,
    int maxRetries = 2,
  })  : _api = api,
        _sleep = sleep,
        _maxRetries = maxRetries;

  // ignore: unused_field
  final QuestionApi _api;
  // ignore: unused_field
  final Future<void> Function(Duration) _sleep;
  // ignore: unused_field
  final int _maxRetries;

  /// TODO(W3): retry transient failures at most maxRetries times, waiting
  /// 1 s, 2 s, ... (Retry-After for 429, capped at 30 s). Return permanent
  /// failures after one call.
  Future<Result<List<Question>>> nextQuestions(String studentId) async {
    throw UnimplementedError('PracticeRepository.nextQuestions');
  }
}
