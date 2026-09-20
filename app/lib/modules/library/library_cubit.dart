import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_config.dart';
import '../../data/models/article.dart';
import '../../data/repository/content_repository.dart';

/// 列表页的一个阶段分区。
class StageGroup {
  const StageGroup({
    required this.stage,
    required this.stageCode,
    required this.articles,
  });

  final LearningStage? stage;
  final String stageCode;
  final List<ArticleSummary> articles;

  String get title =>
      stage == null ? stageCode : '${stage!.code} · ${stage!.title}';

  String get subtitle => stage?.description ?? '';
}

class LibraryState extends Equatable {
  const LibraryState({
    this.loading = true,
    this.error,
    this.offlineNotice,
    this.articles = const [],
  });

  final bool loading;
  final String? error;
  final String? offlineNotice;
  final List<ArticleSummary> articles;

  List<StageGroup> get groups {
    final buckets = <String, List<ArticleSummary>>{};
    for (final article in articles) {
      buckets.putIfAbsent(article.stage, () => []).add(article);
    }

    final codes = buckets.keys.toList()
      ..sort((a, b) =>
          LearningStage.orderOf(a).compareTo(LearningStage.orderOf(b)));

    return codes.map((code) {
      final list = buckets[code]!
        ..sort((a, b) {
          final byWeek = a.week.compareTo(b.week);
          return byWeek != 0 ? byWeek : a.id.compareTo(b.id);
        });
      return StageGroup(
        stage: LearningStage.fromCode(code),
        stageCode: code,
        articles: list,
      );
    }).toList();
  }

  LibraryState copyWith({
    bool? loading,
    String? error,
    String? offlineNotice,
    List<ArticleSummary>? articles,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return LibraryState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      offlineNotice:
          clearNotice ? null : (offlineNotice ?? this.offlineNotice),
      articles: articles ?? this.articles,
    );
  }

  @override
  List<Object?> get props => [loading, error, offlineNotice, articles];
}

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(this._repo) : super(const LibraryState()) {
    load();
  }

  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(
      loading: state.articles.isEmpty,
      clearError: true,
    ));
    try {
      final result = await _repo.loadManifest(forceRefresh: force);
      emit(state.copyWith(
        articles: result.data.articles,
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

  Future<void> reload() => load(force: true);
}
