import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/article.dart';
import '../../data/repository/content_repository.dart';
import '../../services/audio_cache_service.dart';
import '../../services/playback_cubit.dart';

class ReaderState extends Equatable {
  const ReaderState({
    this.article,
    this.loading = true,
    this.error,
    this.offlineNotice,
    this.prefetching = false,
  });

  final Article? article;
  final bool loading;
  final String? error;
  final String? offlineNotice;
  final bool prefetching;

  bool get hasAudio => article?.hasAudio ?? false;

  ReaderState copyWith({
    Article? article,
    bool? loading,
    String? error,
    String? offlineNotice,
    bool? prefetching,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return ReaderState(
      article: article ?? this.article,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      offlineNotice:
          clearNotice ? null : (offlineNotice ?? this.offlineNotice),
      prefetching: prefetching ?? this.prefetching,
    );
  }

  @override
  List<Object?> get props =>
      [article, loading, error, offlineNotice, prefetching];
}

class ReaderCubit extends Cubit<ReaderState> {
  ReaderCubit({
    required this.summary,
    required ContentRepository repo,
    required AudioCacheService audioCache,
    required this.playback,
  })  : _repo = repo,
        _audioCache = audioCache,
        super(const ReaderState()) {
    load();
  }

  final ArticleSummary summary;
  final ContentRepository _repo;
  final AudioCacheService _audioCache;
  final PlaybackCubit playback;

  PlayingArticle? get _playingContext {
    final body = state.article;
    if (body == null || !body.hasAudio) return null;
    return PlayingArticle.fromArticle(summary, body);
  }

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(
      loading: state.article == null,
      clearError: true,
    ));
    try {
      final result = await _repo.loadArticle(summary, forceRefresh: force);
      emit(state.copyWith(
        article: result.data,
        offlineNotice: result.isStale
            ? '当前显示的是离线缓存（${result.networkError}）'
            : null,
        clearNotice: !result.isStale,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), loading: false));
    }
  }

  Future<void> playFromLine(ArticleLine line) async {
    final ctx = _playingContext;
    final cues = state.article?.cues;
    if (ctx == null || cues == null) return;
    final index = cues.indexWhere((c) => c.id == line.id);
    if (index < 0) return;
    await playback.start(ctx, fromIndex: index);
  }

  Future<void> playAll() async {
    final ctx = _playingContext;
    if (ctx == null) return;
    await playback.start(ctx, fromIndex: 0);
  }

  Future<void> stop() => playback.stop();

  /// 把整篇音频下到本地。返回 true=成功，false=失败，null=跳过。
  Future<bool?> prefetchAudio() async {
    final path = state.article?.audio;
    if (path == null || path.isEmpty || state.prefetching) return null;

    emit(state.copyWith(prefetching: true));
    try {
      final file = await _audioCache.resolve(path);
      return file != null;
    } finally {
      emit(state.copyWith(prefetching: false));
    }
  }
}
