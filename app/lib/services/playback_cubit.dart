import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import '../data/models/article.dart';
import 'audio_cache_service.dart';
import 'settings_cubit.dart';

/// 当前正在播的课文上下文。
class PlayingArticle {
  const PlayingArticle({
    required this.summary,
    required this.lines,
    required this.audio,
    required this.cues,
  });

  final ArticleSummary summary;
  final List<ArticleLine> lines;
  final String audio;
  final List<AudioCue> cues;

  String get articleId => summary.id;
  String get titleZh => summary.titleZh;
  String get title => summary.title;
  int get week => summary.week;
  String get level => summary.level;

  factory PlayingArticle.fromArticle(ArticleSummary summary, Article article) {
    return PlayingArticle(
      summary: summary,
      lines: article.lines,
      audio: article.audio!,
      cues: article.cues,
    );
  }
}

class PlaybackState extends Equatable {
  const PlaybackState({
    this.current,
    this.index = 0,
    this.isPlaying = false,
    this.isPaused = false,
    this.currentLineId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final PlayingArticle? current;
  final int index;
  final bool isPlaying;
  final bool isPaused;
  final String? currentLineId;
  final Duration position;
  final Duration duration;

  PlaybackState copyWith({
    PlayingArticle? current,
    int? index,
    bool? isPlaying,
    bool? isPaused,
    String? currentLineId,
    Duration? position,
    Duration? duration,
    bool clearCurrent = false,
    bool clearLineId = false,
  }) {
    return PlaybackState(
      current: clearCurrent ? null : (current ?? this.current),
      index: index ?? this.index,
      isPlaying: isPlaying ?? this.isPlaying,
      isPaused: isPaused ?? this.isPaused,
      currentLineId: clearLineId ? null : (currentLineId ?? this.currentLineId),
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  @override
  List<Object?> get props => [
        current,
        index,
        isPlaying,
        isPaused,
        currentLineId,
        position,
        duration,
      ];
}

/// 整篇单文件朗读。用 cues 时间轴把 position 映射到当前句高亮。
class PlaybackCubit extends Cubit<PlaybackState> {
  PlaybackCubit(this._cache, this._settings) : super(const PlaybackState()) {
    _positionSub = _player.positionStream.listen(_onPosition);
    _durationSub = _player.durationStream.listen((value) {
      if (value != null) emit(state.copyWith(duration: value));
    });
    _stateSub = _player.playerStateStream.listen(_onPlayerState);
    _speedSub = _settings.stream.listen((settings) {
      if (state.current != null && !_jumping) {
        unawaited(_player.setSpeed(settings.speechSpeed));
      }
    });
  }

  final AudioCacheService _cache;
  final SettingsCubit _settings;
  final AudioPlayer _player = AudioPlayer();

  int _token = 0;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<SettingsState>? _speedSub;
  bool _handlingLoop = false;

  /// 正在跳到指定句：忽略旧 position 的 cue 映射。
  bool _jumping = false;

  /// 提前半个 gap 起播时，进度还在间隙里，钉住目标句高亮，避免判回上一句。
  int? _pinnedIndex;
  int? _pinUntilMs;

  void _onPosition(Duration value) {
    if (_jumping) {
      emit(state.copyWith(position: value));
      return;
    }
    final article = state.current;
    if (article == null || article.cues.isEmpty) {
      emit(state.copyWith(position: value));
      return;
    }

    if (_pinnedIndex != null && _pinUntilMs != null) {
      if (value.inMilliseconds < _pinUntilMs!) {
        final i = _pinnedIndex!.clamp(0, article.cues.length - 1);
        emit(state.copyWith(
          position: value,
          index: i,
          currentLineId: article.cues[i].id,
        ));
        return;
      }
      _pinnedIndex = null;
      _pinUntilMs = null;
    }

    final i = _cueIndexAt(value.inMilliseconds, article.cues);
    final id = article.cues[i].id;
    emit(state.copyWith(
      position: value,
      index: i,
      currentLineId: id,
    ));
  }

  /// 跳播落点：句首。cues 已与成品 mp3 对齐，不再做 half-gap 补偿。
  Duration _playHead(List<AudioCue> cues, int index) => cues[index].start;

  void _pinUntilCueStart(int index, AudioCue cue) {
    // 保留接口：若以后要做起音提前量，可再钉住高亮。
    _pinnedIndex = null;
    _pinUntilMs = null;
  }

  void _clearPin() {
    _pinnedIndex = null;
    _pinUntilMs = null;
  }

  int _cueIndexAt(int ms, List<AudioCue> cues) {
    var lo = 0;
    var hi = cues.length - 1;
    var ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].startMs <= ms) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  Future<void> _onPlayerState(PlayerState playerState) async {
    if (playerState.processingState != ProcessingState.completed) return;
    if (_handlingLoop || _jumping) return;
    final article = state.current;
    if (article == null) return;

    _handlingLoop = true;
    try {
      switch (_settings.state.loopMode) {
        case PlaybackLoopMode.single:
          final i = state.index.clamp(0, article.cues.length - 1);
          final cue = article.cues[i];
          final token = ++_token;
          _jumping = true;
          _pinUntilCueStart(i, cue);
          try {
            await _openAt(article.audio, _playHead(article.cues, i), token);
            if (token != _token) return;
            _jumping = false;
            unawaited(_player.play());
          } finally {
            if (token == _token) _jumping = false;
          }
        case PlaybackLoopMode.article:
          emit(state.copyWith(
            index: 0,
            currentLineId: article.cues.first.id,
          ));
          final token = ++_token;
          _jumping = true;
          _clearPin();
          try {
            await _openAt(article.audio, Duration.zero, token);
            if (token != _token) return;
            _jumping = false;
            unawaited(_player.play());
          } finally {
            if (token == _token) _jumping = false;
          }
        case PlaybackLoopMode.none:
          emit(state.copyWith(isPlaying: false, isPaused: false));
      }
    } finally {
      _handlingLoop = false;
    }
  }

  /// 打开音频并定位到 [at]。用 initialPosition，避免连播中 seek 被吞。
  Future<void> _openAt(String relativePath, Duration at, int token) async {
    final file = await _cache.resolve(relativePath);
    if (file == null) throw StateError('无法加载音频 $relativePath');
    if (token != _token) return;

    try {
      await _player.pause();
    } catch (_) {}
    if (token != _token) return;

    await _player.setFilePath(file.path, initialPosition: at);
    if (token != _token) return;

    await _player.setSpeed(_settings.state.speechSpeed);
    if (token != _token) return;

    // 再确认一次位置（部分机型 setFilePath 后仍停在 0）
    if ((_player.position - at).inMilliseconds.abs() > 120) {
      await _player.seek(at);
    }
  }

  Future<void> start(PlayingArticle article, {int fromIndex = 0}) async {
    if (article.audio.isEmpty || article.cues.isEmpty) return;
    final startIndex = fromIndex.clamp(0, article.cues.length - 1);
    final cue = article.cues[startIndex];
    final at = _playHead(article.cues, startIndex);

    final token = ++_token;
    _jumping = true;
    _pinUntilCueStart(startIndex, cue);
    emit(state.copyWith(
      current: article,
      index: startIndex,
      currentLineId: cue.id,
      isPaused: false,
      isPlaying: true,
      position: at,
    ));

    try {
      await _openAt(article.audio, at, token);
      if (token != _token) return;
      _jumping = false;
      unawaited(_player.play());
      debugPrint(
        'playback start ${cue.id} head=${at.inMilliseconds}ms '
        'cue=${cue.startMs}ms (pos=${_player.position.inMilliseconds})',
      );
    } catch (e) {
      debugPrint('音频播放失败 ${article.audio}：$e');
      if (token == _token) _clearSession();
    } finally {
      if (token == _token) _jumping = false;
    }
  }

  Future<void> togglePlayPause() async {
    if (state.current == null) return;
    if (state.isPlaying && !state.isPaused) {
      await _player.pause();
      emit(state.copyWith(isPaused: true, isPlaying: false));
      return;
    }
    if (state.isPaused) {
      emit(state.copyWith(isPaused: false, isPlaying: true));
      unawaited(_player.play());
      return;
    }
    // 已停在末尾：从当前句句首再开
    final article = state.current!;
    final token = ++_token;
    final i = state.index.clamp(0, article.cues.length - 1);
    final cue = article.cues[i];
    final at = _playHead(article.cues, i);
    _jumping = true;
    _pinUntilCueStart(i, cue);
    emit(state.copyWith(isPlaying: true, isPaused: false, position: at));
    try {
      await _openAt(article.audio, at, token);
      if (token != _token) return;
      _jumping = false;
      unawaited(_player.play());
    } catch (e) {
      debugPrint('恢复播放失败：$e');
    } finally {
      if (token == _token) _jumping = false;
    }
  }

  Future<void> next() async {
    final article = state.current;
    if (article == null) return;
    final nextIndex = state.index + 1;
    if (nextIndex >= article.cues.length) {
      if (_settings.state.loopMode == PlaybackLoopMode.article) {
        await _jumpTo(0);
      }
      return;
    }
    await _jumpTo(nextIndex);
  }

  Future<void> previous() async {
    final article = state.current;
    if (article == null) return;
    final prev = state.index - 1;
    await _jumpTo(prev < 0 ? 0 : prev);
  }

  Future<void> seek(Duration target) async {
    await _player.seek(target);
  }

  Future<void> _jumpTo(int target) async {
    final article = state.current;
    if (article == null) return;
    final i = target.clamp(0, article.cues.length - 1);
    final cue = article.cues[i];
    final at = _playHead(article.cues, i);
    final token = ++_token;
    _jumping = true;
    _pinUntilCueStart(i, cue);
    emit(state.copyWith(
      index: i,
      currentLineId: cue.id,
      isPaused: false,
      isPlaying: true,
      position: at,
    ));
    try {
      await _openAt(article.audio, at, token);
      if (token != _token) return;
      _jumping = false;
      unawaited(_player.play());
    } catch (e) {
      debugPrint('跳转播放失败：$e');
    } finally {
      if (token == _token) _jumping = false;
    }
  }

  Future<void> pauseIfPlaying() async {
    if (state.current == null) return;
    if (state.isPlaying && !state.isPaused) {
      await _player.pause();
      emit(state.copyWith(isPaused: true, isPlaying: false));
    }
  }

  Future<void> stop() async {
    _token++;
    _jumping = false;
    _clearPin();
    try {
      await _player.stop();
    } catch (_) {}
    _clearSession();
  }

  Future<void> dismiss() async {
    await stop();
  }

  void _clearSession() {
    _clearPin();
    emit(const PlaybackState());
  }

  @override
  Future<void> close() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _stateSub?.cancel();
    await _speedSub?.cancel();
    await _player.dispose();
    return super.close();
  }
}
