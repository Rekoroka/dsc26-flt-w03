import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app.dart';
import 'data/repositories/practice_repository.dart';
import 'data/services/question_api.dart';

/// Demo entry point: a fake server answers from memory, so `flutter run`
/// works without the real Masaraat backend. Swap in `http.Client()` and the
/// real base URL in a squad app.
void main() {
  final fakeServer = MockClient((request) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final body = jsonEncode({
      'questions': [
        {
          'id': 'q1',
          'skillId': 'chem.moles',
          'stem': 'كم عدد المولات في ١٨ جرام من الماء؟',
          'choices': ['0.5', '1', '2', '18'],
        },
        {
          'id': 'q2',
          'skillId': 'phys.speed',
          'stem': 'سيارة تقطع ١٢٠ كم في ساعتين. ما سرعتها؟',
          'choices': ['30 كم/س', '60 كم/س', '120 كم/س'],
        },
      ],
    });
    return http.Response.bytes(utf8.encode(body), 200,
        headers: {'content-type': 'application/json'});
  });
  final repository = PracticeRepository(
    api: QuestionApi(
      client: fakeServer,
      baseUrl: Uri.parse('https://api.masaraat.test'),
    ),
    sleep: Future<void>.delayed,
  );
  runApp(buildPracticeApp(repository: repository, studentId: 's-42'));
}
