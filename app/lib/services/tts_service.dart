import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import 'settings_service.dart';

class SpeakItem {
  const SpeakItem(this.lineId, this.text);

  final String lineId;
  final String text;
}

/// 日语朗读。全局常驻，避免每次进详情页都重新初始化引擎。
///
/// 语速在两端的含义不同：iOS 的 0.5 约等于正常语速，Android 的 1.0 才是正常，
/// 所以对外统一用「倍率」，进引擎前按平台换算。
class TtsService extends GetxService {
  TtsService(this._settings);

  static const String _language = 'ja-JP';

  final SettingsService _settings;
  final FlutterTts _tts = FlutterTts();

  final RxnString currentLineId = RxnString();
  final RxBool isSpeaking = false.obs;

  /// 设备上是否装了日语语音。Android 常见缺失，需要引导用户去装。
  final RxBool japaneseAvailable = true.obs;
  final RxnString initError = RxnString();

  /// 每次开始新的播放都自增，老的播放循环靠它自行退出。
  int _token = 0;

  Future<TtsService> init() async {
    try {
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
      }
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage(_language);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _applySpeed(_settings.speechSpeed.value);

      final available = await _tts.isLanguageAvailable(_language);
      japaneseAvailable.value = available == true || available == 1;

      _tts.setCancelHandler(_clear);
      _tts.setErrorHandler((message) {
        debugPrint('TTS 出错：$message');
        _clear();
      });
    } catch (e) {
      initError.value = '朗读引擎初始化失败：$e';
      debugPrint(initError.value!);
    }

    // 设置里改语速后立即生效
    ever<double>(_settings.speechSpeed, _applySpeed);
    return this;
  }

  Future<void> _applySpeed(double speed) async {
    final rate = Platform.isIOS ? speed * 0.5 : speed;
    await _tts.setSpeechRate(rate.clamp(0.1, 1.5));
  }

  Future<void> speakLine(String lineId, String text) async {
    if (currentLineId.value == lineId && isSpeaking.value) {
      await stop();
      return;
    }
    await stop();
    final token = ++_token;
    currentLineId.value = lineId;
    isSpeaking.value = true;
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('朗读失败：$e');
    }
    if (token == _token) _clear();
  }

  /// 连续朗读整篇。句间留一点间隔，跟读时不至于赶。
  Future<void> speakAll(
    List<SpeakItem> items, {
    Duration gap = const Duration(milliseconds: 350),
  }) async {
    await stop();
    final token = ++_token;
    isSpeaking.value = true;
    for (final item in items) {
      if (token != _token) return;
      currentLineId.value = item.lineId;
      try {
        await _tts.speak(item.text);
      } catch (e) {
        debugPrint('朗读失败：$e');
        break;
      }
      if (token != _token) return;
      await Future<void>.delayed(gap);
    }
    if (token == _token) _clear();
  }

  Future<void> stop() async {
    _token++;
    try {
      await _tts.stop();
    } catch (_) {
      // 引擎没在播时 stop 可能抛错，忽略即可
    }
    _clear();
  }

  void _clear() {
    currentLineId.value = null;
    isSpeaking.value = false;
  }

  @override
  void onClose() {
    _tts.stop();
    super.onClose();
  }
}
