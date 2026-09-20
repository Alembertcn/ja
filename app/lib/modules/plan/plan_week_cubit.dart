import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/plan.dart';
import '../../data/repository/content_repository.dart';

class PlanWeekState extends Equatable {
  const PlanWeekState({
    required this.summary,
    this.detail,
    this.loading = true,
    this.error,
    this.offlineNotice,
  });

  final PlanWeekSummary summary;
  final PlanWeekDetail? detail;
  final bool loading;
  final String? error;
  final String? offlineNotice;

  PlanWeekState copyWith({
    PlanWeekDetail? detail,
    bool? loading,
    String? error,
    String? offlineNotice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PlanWeekState(
      summary: summary,
      detail: detail ?? this.detail,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      offlineNotice:
          clearNotice ? null : (offlineNotice ?? this.offlineNotice),
    );
  }

  @override
  List<Object?> get props => [summary, detail, loading, error, offlineNotice];
}

class PlanWeekCubit extends Cubit<PlanWeekState> {
  PlanWeekCubit({
    required PlanWeekSummary summary,
    required ContentRepository repo,
  })  : _repo = repo,
        super(PlanWeekState(summary: summary)) {
    load();
  }

  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(loading: state.detail == null, clearError: true));
    try {
      final result = await _repo.loadPlanWeek(
        state.summary,
        forceRefresh: force,
      );
      emit(state.copyWith(
        detail: result.data,
        offlineNotice: result.isStale
            ? '当前显示的是离线缓存（${result.networkError}）'
            : null,
        clearNotice: !result.isStale,
        loading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        detail: PlanWeekDetail.fromSummary(state.summary),
        error: e.toString(),
        loading: false,
      ));
    }
  }
}
