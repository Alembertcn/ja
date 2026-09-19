import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../shared/state_views.dart';
import 'reader_controller.dart';
import 'widgets/line_tile.dart';

class ReaderView extends GetView<ReaderController> {
  const ReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(controller.summary.titleZh, style: theme.textTheme.titleMedium),
            Text(
              controller.summary.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                locale: japaneseLocale,
              ),
            ),
          ],
        ),
        actions: [
          Obx(() {
            final hasExpanded = controller.expandedLineIds.isNotEmpty;
            return IconButton(
              tooltip: hasExpanded ? '全部收起' : '全部展开',
              onPressed: hasExpanded ? controller.collapseAll : controller.expandAll,
              icon: Icon(hasExpanded ? Icons.unfold_less : Icons.unfold_more),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value && controller.article.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final error = controller.error.value;
        if (error != null && controller.article.value == null) {
          return ErrorStateView(message: error, onRetry: () => controller.load(force: true));
        }

        final article = controller.article.value;
        if (article == null) {
          return const EmptyStateView(
            icon: Icons.article_outlined,
            title: '没有正文',
            message: '这篇课文暂时拉不到内容。',
          );
        }

        return RefreshIndicator(
          onRefresh: () => controller.load(force: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Obx(() {
                final notice = controller.offlineNotice.value;
                return notice == null
                    ? const SizedBox.shrink()
                    : OfflineBanner(message: notice);
              }),
              _ArticleHeader(article: article),
              const SizedBox(height: 12),
              for (final line in article.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Obx(() => LineTile(
                        line: line,
                        isDialogue: article.isDialogue,
                        expanded: controller.isExpanded(line.id),
                        playing: controller.tts.currentLineId.value == line.id,
                        fontScale: controller.settings.fontScale.value,
                        annotationStyle: controller.settings.annotationStyle.value,
                        inlineFurigana: controller.settings.inlineFurigana.value,
                        onTap: () => controller.toggleLine(line.id),
                        onPlay: () => controller.playLine(line),
                      )),
                ),
            ],
          ),
        );
      }),
      floatingActionButton: Obx(() {
        if (controller.article.value == null) return const SizedBox.shrink();
        final speaking = controller.tts.isSpeaking.value;
        return FloatingActionButton.extended(
          onPressed: speaking ? controller.stop : controller.playAll,
          icon: Icon(speaking ? Icons.stop : Icons.play_arrow),
          label: Text(speaking ? '停止' : '朗读全文'),
        );
      }),
    );
  }
}

class _ArticleHeader extends StatelessWidget {
  const _ArticleHeader({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ttsWarning = !Get.find<ReaderController>().tts.japaneseAvailable.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(text: article.stage),
            _Chip(text: 'W${article.week.toString().padLeft(2, '0')}'),
            _Chip(text: article.level),
            if (article.vocabTopic != null) _Chip(text: article.vocabTopic!),
            for (final module in article.grammarModules) _Chip(text: module),
          ],
        ),
        if (article.scene != null) ...[
          const SizedBox(height: 10),
          Text(
            article.scene!,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          '点击任意一行展开注音、翻译与解析',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        if (ttsWarning) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '系统里没找到日语语音，朗读可能无声。\n'
              'Android：安装「Google 文字转语音」并在 设置 → 系统 → 语言和输入法 → 文字转语音 里下载日语语音包。',
              style: TextStyle(fontSize: 12, color: scheme.onErrorContainer, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
