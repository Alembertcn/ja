import 'dart:convert';

class PracticeSet {
  const PracticeSet({
    required this.id,
    required this.week,
    required this.level,
    required this.title,
    required this.goal,
    required this.sections,
  });

  final String id;
  final int week;
  final String level;
  final String title;
  final String goal;
  final List<PracticeSection> sections;

  int get questionCount =>
      sections.fold(0, (count, section) => count + section.questions.length);

  factory PracticeSet.parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return PracticeSet.fromJson(json);
  }

  factory PracticeSet.fromJson(Map<String, dynamic> json) => PracticeSet(
        id: json['id'] as String,
        week: (json['week'] as num).toInt(),
        level: json['level'] as String? ?? 'N2',
        title: json['title'] as String? ?? '配套练习',
        goal: json['goal'] as String? ?? '',
        sections: _mapList(json['sections'], PracticeSection.fromJson),
      );
}

class PracticeSection {
  const PracticeSection({
    required this.id,
    required this.title,
    required this.instructions,
    required this.questions,
  });

  final String id;
  final String title;
  final String instructions;
  final List<PracticeQuestion> questions;

  factory PracticeSection.fromJson(Map<String, dynamic> json) =>
      PracticeSection(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        instructions: json['instructions'] as String? ?? '',
        questions: _mapList(json['questions'], PracticeQuestion.fromJson),
      );
}

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.module,
    required this.stem,
    required this.options,
    required this.answer,
    required this.explanation,
    this.passage,
  });

  final String id;
  final String module;
  final String stem;
  final String? passage;
  final List<String> options;

  /// 正确选项的零基下标。
  final int answer;
  final String explanation;

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final options = _stringList(json['options']);
    final answer = (json['answer'] as num).toInt();
    if (options.length != 4 || answer < 0 || answer >= options.length) {
      throw const FormatException('练习题必须有 4 个选项且答案下标有效');
    }
    return PracticeQuestion(
      id: json['id'] as String,
      module: json['module'] as String? ?? '',
      stem: json['stem'] as String,
      passage: json['passage'] as String?,
      options: options,
      answer: answer,
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

List<T> _mapList<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((item) => item.toString()).toList(growable: false);
}
