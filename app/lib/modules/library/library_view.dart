import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../shared/state_views.dart';
import 'library_controller.dart';

class LibraryView extends GetView<LibraryController> {
  const LibraryView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课文'),
        actions: [
          Obx(() => IconButton(
                tooltip: '刷新',
                onPressed: controller.loading.value ? null : controller.reload,
                icon: const Icon(Icons.refresh),
              )),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.articles.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = controller.error.value;
        if (error != null && controller.articles.isEmpty) {
          return ErrorStateView(
            message: error,
            onRetry: controller.reload,
          );
        }

        if (controller.articles.isEmpty) {
          return const EmptyStateView(
            icon: Icons.inbox_outlined,
            title: '还没有课文',
            message: '在仓库的 content/articles 下加一篇 JSON，\n推送后 Actions 会自动发布。',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Obx(() {
                final notice = controller.offlineNotice.value;
                if (notice == null) return const SizedBox.shrink();
                return OfflineBanner(message: notice);
              }),
              for (final group in controller.groups) ...[
                _StageHeader(group: group),
                for (final article in group.articles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ArticleCard(article: article),
                  ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      }),
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
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Get.toNamed(Routes.reader, arguments: article),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.titleZh,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      article.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        locale: japaneseLocale,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          text: 'W${article.week.toString().padLeft(2, '0')}',
                          tone: _BadgeTone.primary,
                        ),
                        _Badge(text: article.level, tone: _BadgeTone.secondary),
                        _Badge(
                          text: article.type == 'dialogue' ? '对话' : '短文',
                        ),
                        _Badge(text: '${article.lineCount} 行'),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
      _BadgeTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      _BadgeTone.secondary => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _BadgeTone.plain => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
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
