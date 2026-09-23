import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/practice.dart';
import '../../data/repository/content_repository.dart';

class PracticeState extends Equatable {
  const PracticeState({
    this.loading = false,
    this.practice,
    this.error,
    this.offlineNotice,
  });

  final bool loading;
  final PracticeSet? practice;
  final String? error;
  final String? offlineNotice;

  @override
  List<Object?> get props => [loading, practice, error, offlineNotice];
}

class PracticeCubit extends Cubit<PracticeState> {
  PracticeCubit({
    required this.path,
    required ContentRepository repo,
  })  : _repo = repo,
        super(const PracticeState()) {
    load();
  }

  final String path;
  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(PracticeState(loading: true, practice: state.practice));
    try {
      final result = await _repo.loadPractice(path, forceRefresh: force);
      emit(
        PracticeState(
          practice: result.data,
          offlineNotice: result.isStale
              ? (result.networkError ?? '当前为离线缓存')
              : null,
        ),
      );
    } catch (error) {
      emit(PracticeState(practice: state.practice, error: error.toString()));
    }
  }
}
