import 'package:flutter/material.dart';

import 'data/repositories/practice_repository.dart';

/// The practice app. The tests only ever call this function.
///
/// TODO(W3): load on start; show loading, the list, the empty state or the
/// failure view; a refresh action in the app bar, disabled while loading.
/// Use ChangeNotifier, Riverpod or Bloc inside, your choice.
Widget buildPracticeApp({
  required PracticeRepository repository,
  String studentId = 'demo',
}) {
  return const MaterialApp(
    home: Scaffold(body: Center(child: Text('TODO: practice screen'))),
  );
}
