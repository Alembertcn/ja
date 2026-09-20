import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_config.dart';
import '../../data/models/plan.dart';
import '../../data/repository/content_repository.dart';

class PlanStageGroup {
  const PlanStageGroup({
    required this.stage,
    required this.stageCode,
    required this.weeks,
  });

  final LearningStage? stage;
  final String stageCode;
  final List<PlanWeekSummary> weeks;

  String get title =>
      stage == null ? stageCode : '${stage!.code} · ${stage!.title}';

  String get subtitle => stage?.description ?? '';
}

class PlanState extends Equatable {
  const PlanState({
    this.loading = true,
    this.error,
    this.offlineNotice,
    this.title = '学习计划',
    this.target = '',
    this.weeks = const [],
  });

  final bool loading;
  final String? error;
  final String? offlineNotice;
  final String title;
  final String target;
  final List<PlanWeekSummary> weeks;

  List<PlanStageGroup> get groups {
    final buckets = <String, List<PlanWeekSummary>>{};
    for (final week in weeks) {
      buckets.putIfAbsent(week.stage, () => []).add(week);
    }
    final codes = buckets.keys.toList()
      ..sort((a, b) =>
          LearningStage.orderOf(a).compareTo(LearningStage.orderOf(b)));
    return codes.map((code) {
      final list = buckets[code]!
        ..sort((a, b) => a.week.compareTo(b.week));
      return PlanStageGroup(
        stage: LearningStage.fromCode(code),
        stageCode: code,
        weeks: list,
      );
    }).toList();
  }

  PlanState copyWith({
    bool? loading,
    String? error,
    String? offlineNotice,
    String? title,
    String? target,
    List<PlanWeekSummary>? weeks,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PlanState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      offlineNotice:
          clearNotice ? null : (offlineNotice ?? this.offlineNotice),
      title: title ?? this.title,
      target: target ?? this.target,
      weeks: weeks ?? this.weeks,
    );
  }

  @override
  List<Object?> get props =>
      [loading, error, offlineNotice, title, target, weeks];
}

class PlanCubit extends Cubit<PlanState> {
  PlanCubit(this._repo) : super(const PlanState()) {
    load();
  }

  final ContentRepository _repo;

  Future<void> load({bool force = false}) async {
    emit(state.copyWith(
      loading: state.weeks.isEmpty,
      clearError: true,
    ));
    try {
      final result = await _repo.loadPlanWeeks(forceRefresh: force);
      emit(state.copyWith(
        title: result.data.title,
        target: result.data.target,
        weeks: result.data.weeks,
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

  PlanWeekSummary? weekById(String id) {
    for (final week in state.weeks) {
      if (week.id == id) return week;
    }
    return null;
  }
}
