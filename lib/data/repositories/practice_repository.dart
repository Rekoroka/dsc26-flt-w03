import '../../domain/models/question.dart';
import '../../utils/result.dart';
import '../services/api_failure.dart';
import '../services/question_api.dart';

class PracticeRepository {
  PracticeRepository({
    required QuestionApi api,
    required Future<void> Function(Duration) sleep,
    int maxRetries = 2,
  }) : _api = api,
       _sleep = sleep,
       _maxRetries = maxRetries;

  final QuestionApi _api;
  final Future<void> Function(Duration) _sleep;
  final int _maxRetries;

  Future<Result<List<Question>>> nextQuestions(String studentId) async {
    var retries = 0;

    while (true) {
      final result = await _api.fetchNext(studentId: studentId);

      if (result is Ok<List<Question>>) {
        return result;
      }

      final failure = (result as Err<List<Question>>).failure;

      if (!failure.isTransient || retries >= _maxRetries) {
        return result;
      }

      Duration wait;

      if (failure is RateLimited) {
        wait = failure.retryAfter > const Duration(seconds: 30)
            ? const Duration(seconds: 30)
            : failure.retryAfter;
      } else {
        wait = Duration(seconds: 1 << retries);
      }

      await _sleep(wait);
      retries++;
    }
  }
}
