import 'package:dio/dio.dart';

import '../../app/app_config.dart';

/// 一次远端读取的结果。[notModified] 为 true 时 [body] 为空，直接用缓存。
class RemoteDocument {
  const RemoteDocument({this.body, this.etag, this.notModified = false});

  final String? body;
  final String? etag;
  final bool notModified;
}

class ContentFetchException implements Exception {
  ContentFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 从 GitHub Pages 拉静态 JSON。用 If-None-Match 做条件请求，
/// 内容没变时服务端回 304，省流量也省解析。
class ContentApi {
  /// 只依赖「当前内容源地址」这一件事，方便在测试里指向本地假服务。
  ContentApi(this._baseUrl)
      : _dio = Dio(
          BaseOptions(
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            responseType: ResponseType.plain,
            // 304 不是异常，交给业务层判断
            validateStatus: (status) =>
                status != null && (status == 304 || (status >= 200 && status < 300)),
          ),
        );

  final Dio _dio;
  final String Function() _baseUrl;

  Uri _resolve(String path) {
    final base = _baseUrl().trim();
    final normalized = base.endsWith('/') ? base : '$base/';
    return Uri.parse(normalized).resolve(path);
  }

  Future<RemoteDocument> fetch(String path, {String? etag}) async {
    final url = _resolve(path).toString();
    try {
      final response = await _dio.get<String>(
        url,
        options: Options(
          headers: {
            if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
          },
        ),
      );

      if (response.statusCode == 304) {
        return RemoteDocument(
          etag: etag,
          notModified: true,
        );
      }

      final body = response.data;
      if (body == null || body.isEmpty) {
        throw ContentFetchException('内容源返回了空响应：$url');
      }
      return RemoteDocument(
        body: body,
        etag: response.headers.value('etag') ?? etag,
      );
    } on DioException catch (e) {
      throw ContentFetchException(_describe(e, url));
    }
  }

  String _describe(DioException e, String url) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return '连接内容源超时，请检查网络';
      case DioExceptionType.connectionError:
        return '无法连接内容源，请检查网络';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) {
          return '内容源上没有这个文件（404）：$url\n如果刚改过仓库结构，等 Actions 发布完再试';
        }
        return '内容源返回了 $code';
      default:
        return '拉取内容失败：${e.message ?? e.type.name}';
    }
  }
}
