import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/article.dart';
import 'audio_cache_service.dart';
import 'settings_service.dart';
import 'tts_service.dart';

enum PlaybackSource {
  none,

  /// 播的是仓库里预生成的 mp3
  audio,

  /// 播的是设备系统 TTS
  tts,
}

/// 统一的朗读入口：有预生成音频就播音频，没有或下载失败才回落系统 TTS。
///
/// 这样即使手机上一个 TTS 引擎都没装（国行 ROM 很常见），课文照样能听。
class PlaybackService extends GetxService {
  PlaybackService(this._tts, this._cache, this._settings);

  final TtsService _tts;
  final AudioCacheService _cache;
  final SettingsService _settings;
  final AudioPlayer _player = AudioPlayer();

  final RxnString currentLineId = RxnString();
  final RxBool isPlaying = false.obs;

  /// 最近一次实际用的音源，界面可以据此提示用户现在听的是哪种声音。
  final Rx<PlaybackSource> lastSource = PlaybackSource.none.obs;

  /// 每次开始新播放都自增，进行中的旧循环靠它自行退出。
  int _token = 0;

  /// 设备既没有日语 TTS、这句又没有音频时，播了也是白播。
  bool canPlay(ArticleLine line) =>
      _hasAudio(line) || _tts.japaneseAvailable.value;

  bool _hasAudio(ArticleLine line) =>
      _settings.preferGeneratedAudio.value &&
      line.audio != null &&
      line.audio!.isNotEmpty;

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
    await _speakOne(line, token);
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
      await _speakOne(line, token);
      if (token != _token) return;
      await Future<void>.delayed(gap);
    }
    if (token == _token) _clear();
  }

  Future<void> _speakOne(ArticleLine line, int token) async {
    if (_hasAudio(line)) {
      final file = await _cache.resolve(line.audio!);
      if (token != _token) return;
      if (file != null) {
        try {
          await _player.setFilePath(file.path);
          await _player.setSpeed(_settings.speechSpeed.value);
          if (token != _token) return;
          lastSource.value = PlaybackSource.audio;
          // play() 的 Future 在这一条播完后才完成
          await _player.play();
          await _player.stop();
          return;
        } catch (e) {
          debugPrint('音频播放失败，回落 TTS：$e');
        }
      }
    }

    if (token != _token) return;
    lastSource.value = PlaybackSource.tts;
    await _tts.speak(line.jp);
  }

  /// 「我的」页面里的试听，不占用逐行播放状态。
  Future<void> previewTts(String text) async {
    await stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    _token++;
    await Future.wait([
      _player.stop().catchError((_) {}),
      _tts.stop(),
    ]);
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
