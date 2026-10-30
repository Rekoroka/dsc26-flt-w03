/// One practice question chosen for a student by the Masaraat backend.
final class Question {
  const Question({
    required this.id,
    required this.skillId,
    required this.stem,
    required this.choices,
  });

  final String id;
  final String skillId;
  final String stem;
  final List<String> choices;

  /// Reads one question from the API. Unknown fields are ignored.
  ///
  /// TODO(W3): throw a FormatException for a missing or wrongly typed field,
  /// or when `choices` is not a list of 2 to 6 non-empty strings.
  factory Question.fromJson(Map<String, Object?> json) {
    throw UnimplementedError('Question.fromJson');
  }
}
