import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:get/get.dart';

import 'settings_service.dart';

/// 系统 TTS 朗读。只负责「把一句话读出来」这一件事，
/// 播放到第几行、是否在播这类状态由 [PlaybackService] 统管，避免两处各记一份。
///
/// 语速在两端的含义不同：iOS 的 0.5 约等于正常语速，Android 的 1.0 才是，
/// 所以对外统一用倍率，进引擎前按平台换算。
class TtsService extends GetxService {
  TtsService(this._settings);

  static const String _language = 'ja-JP';

  final SettingsService _settings;
  final FlutterTts _tts = FlutterTts();

  /// 设备上是否装了日语语音。Android 常见缺失，需要引导用户去装。
  final RxBool japaneseAvailable = true.obs;
  final RxnString initError = RxnString();

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

      _tts.setErrorHandler((message) => debugPrint('TTS 出错：$message'));
    } catch (e) {
      initError.value = '朗读引擎初始化失败：$e';
      japaneseAvailable.value = false;
      debugPrint(initError.value!);
    }

    ever<double>(_settings.speechSpeed, _applySpeed);
    return this;
  }

  Future<void> _applySpeed(double speed) async {
    final rate = Platform.isIOS ? speed * 0.5 : speed;
    try {
      await _tts.setSpeechRate(rate.clamp(0.1, 1.5));
    } catch (e) {
      debugPrint('设置语速失败：$e');
    }
  }

  /// 读一句，Future 在读完后才完成。
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('朗读失败：$e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // 引擎没在播时 stop 可能抛错，忽略即可
    }
  }

  @override
  void onClose() {
    _tts.stop();
    super.onClose();
  }
}
