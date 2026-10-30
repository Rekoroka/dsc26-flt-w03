import 'package:http/http.dart' as http;

import '../../domain/models/question.dart';
import '../../utils/result.dart';

/// One call to the Masaraat questions API. Holds no state and never retries.
///
/// Keep the constructor and the signature of [fetchNext] exactly.
class QuestionApi {
  QuestionApi({
    required http.Client client,
    required Uri baseUrl,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = client,
        _baseUrl = baseUrl,
        _timeout = timeout;

  // ignore: unused_field
  final http.Client _client;
  // ignore: unused_field
  final Uri _baseUrl;
  // ignore: unused_field
  final Duration _timeout;

  /// `GET {baseUrl}/v1/students/{studentId}/next-questions?limit={limit}`.
  ///
  /// TODO(W3): see the README for the URL, headers, parsing, status mapping
  /// and network failures. Never throws for network or server problems.
  Future<Result<List<Question>>> fetchNext({
    required String studentId,
    int limit = 10,
  }) async {
    throw UnimplementedError('QuestionApi.fetchNext');
  }
}
