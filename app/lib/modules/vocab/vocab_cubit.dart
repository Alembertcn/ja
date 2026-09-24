import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/vocab.dart';
import '../../data/repository/content_repository.dart';

class VocabState extends Equatable {
  const VocabState({
    this.loading = true,
    this.error,
    this.offlineNotice,
    this.book,
    this.query = '',
    this.kindFilter,
  });

  final bool loading;
  final String? error;
  final String? offlineNotice;
  final VocabBook? book;
  final String query;
  final VocabGroupKind? kindFilter;

  List<VocabGroup> get visibleGroups {
    final source = book?.groups ?? const <VocabGroup>[];
    final q = query.trim().toLowerCase();
    return source
        .where((g) => kindFilter == null || g.kind == kindFilter)
        .map((g) {
          if (q.isEmpty) return g;
          final words = g.words
              .where(
                (w) =>
                    w.word.toLowerCase().contains(q) ||
                    w.reading.toLowerCase().contains(q) ||
                    w.zh.toLowerCase().contains(q) ||
                    (w.note?.toLowerCase().contains(q) ?? false),
              )
              .toList(growable: false);
          if (words.isEmpty &&
              !g.title.toLowerCase().contains(q) &&
              !(g.hint?.toLowerCase().contains(q) ?? false)) {
            return null;
          }
          return VocabGroup(
            id: g.id,
            title: g.title,
            kind: g.kind,
            hint: g.hint,
            words: words.isEmpty ? g.words : words,
          );
        })
        .whereType<VocabGroup>()
        .toList(growable: false);
  }

  VocabState copyWith({
    bool? loading,
    String? error,
    String? offlineNotice,
    VocabBook? book,
    String? query,
    VocabGroupKind? kindFilter,
    bool clearError = false,
    bool clearNotice = false,
    bool clearKindFilter = false,
  }) {
    return VocabState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      offlineNotice:
          clearNotice ? null : (offlineNotice ?? this.offlineNotice),
      book: book ?? this.book,
      query: query ?? this.query,
      kindFilter: clearKindFilter ? null : (kindFilter ?? this.kindFilter),
    );
  }

  @override
  List<Object?> get props =>
      [loading, error, offlineNotice, book, query, kindFilter];
}

class VocabCubit extends Cubit<VocabState> {
  VocabCubit(this._repo) : super(const VocabState()) {
    load();
  }

  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(
      loading: state.book == null,
      clearError: true,
    ));
    try {
      final result = await _repo.loadVocabN2(forceRefresh: force);
      emit(state.copyWith(
        book: result.data,
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

  void setQuery(String query) => emit(state.copyWith(query: query));

  void setKindFilter(VocabGroupKind? kind) {
    if (kind == null) {
      emit(state.copyWith(clearKindFilter: true));
    } else if (state.kindFilter == kind) {
      emit(state.copyWith(clearKindFilter: true));
    } else {
      emit(state.copyWith(kindFilter: kind));
    }
  }
}
