import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../app/app_config.dart';

/// 展开后原文上方那行注音的形式。
enum AnnotationStyle {
  kana('假名'),
  romaji('罗马音'),
  none('不显示');

  const AnnotationStyle(this.label);

  final String label;
}

/// 用户设置。全部落在 GetStorage，同步读写，界面直接 Obx 绑定。
class SettingsService extends GetxService {
  static const _kSpeechSpeed = 'speech_speed';
  static const _kAnnotation = 'annotation_style';
  static const _kInlineFurigana = 'inline_furigana';
  static const _kFontScale = 'font_scale';
  static const _kExpandSingle = 'expand_single';
  static const _kBaseUrl = 'content_base_url';

  final _box = GetStorage();

  /// 相对正常语速的倍率，1.0 为正常。学习场景默认放慢一点。
  late final RxDouble speechSpeed =
      (_box.read<double>(_kSpeechSpeed) ?? 0.8).obs;

  late final Rx<AnnotationStyle> annotationStyle = _readAnnotation().obs;

  /// 是否在汉字上方叠加 ruby 注音。
  late final RxBool inlineFurigana =
      (_box.read<bool>(_kInlineFurigana) ?? true).obs;

  late final RxDouble fontScale = (_box.read<double>(_kFontScale) ?? 1.0).obs;

  /// true 表示同时只展开一行，false 允许多行同时展开。
  late final RxBool expandSingle = (_box.read<bool>(_kExpandSingle) ?? true).obs;

  late final RxString contentBaseUrlRx =
      (_box.read<String>(_kBaseUrl) ?? AppConfig.defaultContentBaseUrl).obs;

  String get contentBaseUrl => contentBaseUrlRx.value;

  AnnotationStyle _readAnnotation() {
    final raw = _box.read<String>(_kAnnotation);
    return AnnotationStyle.values.firstWhere(
      (style) => style.name == raw,
      orElse: () => AnnotationStyle.kana,
    );
  }

  void setSpeechSpeed(double value) {
    final clamped = value.clamp(0.5, 1.5).toDouble();
    speechSpeed.value = clamped;
    _box.write(_kSpeechSpeed, clamped);
  }

  void setAnnotationStyle(AnnotationStyle style) {
    annotationStyle.value = style;
    _box.write(_kAnnotation, style.name);
  }

  void setInlineFurigana(bool value) {
    inlineFurigana.value = value;
    _box.write(_kInlineFurigana, value);
  }

  void setFontScale(double value) {
    final clamped = value.clamp(0.8, 1.6).toDouble();
    fontScale.value = clamped;
    _box.write(_kFontScale, clamped);
  }

  void setExpandSingle(bool value) {
    expandSingle.value = value;
    _box.write(_kExpandSingle, value);
  }

  void setContentBaseUrl(String value) {
    final trimmed = value.trim();
    final url = trimmed.isEmpty ? AppConfig.defaultContentBaseUrl : trimmed;
    contentBaseUrlRx.value = url;
    _box.write(_kBaseUrl, url);
  }

  void resetContentBaseUrl() => setContentBaseUrl(AppConfig.defaultContentBaseUrl);
}
