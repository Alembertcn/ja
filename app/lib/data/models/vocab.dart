import 'dart:convert';

/// 与 content/schema/vocab.schema.json 对应。

enum VocabGroupKind {
  similarity,
  theme,
  pattern,
  function,
  sound,
  core;

  static VocabGroupKind fromString(String? raw) {
    switch (raw) {
      case 'similarity':
        return VocabGroupKind.similarity;
      case 'theme':
        return VocabGroupKind.theme;
      case 'pattern':
        return VocabGroupKind.pattern;
      case 'function':
        return VocabGroupKind.function;
      case 'sound':
        return VocabGroupKind.sound;
      case 'core':
        return VocabGroupKind.core;
      default:
        return VocabGroupKind.theme;
    }
  }

  String get labelZh => switch (this) {
        VocabGroupKind.similarity => '易混近义',
        VocabGroupKind.theme => '主题',
        VocabGroupKind.pattern => '构词',
        VocabGroupKind.function => '功能词',
        VocabGroupKind.sound => '拟声拟态',
        VocabGroupKind.core => '高频核心',
      };
}

class VocabWord {
  const VocabWord({
    required this.word,
    required this.reading,
    required this.zh,
    this.note,
  });

  final String word;
  final String reading;
  final String zh;
  final String? note;

  factory VocabWord.fromJson(Map<String, dynamic> json) => VocabWord(
        word: json['word'] as String,
        reading: json['reading'] as String,
        zh: json['zh'] as String,
        note: json['note'] as String?,
      );
}

class VocabGroup {
  const VocabGroup({
    required this.id,
    required this.title,
    required this.kind,
    this.hint,
    required this.words,
  });

  final String id;
  final String title;
  final VocabGroupKind kind;
  final String? hint;
  final List<VocabWord> words;

  factory VocabGroup.fromJson(Map<String, dynamic> json) => VocabGroup(
        id: json['id'] as String,
        title: json['title'] as String,
        kind: VocabGroupKind.fromString(json['kind'] as String?),
        hint: json['hint'] as String?,
        words: _mapList(json['words'], VocabWord.fromJson),
      );
}

class VocabBook {
  const VocabBook({
    required this.id,
    required this.title,
    required this.titleZh,
    required this.level,
    this.subtitle,
    required this.updatedAt,
    required this.groups,
  });

  final String id;
  final String title;
  final String titleZh;
  final String level;
  final String? subtitle;
  final String updatedAt;
  final List<VocabGroup> groups;

  int get wordCount =>
      groups.fold(0, (sum, group) => sum + group.words.length);

  factory VocabBook.fromJson(Map<String, dynamic> json) => VocabBook(
        id: json['id'] as String,
        title: json['title'] as String,
        titleZh: json['titleZh'] as String,
        level: json['level'] as String,
        subtitle: json['subtitle'] as String?,
        updatedAt: json['updatedAt'] as String,
        groups: _mapList(json['groups'], VocabGroup.fromJson),
      );

  static VocabBook parse(String body) =>
      VocabBook.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}
