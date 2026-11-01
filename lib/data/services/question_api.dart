import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/question.dart';
import '../../utils/result.dart';
import 'api_failure.dart';

class QuestionApi {
  QuestionApi({
    required http.Client client,
    required Uri baseUrl,
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client,
       _baseUrl = baseUrl,
       _timeout = timeout;

  final http.Client _client;
  final Uri _baseUrl;
  final Duration _timeout;

  Future<Result<List<Question>>> fetchNext({
    required String studentId,
    int limit = 10,
  }) async {
    // خطأ برمجي وليس خطأ شبكة: يُرمى قبل إرسال أي request.
    if (limit < 1 || limit > 50) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 50');
    }

    // replace(pathSegments: ...) يشفّر كل segment: المسافة %20 و / تصبح %2F.
    // نتجاهل الـ segments الفارغة (trailing slash) ونحتفظ بالـ base path.
    final uri = _baseUrl.replace(
      pathSegments: [
        ..._baseUrl.pathSegments.where((segment) => segment.isNotEmpty),
        'v1',
        'students',
        studentId,
        'next-questions',
      ],
      queryParameters: {'limit': '$limit'},
    );

    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      switch (response.statusCode) {
        case 200:
          return _parseBody(response);
        case 401:
          return const Err(Unauthorized());
        case 404:
          return const Err(NotFound());
        case 429:
          return Err(
            RateLimited(_parseRetryAfter(response.headers['retry-after'])),
          );
        case >= 500 && <= 599:
          return Err(ServerError(response.statusCode));
        default:
          return Err(UnexpectedStatus(response.statusCode));
      }
    } on TimeoutException {
      return const Err(TimedOut());
    } on http.ClientException {
      return const Err(Offline());
    }
  }

  /// فك الترميز من bytes بـ UTF-8 بغض النظر عن الـ headers (للنص العربي).
  /// لا يرمي أي exception: أي مشكلة تتحول إلى BadResponse.
  Result<List<Question>> _parseBody(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        return const Err(BadResponse('Response must be a JSON object'));
      }

      final rawQuestions = decoded['questions'];
      if (rawQuestions is! List) {
        return const Err(BadResponse('Missing or invalid questions list'));
      }

      final questions = <Question>[];
      for (final item in rawQuestions) {
        if (item is! Map) {
          return const Err(BadResponse('Question must be an object'));
        }
        questions.add(Question.fromJson(Map<String, Object?>.from(item)));
      }
      return Ok(questions);
    } catch (_) {
      return const Err(BadResponse('Invalid response body'));
    }
  }

  /// أرقام صحيحة فقط ("12" أو "120"). أي شيء آخر (تاريخ HTTP، "2.5"، نص،
  /// "+5"، سالب) يأخذ القيمة الافتراضية 5 ثوانٍ.
  Duration _parseRetryAfter(String? raw) {
    final value = raw?.trim();
    if (value == null || !RegExp(r'^\d+$').hasMatch(value)) {
      return const Duration(seconds: 5);
    }
    final seconds = int.tryParse(value);
    return Duration(seconds: seconds ?? 5);
  }
}
