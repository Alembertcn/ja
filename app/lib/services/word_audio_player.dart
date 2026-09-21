import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_cache_service.dart';
import 'playback_cubit.dart';

/// 精讲笔记词表点读。预生成 edge-tts mp3，路径与 tools/lesson_vocab.py 一致。
class WordAudioPlayer {
  WordAudioPlayer(this._cache, this._playback);

  final AudioCacheService _cache;
  final PlaybackCubit _playback;
  final AudioPlayer _player = AudioPlayer();

  static const voice = 'ja-JP-NanamiNeural';
  static const rate = '-10%';
  static const linkScheme = 'ja-word:';

  static String textKey(
    String text, {
    String voice = WordAudioPlayer.voice,
    String rate = WordAudioPlayer.rate,
  }) {
    final raw = utf8.encode('$text\u0000$voice\u0000$rate');
    return sha256.convert(raw).toString().substring(0, 16);
  }

  static String relativePathFor(String speakText) =>
      'audio/words/${textKey(speakText)}.mp3';

  /// 解析 `ja-word:` 链接并播放；非本 scheme 返回 false。
  Future<bool> playFromHref(String? href) async {
    if (href == null || !href.startsWith(linkScheme)) return false;
    final encoded = href.substring(linkScheme.length);
    final text = Uri.decodeComponent(encoded);
    if (text.isEmpty) return false;
    await playText(text);
    return true;
  }

  Future<void> playText(String speakText) async {
    final path = relativePathFor(speakText);
    await _playback.pauseIfPlaying();
    final file = await _cache.resolve(path);
    if (file == null) {
      debugPrint('词音频不可用 $path（$speakText）');
      return;
    }
    try {
      await _player.stop();
      await _player.setFilePath(file.path);
      unawaited(_player.play());
    } catch (e) {
      debugPrint('词音频播放失败 $path：$e');
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
