import 'dart:async';
import 'dart:convert';

import 'package:dsc26_flt_w03/app.dart';
import 'package:dsc26_flt_w03/data/repositories/practice_repository.dart';
import 'package:dsc26_flt_w03/data/services/api_failure.dart';
import 'package:dsc26_flt_w03/data/services/question_api.dart';
import 'package:dsc26_flt_w03/domain/models/question.dart';
import 'package:dsc26_flt_w03/utils/result.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final base = Uri.parse('https://api.masaraat.test');

Map<String, Object?> q(String id) => {
      'id': id,
      'skillId': 'chem.moles',
      'stem': 'كم عدد المولات؟',
      'choices': ['1', '2', '3', '4'],
    };

http.Response ok(List<Map<String, Object?>> questions) => http.Response.bytes(
      utf8.encode(jsonEncode({'questions': questions})),
      200,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('fetchNext calls the right URL and parses Arabic text', () async {
    late Uri seen;
    final api = QuestionApi(
      client: MockClient((request) async {
        seen = request.url;
        return ok([q('q1'), q('q2')]);
      }),
      baseUrl: base,
    );
    final result = await api.fetchNext(studentId: 's-42', limit: 2);
    expect(seen.path, '/v1/students/s-42/next-questions');
    expect(seen.queryParameters['limit'], '2');
    expect(result, isA<Ok<List<Question>>>());
    final questions = (result as Ok<List<Question>>).value;
    expect(questions.map((x) => x.id), ['q1', 'q2']);
    expect(questions.first.stem, 'كم عدد المولات؟');
  });

  test('429 becomes RateLimited with the Retry-After value', () async {
    final api = QuestionApi(
      client: MockClient((_) async =>
          http.Response('slow down', 429, headers: {'retry-after': '7'})),
      baseUrl: base,
    );
    final result = await api.fetchNext(studentId: 's-42');
    final failure = (result as Err<List<Question>>).failure;
    expect(failure, isA<RateLimited>());
    expect((failure as RateLimited).retryAfter, const Duration(seconds: 7));
  });

  test('a 503 is retried once after 1 second, then succeeds', () async {
    var calls = 0;
    final waits = <Duration>[];
    final repo = PracticeRepository(
      api: QuestionApi(
        client: MockClient((_) async =>
            ++calls == 1 ? http.Response('busy', 503) : ok([q('q1')])),
        baseUrl: base,
      ),
      sleep: (d) async => waits.add(d),
    );
    final result = await repo.nextQuestions('s-42');
    expect(result, isA<Ok<List<Question>>>());
    expect(calls, 2);
    expect(waits, [const Duration(seconds: 1)]);
  });

  testWidgets('offline shows retry, and retry recovers', (tester) async {
    var online = false;
    final repo = PracticeRepository(
      api: QuestionApi(
        client: MockClient((_) async {
          if (!online) throw http.ClientException('no route to host');
          return ok([q('q1')]);
        }),
        baseUrl: base,
      ),
      sleep: (_) async {},
    );
    await tester.pumpWidget(buildPracticeApp(repository: repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-error')), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    online = true;
    await tester.tap(find.byKey(const Key('practice-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('question-q1')), findsOneWidget);
  });

  testWidgets('shows a loading indicator until the server answers',
      (tester) async {
    final gate = Completer<http.Response>();
    final repo = PracticeRepository(
      api: QuestionApi(client: MockClient((_) => gate.future), baseUrl: base),
      sleep: (_) async {},
    );
    await tester.pumpWidget(buildPracticeApp(repository: repo));
    await tester.pump();
    expect(find.byKey(const Key('practice-loading')), findsOneWidget);
    gate.complete(ok([]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('practice-empty')), findsOneWidget);
  });
}
