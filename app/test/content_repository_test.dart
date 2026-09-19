import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja/data/local/app_database.dart';
import 'package:ja/data/remote/content_api.dart';
import 'package:ja/data/repository/content_repository.dart';

const _manifestBody = '''
{"schemaVersion":1,"generatedAt":"2026-09-19T00:00:00Z","count":1,"articles":[
{"id":"W01-x","title":"テスト","titleZh":"测试","stage":"P0","week":1,"level":"N5",
 "type":"article","updatedAt":"2026-09-19","lineCount":1,"contentHash":"abc","path":"articles/W01-x.json"}]}
''';

/// 一个可控的假内容源：能数请求次数、能按需返回 304、能整个下线。
class _FakeServer {
  late HttpServer _server;
  int requestCount = 0;
  bool offline = false;
  String body = _manifestBody;
  String etag = '"v1"';

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      requestCount++;
      if (offline) {
        await request.response.close();
        return;
      }
      final ifNoneMatch = request.headers.value('if-none-match');
      request.response.headers.set('etag', etag);
      if (ifNoneMatch == etag) {
        request.response.statusCode = HttpStatus.notModified;
      } else {
        request.response.write(body);
      }
      await request.response.close();
    });
    return 'http://127.0.0.1:${_server.port}/';
  }

  Future<void> stop() => _server.close(force: true);
}

// 注意：这个 suite 故意不初始化 TestWidgetsFlutterBinding。
// 一旦初始化，flutter_test 会把所有 HttpClient 请求短路成 400，假服务就形同虚设。
void main() {
  late _FakeServer server;
  late AppDatabase db;
  late ContentRepository repo;

  setUp(() async {
    server = _FakeServer();
    final url = await server.start();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ContentRepository(ContentApi(() => url), db);
  });

  tearDown(() async {
    await db.close();
    await server.stop();
  });

  test('首次拉取来自网络并落库', () async {
    final result = await repo.loadManifest();
    expect(result.origin, ContentOrigin.network);
    expect(result.data.articles.single.id, 'W01-x');

    final stats = await repo.cacheStats();
    expect(stats.approxBytes, greaterThan(0));
  });

  test('内容没变时服务端回 304，走缓存', () async {
    await repo.loadManifest();
    final second = await repo.loadManifest();

    expect(server.requestCount, 2);
    expect(second.origin, ContentOrigin.cache);
    expect(second.networkError, isNull, reason: '304 不是错误，不该提示离线');
    expect(second.data.articles.single.titleZh, '测试');
  });

  test('断网时回落到缓存并带上原因', () async {
    await repo.loadManifest();
    server.offline = true;

    final offlineResult = await repo.loadManifest();
    expect(offlineResult.origin, ContentOrigin.cache);
    expect(offlineResult.isStale, isTrue);
    expect(offlineResult.data.articles, hasLength(1));
  });

  test('没有缓存又拉不到时抛错，不返回空列表', () async {
    server.offline = true;
    expect(repo.loadManifest(), throwsA(isA<Exception>()));
  });

  test('清除缓存后统计归零', () async {
    await repo.loadManifest();
    await repo.clearCache();
    final stats = await repo.cacheStats();
    expect(stats.articleCount, 0);
    expect(stats.approxBytes, 0);
  });
}
