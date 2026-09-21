import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/plan.dart';
import '../shared/app_surface.dart';
import '../shared/state_views.dart';
import 'plan_cubit.dart';

class PlanView extends StatelessWidget {
  const PlanView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      body: BlocBuilder<PlanCubit, PlanState>(
        builder: (context, state) {
          if (state.loading && state.weeks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = state.error;
          if (error != null && state.weeks.isEmpty) {
            return ErrorStateView(
              message: error,
              onRetry: context.read<PlanCubit>().reload,
            );
          }

          if (state.weeks.isEmpty) {
            return const EmptyStateView(
              icon: Icons.calendar_month_outlined,
              title: '还没有学习计划',
              message: '在仓库 content/plan/weeks.json 发布后即可在此查看。',
            );
          }

          return RefreshIndicator(
            onRefresh: context.read<PlanCubit>().reload,
            color: AppColors.brand,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    title: state.title,
                    target: state.target,
                    onRefresh: context.read<PlanCubit>().reload,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (state.offlineNotice != null)
                        OfflineBanner(message: state.offlineNotice!),
                      for (final group in state.groups) ...[
                        _StageHeader(group: group),
                        for (final week in group.weeks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _WeekCard(week: week),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.target,
    required this.onRefresh,
  });

  final String title;
  final String target;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 12, 12, 20),
      decoration: BoxDecoration(gradient: AppColors.headerGradient(scheme)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                if (target.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    target,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: onRefresh,
            icon: Icon(Icons.refresh, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.group});

  final PlanStageGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (group.subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                group.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final PlanWeekSummary week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppInkSurface(
      shadowed: true,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.planWeek,
        arguments: week,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: AppColors.coverGradient(week.week),
              ),
              alignment: Alignment.center,
              child: Text(
                week.id,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    week.modules.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (week.deliverable.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      week.deliverable,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}
