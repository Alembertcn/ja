import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_router.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../../services/playback_cubit.dart';
import '../../services/settings_cubit.dart';
import '../explain/explain_args.dart';
import '../player/player_bar.dart';
import '../shared/state_views.dart';
import 'reader_cubit.dart';
import 'widgets/line_tile.dart';

class ReaderView extends StatefulWidget {
  const ReaderView({super.key});

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  final Map<String, GlobalKey> _lineKeys = {};

  GlobalKey _keyFor(String id) => _lineKeys.putIfAbsent(id, GlobalKey.new);

  void _scrollToLine(String id) {
    final ctx = _lineKeys[id]?.currentContext;
    if (ctx == null || !mounted) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      alignment: 0.25,
    );
  }

  void _openExplain(Article article, ArticleLine line) {
    final cubit = context.read<ReaderCubit>();
    Navigator.of(context).pushNamed(
      Routes.explain,
      arguments: ExplainArgs(
        line: line,
        isDialogue: article.isDialogue,
        title: cubit.summary.titleZh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<ReaderCubit>();

    return BlocListener<PlaybackCubit, PlaybackState>(
      listenWhen: (prev, next) =>
          prev.currentLineId != next.currentLineId && next.currentLineId != null,
      listener: (context, state) {
        final id = state.currentLineId;
        if (id == null) return;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLine(id));
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg(scheme),
        appBar: AppBar(
          backgroundColor: AppColors.card(scheme),
          title: Text(
            cubit.summary.titleZh,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          actions: [
            BlocBuilder<ReaderCubit, ReaderState>(
              buildWhen: (a, b) =>
                  a.hasAudio != b.hasAudio || a.prefetching != b.prefetching,
              builder: (context, state) {
                return PopupMenuButton<_ReaderMenu>(
                  onSelected: (value) async {
                    switch (value) {
                      case _ReaderMenu.prefetch:
                        final ok = await cubit.prefetchAudio();
                        if (!context.mounted || ok == null) return;
                        showAppSnackBar(
                          context,
                          ok ? '已缓存到本地' : '下载失败',
                          ok ? '整篇音频可离线播放' : '请检查网络后重试',
                        );
                      case _ReaderMenu.refresh:
                        await cubit.load(force: true);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _ReaderMenu.prefetch,
                      enabled: state.hasAudio && !state.prefetching,
                      child: const Text('缓存音频到本地'),
                    ),
                    const PopupMenuItem(
                      value: _ReaderMenu.refresh,
                      child: Text('重新拉取'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<ReaderCubit, ReaderState>(
          builder: (context, state) {
            if (state.loading && state.article == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final error = state.error;
            if (error != null && state.article == null) {
              return ErrorStateView(
                message: error,
                onRetry: () => cubit.load(force: true),
              );
            }

            final article = state.article;
            if (article == null) {
              return const EmptyStateView(
                icon: Icons.article_outlined,
                title: '没有正文',
                message: '这篇课文暂时拉不到内容。',
              );
            }

            return RefreshIndicator(
              color: AppColors.brand,
              onRefresh: () => cubit.load(force: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (state.offlineNotice != null)
                    OfflineBanner(message: state.offlineNotice!),
                  _ArticleHeader(article: article),
                  const SizedBox(height: 14),
                  for (final line in article.lines)
                    Padding(
                      key: _keyFor(line.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: BlocBuilder<PlaybackCubit, PlaybackState>(
                        buildWhen: (a, b) =>
                            a.currentLineId != b.currentLineId,
                        builder: (context, playback) {
                          return BlocBuilder<SettingsCubit, SettingsState>(
                            buildWhen: (a, b) => a.fontScale != b.fontScale,
                            builder: (context, settings) {
                              return LineTile(
                                line: line,
                                isDialogue: article.isDialogue,
                                playing: playback.currentLineId == line.id,
                                fontScale: settings.fontScale,
                                onTap: () => cubit.playFromLine(line),
                                onExplain: () => _openExplain(article, line),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: const PlayerBar.full(),
      ),
    );
  }
}

enum _ReaderMenu { prefetch, refresh }

class _ArticleHeader extends StatelessWidget {
  const _ArticleHeader({required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<ReaderCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      locale: japaneseLocale,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Chip(text: article.level, emphasize: true),
                      _Chip(text: 'W${article.week.toString().padLeft(2, '0')}'),
                      _Chip(text: article.type == 'dialogue' ? '对话' : '短文'),
                      if (article.vocabTopic != null) _Chip(text: article.vocabTopic!),
                      Text(
                        article.updatedAt,
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<PlaybackCubit, PlaybackState>(
              builder: (context, playback) {
                final playing = playback.isPlaying &&
                    !playback.isPaused &&
                    playback.current?.articleId == article.id;
                return Material(
                  color: AppColors.brand,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: AppColors.cardShadow,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      if (playing) {
                        cubit.playback.togglePlayPause();
                      } else if (playback.current?.articleId == article.id &&
                          playback.isPaused) {
                        cubit.playback.togglePlayPause();
                      } else {
                        cubit.playAll();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 148,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: AppColors.coverGradient(article.week),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 18,
                bottom: 16,
                right: 18,
                child: Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    locale: japaneseLocale,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black26)],
                  ),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'W${article.week.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          '点击句子跳播 · 点 ✦ 查看 AI讲解',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
        ),
        BlocBuilder<ReaderCubit, ReaderState>(
          buildWhen: (a, b) => a.hasAudio != b.hasAudio,
          builder: (context, state) {
            if (state.hasAudio) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '这篇还没有音频，朗读不可用。在仓库里跑一次 tools/publish.py 合成后重新发布即可。',
                  style: TextStyle(fontSize: 12, color: scheme.onErrorContainer, height: 1.5),
                ),
              ),
            );
          },
        ),
      ],
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
