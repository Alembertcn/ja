import 'package:flutter/foundation.dart';

import '../../app/app_config.dart';
import '../local/app_database.dart';
import '../models/article.dart';
import '../models/plan.dart';
import '../remote/content_api.dart';

/// 数据来源，用于在界面上如实告诉用户看到的是不是离线内容。
enum ContentOrigin {
  /// 刚从网上拉到的新内容
  network,

  /// 服务端说没变，或网络失败后回落，总之来自本地缓存
  cache,
}

class ContentResult<T> {
  const ContentResult({
    required this.data,
    required this.origin,
    this.networkError,
  });

  final T data;
  final ContentOrigin origin;

  /// 回落到缓存时，导致回落的网络错误。界面可据此提示。
  final String? networkError;

  bool get isStale => origin == ContentOrigin.cache && networkError != null;
}

const String _manifestKey = 'manifest';
const String _planWeeksKey = 'plan:weeks';

String _articleKey(String id) => 'article:$id';
String _planWeekKey(String id) => 'plan:week:$id';
String _lessonKey(String path) => 'lesson:$path';

/// 远端优先、离线回落。任何网络问题都不应该让已经缓存过的课文读不了。
class ContentRepository {
  ContentRepository(this._api, this._db);

  final ContentApi _api;
  final AppDatabase _db;

  Future<ContentResult<ContentManifest>> loadManifest({
    bool forceRefresh = false,
  }) async {
    return _load(
      key: _manifestKey,
      path: AppConfig.manifestPath,
      forceRefresh: forceRefresh,
      parse: ContentManifest.parse,
    );
  }

  Future<ContentResult<Article>> loadArticle(
    ArticleSummary summary, {
    bool forceRefresh = false,
  }) async {
    return _load(
      key: _articleKey(summary.id),
      path: summary.path,
      forceRefresh: forceRefresh,
      parse: Article.parse,
    );
  }

  Future<ContentResult<PlanCatalog>> loadPlanWeeks({
    bool forceRefresh = false,
  }) async {
    return _load(
      key: _planWeeksKey,
      path: 'plan/weeks.json',
      forceRefresh: forceRefresh,
      parse: PlanCatalog.parse,
    );
  }

  Future<ContentResult<PlanWeekDetail>> loadPlanWeek(
    PlanWeekSummary summary, {
    bool forceRefresh = false,
  }) async {
    final path = summary.detailPath;
    if (path == null || path.isEmpty) {
      return ContentResult(
        data: PlanWeekDetail.fromSummary(summary),
        origin: ContentOrigin.cache,
      );
    }
    return _load(
      key: _planWeekKey(summary.id),
      path: path,
      forceRefresh: forceRefresh,
      parse: PlanWeekDetail.parse,
    );
  }

  /// 拉取精讲笔记 Markdown（发布在内容源 lessons/ 下）。
  Future<ContentResult<String>> loadLesson(
    String lessonPath, {
    bool forceRefresh = false,
  }) {
    return _load(
      key: _lessonKey(lessonPath),
      path: lessonPath,
      forceRefresh: forceRefresh,
      parse: (body) => body,
    );
  }

  Future<ContentResult<T>> _load<T>({
    required String key,
    required String path,
    required bool forceRefresh,
    required T Function(String body) parse,
  }) async {
    final cached = await _db.readDocument(key);

    try {
      final remote = await _api.fetch(
        path,
        etag: forceRefresh ? null : cached?.etag,
      );

      if (remote.notModified && cached != null) {
        await _db.touchDocument(key, remote.etag ?? cached.etag);
        return ContentResult(
          data: parse(cached.body),
          origin: ContentOrigin.cache,
        );
      }

      final body = remote.body;
      if (body != null) {
        // 先解析再落库，坏内容不污染缓存
        final parsed = parse(body);
        await _db.writeDocument(key, body, remote.etag);
        return ContentResult(
          data: parsed,
          origin: ContentOrigin.network,
        );
      }

      throw ContentFetchException('内容源没有返回内容，且本地没有缓存');
    } catch (error, stack) {
      if (cached != null) {
        debugPrint('拉取 $path 失败，回落缓存：$error');
        return ContentResult(
          data: parse(cached.body),
          origin: ContentOrigin.cache,
          networkError: _message(error),
        );
      }
      debugPrintStack(stackTrace: stack, label: '拉取 $path 失败且无缓存');
      rethrow;
    }
  }

  Future<CacheStats> cacheStats() async {
    final docs = await _db.allDocuments();
    var bytes = 0;
    var articles = 0;
    DateTime? latest;
    for (final doc in docs) {
      bytes += doc.body.length;
      if (doc.key.startsWith('article:')) articles++;
      if (latest == null || doc.fetchedAt.isAfter(latest)) {
        latest = doc.fetchedAt;
      }
    }
    return CacheStats(
      articleCount: articles,
      approxBytes: bytes,
      lastFetchedAt: latest,
    );
  }

  Future<void> clearCache() => _db.clearAll();

  String _message(Object error) =>
      error is ContentFetchException ? error.message : error.toString();
}

class CacheStats {
  const CacheStats({
    required this.articleCount,
    required this.approxBytes,
    this.lastFetchedAt,
  });

  final int articleCount;

  /// JSON 字符长度的近似值，够用来给用户一个量级概念。
  final int approxBytes;
  final DateTime? lastFetchedAt;

  String get readableSize {
    if (approxBytes < 1024) return '$approxBytes B';
    if (approxBytes < 1024 * 1024) {
      return '${(approxBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(approxBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
