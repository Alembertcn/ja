import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// 远端文档的本地缓存。manifest 与每篇课文共用一张表：
/// key 为 `manifest` 或 `article:<id>`，etag 用于下次请求做条件 GET。
class CachedDocuments extends Table {
  TextColumn get key => text()();
  TextColumn get body => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CachedDocuments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'ja_cache'));

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<CachedDocument?> readDocument(String key) {
    return (select(cachedDocuments)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
  }

  Future<void> writeDocument(String key, String body, String? etag) {
    return into(cachedDocuments).insertOnConflictUpdate(
      CachedDocumentsCompanion.insert(
        key: key,
        body: body,
        etag: Value(etag),
        fetchedAt: DateTime.now(),
      ),
    );
  }

  /// 只更新 etag 与时间戳，用于服务端返回 304 的情况。
  Future<void> touchDocument(String key, String? etag) {
    return (update(cachedDocuments)..where((t) => t.key.equals(key))).write(
      CachedDocumentsCompanion(
        etag: Value(etag),
        fetchedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<CachedDocument>> allDocuments() => select(cachedDocuments).get();

  Future<int> clearAll() => delete(cachedDocuments).go();
}
