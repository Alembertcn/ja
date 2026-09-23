import 'dart:convert';

/// 学习计划周次摘要（列表用）。
class PlanWeekSummary {
  const PlanWeekSummary({
    required this.id,
    required this.stage,
    required this.week,
    required this.title,
    required this.modules,
    required this.deliverable,
    this.detailPath,
    this.articleIds = const [],
    this.lessonPath,
    this.practicePath,
  });

  final String id;
  final String stage;
  final int week;
  final String title;
  final List<String> modules;
  final String deliverable;
  final String? detailPath;
  final List<String> articleIds;
  final String? lessonPath;
  final String? practicePath;

  bool get hasDetail => detailPath != null && detailPath!.isNotEmpty;

  factory PlanWeekSummary.fromJson(Map<String, dynamic> json) => PlanWeekSummary(
        id: json['id'] as String,
        stage: json['stage'] as String? ?? '',
        week: (json['week'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        modules: _stringList(json['modules']),
        deliverable: json['deliverable'] as String? ?? '',
        detailPath: json['detailPath'] as String?,
        articleIds: _articleIds(json),
        lessonPath: json['lessonPath'] as String?,
        practicePath: json['practicePath'] as String?,
      );
}

class PlanCatalog {
  const PlanCatalog({
    required this.title,
    required this.target,
    required this.weeks,
  });

  final String title;
  final String target;
  final List<PlanWeekSummary> weeks;

  factory PlanCatalog.parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return PlanCatalog(
      title: json['title'] as String? ?? '学习计划',
      target: json['target'] as String? ?? '',
      weeks: _mapList(json['weeks'], PlanWeekSummary.fromJson),
    );
  }
}

class PlanDay {
  const PlanDay({
    required this.day,
    required this.focus,
    required this.tasks,
  });

  final int day;
  final String focus;
  final String tasks;

  factory PlanDay.fromJson(Map<String, dynamic> json) => PlanDay(
        day: (json['day'] as num).toInt(),
        focus: json['focus'] as String? ?? '',
        tasks: json['tasks'] as String? ?? '',
      );
}

class PlanTopic {
  const PlanTopic({
    required this.id,
    required this.title,
    required this.points,
  });

  final String id;
  final String title;
  final List<String> points;

  factory PlanTopic.fromJson(Map<String, dynamic> json) => PlanTopic(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        points: _stringList(json['points']),
      );
}

/// 单周详情（有独立 JSON 时）。
class PlanWeekDetail {
  const PlanWeekDetail({
    required this.id,
    required this.stage,
    required this.week,
    required this.title,
    required this.modules,
    required this.goal,
    this.hoursHint,
    this.articleIds = const [],
    this.lessonPath,
    this.practicePath,
    this.days = const [],
    this.deliverables = const [],
    this.topics = const [],
  });

  final String id;
  final String stage;
  final int week;
  final String title;
  final List<String> modules;
  final String goal;
  final String? hoursHint;
  final List<String> articleIds;
  final String? lessonPath;
  final String? practicePath;
  final List<PlanDay> days;
  final List<String> deliverables;
  final List<PlanTopic> topics;

  factory PlanWeekDetail.parse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return PlanWeekDetail.fromJson(json);
  }

  factory PlanWeekDetail.fromJson(Map<String, dynamic> json) => PlanWeekDetail(
        id: json['id'] as String,
        stage: json['stage'] as String? ?? '',
        week: (json['week'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        modules: _stringList(json['modules']),
        goal: json['goal'] as String? ?? '',
        hoursHint: json['hoursHint'] as String?,
        articleIds: _articleIds(json),
        lessonPath: json['lessonPath'] as String?,
        practicePath: json['practicePath'] as String?,
        days: _mapList(json['days'], PlanDay.fromJson),
        deliverables: _stringList(json['deliverables']),
        topics: _mapList(json['topics'], PlanTopic.fromJson),
      );

  /// 仅有列表摘要、尚无独立详情文件时的占位详情。
  factory PlanWeekDetail.fromSummary(PlanWeekSummary summary) => PlanWeekDetail(
        id: summary.id,
        stage: summary.stage,
        week: summary.week,
        title: summary.title,
        modules: summary.modules,
        goal: summary.deliverable,
        articleIds: summary.articleIds,
        lessonPath: summary.lessonPath,
        practicePath: summary.practicePath,
        deliverables: summary.deliverable.isEmpty ? const [] : [summary.deliverable],
      );
}

List<T> _mapList<T>(Object? raw, T Function(Map<String, dynamic>) fromJson) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => fromJson(Map<String, dynamic>.from(e)))
      .toList(growable: false);
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

/// 支持 `articleIds: [...]`，兼容旧字段 `articleId`。
List<String> _articleIds(Map<String, dynamic> json) {
  final fromList = _stringList(json['articleIds']);
  if (fromList.isNotEmpty) return fromList;
  final single = json['articleId'];
  if (single is String && single.isNotEmpty) return [single];
  return const [];
}
