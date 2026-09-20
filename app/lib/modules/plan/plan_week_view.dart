import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_router.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../../data/models/plan.dart';
import '../lesson/lesson_args.dart';
import '../library/library_cubit.dart';
import '../shared/state_views.dart';
import 'plan_week_cubit.dart';

class PlanWeekView extends StatelessWidget {
  const PlanWeekView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocBuilder<PlanWeekCubit, PlanWeekState>(
      builder: (context, state) {
        final summary = state.summary;
        return Scaffold(
          backgroundColor: AppColors.pageBg(scheme),
          appBar: AppBar(
            backgroundColor: AppColors.card(scheme),
            title: Text(
              '${summary.id} · ${summary.title}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          body: _body(context, state),
        );
      },
    );
  }

  Widget _body(BuildContext context, PlanWeekState state) {
    if (state.loading && state.detail == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final detail = state.detail;
    if (detail == null) {
      return ErrorStateView(
        message: state.error ?? '加载失败',
        onRetry: () => context.read<PlanWeekCubit>().load(force: true),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final plannedIds = detail.articleIds.isNotEmpty
        ? detail.articleIds
        : state.summary.articleIds;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (state.offlineNotice != null) OfflineBanner(message: state.offlineNotice!),
        _MetaChips(detail: detail),
        const SizedBox(height: 16),
        _SectionCard(
          title: '本周目标',
          child: Text(
            detail.goal,
            style: TextStyle(
              fontSize: 15,
              height: 1.55,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (detail.hoursHint != null && detail.hoursHint!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '建议时长：${detail.hoursHint}',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
        if (detail.days.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionCard(
            title: '本周安排',
            child: Column(
              children: [
                for (var i = 0; i < detail.days.length; i++) ...[
                  if (i > 0) Divider(height: 20, color: scheme.outlineVariant),
                  _DayRow(day: detail.days[i]),
                ],
              ],
            ),
          ),
        ],
        if (detail.deliverables.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionCard(
            title: '交付物',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < detail.deliverables.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == detail.deliverables.length - 1 ? 0 : 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            detail.deliverables[i],
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          '知识点',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 10),
        if (detail.topics.isEmpty)
          _SectionCard(
            title: '资料待补充',
            child: Text(
              '本周暂无细化知识点摘要；完整内容请打开精讲笔记。',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final topic in detail.topics) ...[
            _TopicTile(topic: topic),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        _WeekArticlesBox(
          week: detail.week,
          plannedIds: plannedIds,
        ),
        if (_hasLesson(detail, state)) ...[
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _openLesson(context, detail, state),
            icon: const Icon(Icons.article_outlined),
            label: const Text('打开精讲笔记'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ],
    );
  }

  bool _hasLesson(PlanWeekDetail detail, PlanWeekState state) {
    final path = detail.lessonPath ?? state.summary.lessonPath;
    return path != null && path.isNotEmpty;
  }

  void _openLesson(
    BuildContext context,
    PlanWeekDetail detail,
    PlanWeekState state,
  ) {
    final path = detail.lessonPath ?? state.summary.lessonPath;
    if (path == null || path.isEmpty) return;
    Navigator.of(context).pushNamed(
      Routes.lesson,
      arguments: LessonArgs(
        path: path,
        title: '${detail.id} 精讲笔记',
      ),
    );
  }
}

/// 本周精读：折叠后看篇数，展开后列出短文，点进阅读页。
/// 以计划里的 articleIds 为主序，并并入课文库中同 week 的篇目（避免计划缓存过旧漏篇）。
class _WeekArticlesBox extends StatelessWidget {
  const _WeekArticlesBox({
    required this.week,
    required this.plannedIds,
  });

  final int week;
  final List<String> plannedIds;

  static List<String> _resolveIds(List<String> planned, List<ArticleSummary> library, int week) {
    final seen = <String>{};
    final ids = <String>[];
    void add(String id) {
      if (id.isEmpty || seen.contains(id)) return;
      seen.add(id);
      ids.add(id);
    }

    for (final id in planned) {
      add(id);
    }
    final sameWeek = library.where((a) => a.week == week).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    for (final a in sameWeek) {
      add(a.id);
    }
    return ids;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<LibraryCubit, LibraryState>(
      buildWhen: (a, b) => a.articles != b.articles || a.loading != b.loading,
      builder: (context, lib) {
        final articleIds = _resolveIds(plannedIds, lib.articles, week);
        if (articleIds.isEmpty && !lib.loading) {
          return _SectionCard(
            title: '本周精读',
            child: Text(
              '本周还没有关联精读课文。',
              style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
            ),
          );
        }

        final byId = {for (final a in lib.articles) a.id: a};
        final ready = articleIds.where(byId.containsKey).length;

        return Material(
          color: AppColors.card(scheme),
          borderRadius: AppRadii.mdAll,
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: articleIds.length <= 3,
              leading: const Icon(Icons.menu_book, color: AppColors.brand),
              title: const Text(
                '本周精读',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              subtitle: Text(
                lib.loading && lib.articles.isEmpty
                    ? '课文列表加载中…'
                    : articleIds.isEmpty
                        ? '暂无短文'
                        : ready == articleIds.length
                            ? '$ready 篇短文，点开查看'
                            : '已同步 $ready / ${articleIds.length} 篇',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              children: [
                for (var i = 0; i < articleIds.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                  _ArticleRow(
                    index: i + 1,
                    articleId: articleIds[i],
                    summary: byId[articleIds[i]],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArticleRow extends StatelessWidget {
  const _ArticleRow({
    required this.index,
    required this.articleId,
    required this.summary,
  });

  final int index;
  final String articleId;
  final ArticleSummary? summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = summary?.titleZh ?? articleId;
    final jp = summary?.title;
    final scene = summary?.scene;
    final available = summary != null;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 12, 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.brandSoft(scheme),
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.brand,
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: available ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        [
          if (jp != null && jp.isNotEmpty) jp,
          if (scene != null && scene.isNotEmpty) scene,
          if (!available) '课文未同步，请先到「课文」页刷新',
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant),
      ),
      trailing: Icon(
        available ? Icons.chevron_right : Icons.cloud_off_outlined,
        color: scheme.onSurfaceVariant,
      ),
      onTap: () {
        if (summary == null) {
          showAppSnackBar(context, '未找到课文', '请先在「课文」页刷新列表后再试');
          return;
        }
        Navigator.of(context).pushNamed(Routes.reader, arguments: summary);
      },
    );
  }
}

class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.detail});

  final PlanWeekDetail detail;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(text: detail.stage, emphasize: true),
        _Chip(text: detail.id),
        for (final m in detail.modules) _Chip(text: m),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final PlanDay day;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 52,
          child: Text(
            'Day${day.day}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.focus,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day.tasks,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final PlanTopic topic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: AppColors.card(scheme),
      borderRadius: AppRadii.mdAll,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shadowColor: AppColors.cardShadow,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            '${topic.id} · ${topic.title}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          children: [
            for (final point in topic.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('· ', style: TextStyle(color: AppColors.brand)),
                    Expanded(
                      child: Text(
                        point,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.card(scheme),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.emphasize = false});

  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: emphasize ? AppColors.brandSoft(scheme) : AppColors.mutedChipBg(scheme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: emphasize ? AppColors.brand : AppColors.mutedChipFg(scheme),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
