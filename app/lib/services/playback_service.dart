import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/article.dart';
import 'audio_cache_service.dart';
import 'settings_service.dart';

/// 逐句朗读。音频由 tools/tts.py 预先合成并随内容发布，客户端只管播。
///
/// 不用系统 TTS：手机上常常一个引擎都没装（国行 ROM 很常见），
/// 而且各家引擎的日语音质和语速语义都不一致，不如把声音固定在内容侧。
class PlaybackService extends GetxService {
  PlaybackService(this._cache, this._settings);

  final AudioCacheService _cache;
  final SettingsService _settings;
  final AudioPlayer _player = AudioPlayer();

  final RxnString currentLineId = RxnString();
  final RxBool isPlaying = false.obs;

  /// 每次开始新播放都自增，进行中的旧循环靠它自行退出。
  int _token = 0;

  Future<void> playLine(ArticleLine line) async {
    // 再点一次正在播的那句 = 停止
    if (currentLineId.value == line.id && isPlaying.value) {
      await stop();
      return;
    }
    await stop();
    final token = ++_token;
    currentLineId.value = line.id;
    isPlaying.value = true;
    await _playOne(line, token);
    if (token == _token) _clear();
  }

  Future<void> playAll(
    List<ArticleLine> lines, {
    Duration gap = const Duration(milliseconds: 350),
  }) async {
    await stop();
    final token = ++_token;
    isPlaying.value = true;
    for (final line in lines) {
      if (token != _token) return;
      currentLineId.value = line.id;
      await _playOne(line, token);
      if (token != _token) return;
      await Future<void>.delayed(gap);
    }
    if (token == _token) _clear();
  }

  Future<void> _playOne(ArticleLine line, int token) async {
    final path = line.audio;
    if (path == null || path.isEmpty) return;

    final file = await _cache.resolve(path);
    if (file == null || token != _token) return;

    try {
      await _player.setFilePath(file.path);
      await _player.setSpeed(_settings.speechSpeed.value);
      if (token != _token) return;
      // play() 的 Future 在这一条播完后才完成
      await _player.play();
      await _player.stop();
    } catch (e) {
      debugPrint('音频播放失败 $path：$e');
    }
  }

  Future<void> stop() async {
    _token++;
    try {
      await _player.stop();
    } catch (_) {
      // 没在播时 stop 可能抛错，忽略
    }
    _clear();
  }

  void _clear() {
    currentLineId.value = null;
    isPlaying.value = false;
  }

  @override
  void onClose() {
    _player.dispose();
    super.onClose();
  }
}
