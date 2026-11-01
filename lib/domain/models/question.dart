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
  /// Throws [FormatException] when `id`, `skillId` or `stem` is not a
  /// non-empty string, or when `choices` is not a list of 2 to 6 non-empty
  /// strings.
  factory Question.fromJson(Map<String, Object?> json) {
    final id = _requireString(json, 'id');
    final skillId = _requireString(json, 'skillId');
    final stem = _requireString(json, 'stem');

    final rawChoices = json['choices'];
    if (rawChoices is! List ||
        rawChoices.length < 2 ||
        rawChoices.length > 6 ||
        !rawChoices.every((c) => c is String && c.isNotEmpty)) {
      throw const FormatException('Invalid question choices');
    }

    return Question(
      id: id,
      skillId: skillId,
      stem: stem,
      choices: List<String>.from(rawChoices),
    );
  }

  static String _requireString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('Invalid $key');
    }
    return value;
  }
}
