import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../shared/app_surface.dart';
import '../shared/state_views.dart';
import 'library_cubit.dart';

class LibraryView extends StatelessWidget {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      body: BlocBuilder<LibraryCubit, LibraryState>(
        builder: (context, state) {
          if (state.loading && state.articles.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final error = state.error;
          if (error != null && state.articles.isEmpty) {
            return ErrorStateView(
              message: error,
              onRetry: context.read<LibraryCubit>().reload,
            );
          }

          if (state.articles.isEmpty) {
            return const EmptyStateView(
              icon: Icons.inbox_outlined,
              title: '还没有课文',
              message: '在仓库的 content/articles 下加一篇 JSON，\n推送后 Actions 会自动发布。',
            );
          }

          return RefreshIndicator(
            onRefresh: context.read<LibraryCubit>().reload,
            color: AppColors.brand,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    onRefresh: context.read<LibraryCubit>().reload,
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
                        for (final article in group.articles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ArticleCard(article: article),
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
  const _Header({required this.onRefresh});

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
                  '课文',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '按周次精读 · 逐句注音与朗读',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4, right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.glassFill(scheme),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
            ),
            child: const Text(
              '日语等级：N5~N2',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
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

  final StageGroup group;

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

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final ArticleSummary article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppInkSurface(
      shadowed: true,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.reader,
        arguments: article,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: AppColors.coverGradient(article.week),
              ),
              alignment: Alignment.center,
              child: Text(
                'W${article.week.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
                    article.titleZh,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      locale: japaneseLocale,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _Badge(text: article.level, tone: _BadgeTone.primary),
                      _Badge(
                        text: article.type == 'dialogue' ? '对话' : '短文',
                        tone: _BadgeTone.secondary,
                      ),
                      _Badge(text: '${article.lineCount} 行'),
                    ],
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

enum _BadgeTone { primary, secondary, plain }

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.tone = _BadgeTone.plain});

  final String text;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (tone) {
      _BadgeTone.primary => (AppColors.brandSoft(scheme), AppColors.brand),
      _BadgeTone.secondary => (
          AppColors.mutedChipBg(scheme),
          AppColors.mutedChipFg(scheme),
        ),
      _BadgeTone.plain => (
          AppColors.mutedChipBg(scheme),
          AppColors.mutedChipFg(scheme),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}
