import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_router.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
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
    final articleId = detail.articleId ?? state.summary.articleId;

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
        if (_hasLesson(detail, state) ||
            (articleId != null && articleId.isNotEmpty)) ...[
          const SizedBox(height: 12),
          if (_hasLesson(detail, state))
            FilledButton.tonalIcon(
              onPressed: () => _openLesson(context, detail, state),
              icon: const Icon(Icons.article_outlined),
              label: const Text('打开精讲笔记'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          if (_hasLesson(detail, state) &&
              articleId != null &&
              articleId.isNotEmpty)
            const SizedBox(height: 10),
          if (articleId != null && articleId.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _openArticle(context, articleId),
              icon: const Icon(Icons.menu_book),
              label: const Text('打开精读课文'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brand,
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

  void _openArticle(BuildContext context, String articleId) {
    final articles = context.read<LibraryCubit>().state.articles;
    for (final article in articles) {
      if (article.id == articleId) {
        Navigator.of(context).pushNamed(Routes.reader, arguments: article);
        return;
      }
    }
    showAppSnackBar(context, '未找到课文', '请先在「课文」页刷新列表后再试');
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
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: AppColors.cardShadow,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
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
