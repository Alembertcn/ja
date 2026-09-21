import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../data/remote/content_api.dart';

/// 音频的本地缓存。首次播放时下载，之后完全离线可用。
///
/// 目录结构与内容源一致（`audio/<课文 id>/article.mp3`、`audio/words/<hash>.mp3`）。
class AudioCacheService {
  AudioCacheService(this._api);

  final ContentApi _api;
  late final Directory _root;

  /// 同一个文件被并发请求时只下载一次。
  final Map<String, Future<File?>> _inFlight = {};

  Future<AudioCacheService> init() async {
    final base = await getApplicationSupportDirectory();
    _root = Directory('${base.path}/audio');
    await _root.create(recursive: true);
    return this;
  }

  File _fileFor(String relativePath) => File('${_root.path}/$relativePath');

  /// 取音频文件，本地没有就下载。拿不到返回 null。
  Future<File?> resolve(String relativePath) {
    final existing = _fileFor(relativePath);
    if (existing.existsSync()) return Future.value(existing);

    return _inFlight.putIfAbsent(relativePath, () async {
      try {
        final target = _fileFor(relativePath);
        await _api.download(relativePath, target);
        return target;
      } catch (e) {
        debugPrint('音频下载失败 $relativePath：$e');
        return null;
      } finally {
        _inFlight.remove(relativePath);
      }
    });
  }

  /// 整篇预下载，供「离线备课」用。返回成功的条数。
  Future<int> prefetch(Iterable<String> relativePaths) async {
    var ok = 0;
    for (final path in relativePaths) {
      if (await resolve(path) != null) ok++;
    }
    return ok;
  }

  Future<({int files, int bytes})> stats() async {
    if (!await _root.exists()) return (files: 0, bytes: 0);
    var files = 0;
    var bytes = 0;
    await for (final entity in _root.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.mp3')) {
        files++;
        bytes += await entity.length();
      }
    }
    return (files: files, bytes: bytes);
  }

  Future<void> clear() async {
    if (await _root.exists()) {
      await _root.delete(recursive: true);
    }
    await _root.create(recursive: true);
  }
}
