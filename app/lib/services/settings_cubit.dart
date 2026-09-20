import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

/// 朗读循环模式。
enum PlaybackLoopMode {
  none('不循环'),
  single('单句'),
  article('单篇');

  const PlaybackLoopMode(this.label);

  final String label;
}

class SettingsState extends Equatable {
  const SettingsState({
    required this.speechSpeed,
    required this.annotationStyle,
    required this.loopMode,
    required this.inlineFurigana,
    required this.fontScale,
    required this.expandSingle,
    required this.contentBaseUrl,
  });

  final double speechSpeed;
  final AnnotationStyle annotationStyle;
  final PlaybackLoopMode loopMode;
  final bool inlineFurigana;
  final double fontScale;
  final bool expandSingle;
  final String contentBaseUrl;

  SettingsState copyWith({
    double? speechSpeed,
    AnnotationStyle? annotationStyle,
    PlaybackLoopMode? loopMode,
    bool? inlineFurigana,
    double? fontScale,
    bool? expandSingle,
    String? contentBaseUrl,
  }) {
    return SettingsState(
      speechSpeed: speechSpeed ?? this.speechSpeed,
      annotationStyle: annotationStyle ?? this.annotationStyle,
      loopMode: loopMode ?? this.loopMode,
      inlineFurigana: inlineFurigana ?? this.inlineFurigana,
      fontScale: fontScale ?? this.fontScale,
      expandSingle: expandSingle ?? this.expandSingle,
      contentBaseUrl: contentBaseUrl ?? this.contentBaseUrl,
    );
  }

  @override
  List<Object?> get props => [
        speechSpeed,
        annotationStyle,
        loopMode,
        inlineFurigana,
        fontScale,
        expandSingle,
        contentBaseUrl,
      ];
}

/// 用户设置。持久化在 GetStorage，UI 用 BlocBuilder 订阅。
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit() : super(_loadInitial());

  static const _kSpeechSpeed = 'speech_speed';
  static const _kAnnotation = 'annotation_style';
  static const _kInlineFurigana = 'inline_furigana';
  static const _kFontScale = 'font_scale';
  static const _kExpandSingle = 'expand_single';
  static const _kBaseUrl = 'content_base_url';
  static const _kLoopMode = 'loop_mode';

  final _box = GetStorage();

  static SettingsState _loadInitial() {
    final box = GetStorage();
    return SettingsState(
      speechSpeed: box.read<double>(_kSpeechSpeed) ?? 0.8,
      annotationStyle: _readAnnotation(box),
      loopMode: _readLoopMode(box),
      inlineFurigana: box.read<bool>(_kInlineFurigana) ?? true,
      fontScale: box.read<double>(_kFontScale) ?? 1.0,
      expandSingle: box.read<bool>(_kExpandSingle) ?? true,
      contentBaseUrl:
          box.read<String>(_kBaseUrl) ?? AppConfig.defaultContentBaseUrl,
    );
  }

  static AnnotationStyle _readAnnotation(GetStorage box) {
    final raw = box.read<String>(_kAnnotation);
    return AnnotationStyle.values.firstWhere(
      (style) => style.name == raw,
      orElse: () => AnnotationStyle.kana,
    );
  }

  static PlaybackLoopMode _readLoopMode(GetStorage box) {
    final raw = box.read<String>(_kLoopMode);
    return PlaybackLoopMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PlaybackLoopMode.none,
    );
  }

  String get contentBaseUrl => state.contentBaseUrl;

  void setSpeechSpeed(double value) {
    final clamped = value.clamp(0.5, 1.5).toDouble();
    emit(state.copyWith(speechSpeed: clamped));
    _box.write(_kSpeechSpeed, clamped);
  }

  void setLoopMode(PlaybackLoopMode mode) {
    emit(state.copyWith(loopMode: mode));
    _box.write(_kLoopMode, mode.name);
  }

  void setAnnotationStyle(AnnotationStyle style) {
    emit(state.copyWith(annotationStyle: style));
    _box.write(_kAnnotation, style.name);
  }

  void setInlineFurigana(bool value) {
    emit(state.copyWith(inlineFurigana: value));
    _box.write(_kInlineFurigana, value);
  }

  void setFontScale(double value) {
    final clamped = value.clamp(0.8, 1.6).toDouble();
    emit(state.copyWith(fontScale: clamped));
    _box.write(_kFontScale, clamped);
  }

  void setExpandSingle(bool value) {
    emit(state.copyWith(expandSingle: value));
    _box.write(_kExpandSingle, value);
  }

  void setContentBaseUrl(String value) {
    final trimmed = value.trim();
    final url = trimmed.isEmpty ? AppConfig.defaultContentBaseUrl : trimmed;
    emit(state.copyWith(contentBaseUrl: url));
    _box.write(_kBaseUrl, url);
  }

  void resetContentBaseUrl() =>
      setContentBaseUrl(AppConfig.defaultContentBaseUrl);
}
