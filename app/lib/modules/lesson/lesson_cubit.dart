import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repository/content_repository.dart';

class LessonState extends Equatable {
  const LessonState({
    this.loading = false,
    this.markdown,
    this.error,
    this.offlineNotice,
  });

  final bool loading;
  final String? markdown;
  final String? error;
  final String? offlineNotice;

  LessonState copyWith({
    bool? loading,
    String? markdown,
    String? error,
    String? offlineNotice,
    bool clearError = false,
    bool clearOffline = false,
  }) {
    return LessonState(
      loading: loading ?? this.loading,
      markdown: markdown ?? this.markdown,
      error: clearError ? null : (error ?? this.error),
      offlineNotice: clearOffline ? null : (offlineNotice ?? this.offlineNotice),
    );
  }

  @override
  List<Object?> get props => [loading, markdown, error, offlineNotice];
}

class LessonCubit extends Cubit<LessonState> {
  LessonCubit({
    required this.path,
    required ContentRepository repo,
  })  : _repo = repo,
        super(const LessonState()) {
    load();
  }

  final String path;
  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(loading: true, clearError: true, clearOffline: true));
    try {
      final result = await _repo.loadLesson(path, forceRefresh: force);
      emit(
        LessonState(
          markdown: result.data,
          offlineNotice: result.isStale
              ? (result.networkError ?? '当前为离线缓存')
              : null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: e.toString(),
        ),
      );
    }
  }
}
