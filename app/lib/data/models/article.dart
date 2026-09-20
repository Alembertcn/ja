import 'dart:convert';

/// 与 content/schema/article.schema.json 对应的数据模型。
/// 字段名必须与契约保持一致，改动时两边要同步。

class RubySpan {
  const RubySpan({required this.start, required this.len, required this.ruby});

  final int start;
  final int len;
  final String ruby;

  int get end => start + len;

  factory RubySpan.fromJson(Map<String, dynamic> json) => RubySpan(
        start: (json['start'] as num).toInt(),
        len: (json['len'] as num).toInt(),
        ruby: json['ruby'] as String,
      );
}

class GrammarPoint {
  const GrammarPoint({this.module, required this.point, required this.explain});

  /// 学习计划里的模块号，如 G2-E01。可能缺省。
  final String? module;
  final String point;
  final String explain;

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
        module: json['module'] as String?,
        point: json['point'] as String,
        explain: json['explain'] as String,
      );
}

class VocabItem {
  const VocabItem({
    required this.word,
    required this.reading,
    this.pos,
    required this.zh,
    this.note,
  });

  final String word;
  final String reading;
  final String? pos;
  final String zh;
  final String? note;

  factory VocabItem.fromJson(Map<String, dynamic> json) => VocabItem(
        word: json['word'] as String,
        reading: json['reading'] as String,
        pos: json['pos'] as String?,
        zh: json['zh'] as String,
        note: json['note'] as String?,
      );
}

class ArticleLine {
  const ArticleLine({
    required this.id,
    this.speaker,
    required this.jp,
    required this.reading,
    this.romaji,
    this.furigana = const [],
    required this.zh,
    this.grammar = const [],
    this.vocab = const [],
    this.note,
    this.isSentenceEnd = true,
  });

  final String id;
  final String? speaker;
  final String jp;

  /// 整句假名读音。
  final String reading;
  final String? romaji;
  final List<RubySpan> furigana;
  final String zh;
  final List<GrammarPoint> grammar;
  final List<VocabItem> vocab;
  final String? note;

  /// 完整句结尾才显示 AI 讲解入口。
  final bool isSentenceEnd;

  factory ArticleLine.fromJson(Map<String, dynamic> json) => ArticleLine(
        id: json['id'] as String,
        speaker: json['speaker'] as String?,
        jp: json['jp'] as String,
        reading: json['reading'] as String,
        romaji: json['romaji'] as String?,
        furigana: _mapList(json['furigana'], RubySpan.fromJson),
        zh: json['zh'] as String,
        grammar: _mapList(json['grammar'], GrammarPoint.fromJson),
        vocab: _mapList(json['vocab'], VocabItem.fromJson),
        note: json['note'] as String?,
        isSentenceEnd: json['isSentenceEnd'] as bool? ?? true,
      );
}

/// 整篇音频中一句的起止时间（毫秒）。
class AudioCue {
  const AudioCue({
    required this.id,
    required this.startMs,
    required this.endMs,
  });

  final String id;
  final int startMs;
  final int endMs;

  Duration get start => Duration(milliseconds: startMs);
  Duration get end => Duration(milliseconds: endMs);

  factory AudioCue.fromJson(Map<String, dynamic> json) => AudioCue(
        id: json['id'] as String,
        startMs: (json['startMs'] as num).toInt(),
        endMs: (json['endMs'] as num).toInt(),
      );
}

class Article {
  const Article({
    required this.id,
    required this.title,
    required this.titleZh,
    required this.stage,
    required this.week,
    required this.level,
    required this.type,
    this.scene,
    this.grammarModules = const [],
    this.vocabTopic,
    this.tags = const [],
    required this.updatedAt,
    this.audio,
    this.cues = const [],
    required this.lines,
  });

  final String id;
  final String title;
  final String titleZh;
  final String stage;
  final int week;
  final String level;
  final String type;
  final String? scene;
  final List<String> grammarModules;
  final String? vocabTopic;
  final List<String> tags;
  final String updatedAt;

  /// 整篇音频相对路径，构建期注入。
  final String? audio;

  /// 句级时间轴，与 lines 顺序一致。
  final List<AudioCue> cues;

  final List<ArticleLine> lines;

  bool get isDialogue => type == 'dialogue';

  bool get hasAudio => audio != null && audio!.isNotEmpty && cues.isNotEmpty;

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String,
        title: json['title'] as String,
        titleZh: json['titleZh'] as String,
        stage: json['stage'] as String,
        week: (json['week'] as num).toInt(),
        level: json['level'] as String,
        type: json['type'] as String,
        scene: json['scene'] as String?,
        grammarModules: _stringList(json['grammarModules']),
        vocabTopic: json['vocabTopic'] as String?,
        tags: _stringList(json['tags']),
        updatedAt: json['updatedAt'] as String,
        audio: json['audio'] as String?,
        cues: _mapList(json['cues'], AudioCue.fromJson),
        lines: _mapList(json['lines'], ArticleLine.fromJson),
      );

  static Article parse(String body) =>
      Article.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

/// manifest.json 里的轻量条目，列表页只用这些字段。
class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.title,
    required this.titleZh,
    required this.stage,
    required this.week,
    required this.level,
    required this.type,
    this.scene,
    this.tags = const [],
    this.grammarModules = const [],
    this.vocabTopic,
    required this.updatedAt,
    required this.lineCount,
    required this.contentHash,
    required this.path,
  });

  final String id;
  final String title;
  final String titleZh;
  final String stage;
  final int week;
  final String level;
  final String type;
  final String? scene;
  final List<String> tags;
  final List<String> grammarModules;
  final String? vocabTopic;
  final String updatedAt;
  final int lineCount;

  /// 内容指纹，变了才需要重新拉正文。
  final String contentHash;
  final String path;

  factory ArticleSummary.fromJson(Map<String, dynamic> json) => ArticleSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        titleZh: json['titleZh'] as String,
        stage: json['stage'] as String? ?? '',
        week: (json['week'] as num?)?.toInt() ?? 0,
        level: json['level'] as String? ?? '',
        type: json['type'] as String? ?? 'article',
        scene: json['scene'] as String?,
        tags: _stringList(json['tags']),
        grammarModules: _stringList(json['grammarModules']),
        vocabTopic: json['vocabTopic'] as String?,
        updatedAt: json['updatedAt'] as String? ?? '',
        lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
        contentHash: json['contentHash'] as String? ?? '',
        path: json['path'] as String? ?? 'articles/${json['id']}.json',
      );
}

class ContentManifest {
  const ContentManifest({required this.articles});

  final List<ArticleSummary> articles;

  factory ContentManifest.parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return ContentManifest(
      articles: _mapList(json['articles'], ArticleSummary.fromJson),
    );
  }
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList(growable: false);
}
