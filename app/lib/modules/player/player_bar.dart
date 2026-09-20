import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../services/playback_cubit.dart';
import '../../services/settings_cubit.dart';
import 'playback_settings_sheet.dart';

enum PlayerBarStyle { mini, full }

/// 全局播放条。迷你态挂在 Home 底栏上方；完整态挂在阅读页底部。
class PlayerBar extends StatelessWidget {
  const PlayerBar({super.key, required this.style});

  const PlayerBar.mini({super.key}) : style = PlayerBarStyle.mini;

  const PlayerBar.full({super.key}) : style = PlayerBarStyle.full;

  final PlayerBarStyle style;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      builder: (context, state) {
        final article = state.current;
        if (article == null) return const SizedBox.shrink();

        final playing = state.isPlaying && !state.isPaused;
        final playback = context.read<PlaybackCubit>();

        return style == PlayerBarStyle.mini
            ? _MiniBar(
                playback: playback,
                article: article,
                playing: playing,
                index: state.index,
                position: state.position,
                duration: state.duration,
              )
            : _FullBar(
                playback: playback,
                article: article,
                playing: playing,
                position: state.position,
                duration: state.duration,
              );
      },
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.playback,
    required this.article,
    required this.playing,
    required this.index,
    required this.position,
    required this.duration,
  });

  final PlaybackCubit playback;
  final PlayingArticle article;
  final bool playing;
  final int index;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = article.cues.isEmpty ? article.lines.length : article.cues.length;
    final idx = index.clamp(0, total == 0 ? 0 : total - 1);
    final durMs = duration.inMilliseconds;
    final posMs = position.inMilliseconds;
    final progress = durMs <= 0 ? 0.0 : (posMs / durMs).clamp(0.0, 1.0);

    return Material(
      color: scheme.surface,
      elevation: 6,
      shadowColor: AppColors.cardShadow,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          Routes.reader,
          arguments: article.summary,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: scheme.outlineVariant.withValues(alpha: 0.35),
                color: AppColors.brand,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '关闭播放',
                    onPressed: playback.dismiss,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.power_settings_new,
                        size: 20, color: scheme.onSurfaceVariant),
                  ),
                  _CoverThumb(week: article.week, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.titleZh,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          total == 0 ? '' : '${idx + 1} / $total 句',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: playback.togglePlayPause,
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: AppColors.brand,
                      size: 34,
                    ),
                  ),
                  IconButton(
                    tooltip: '播放设置',
                    onPressed: () => PlaybackSettingsSheet.open(context),
                    icon: Icon(Icons.queue_music_outlined,
                        color: scheme.onSurfaceVariant),
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

class _FullBar extends StatelessWidget {
  const _FullBar({
    required this.playback,
    required this.article,
    required this.playing,
    required this.position,
    required this.duration,
  });

  final PlaybackCubit playback;
  final PlayingArticle article;
  final bool playing;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final value = (position.inMilliseconds / maxMs).clamp(0.0, 1.0);

    return Material(
      color: scheme.surface,
      elevation: 8,
      shadowColor: AppColors.cardShadow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    _format(position),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: value,
                        onChanged: (v) {
                          playback.seek(
                            Duration(milliseconds: (v * maxMs).round()),
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    _format(duration),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: '播放设置',
                    onPressed: () => PlaybackSettingsSheet.open(context),
                    icon: Icon(Icons.tune, color: scheme.onSurfaceVariant),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: playback.previous,
                    icon: const Icon(Icons.skip_previous, size: 30),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.brand,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: playback.togglePlayPause,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: playback.next,
                    icon: const Icon(Icons.skip_next, size: 30),
                  ),
                  const Spacer(),
                  const _SpeedBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _format(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.speechSpeed != b.speechSpeed,
      builder: (context, settings) {
        return TextButton(
          onPressed: () => PlaybackSettingsSheet.open(context),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
          ),
          child: Text(
            '${settings.speechSpeed.toStringAsFixed(1)}×',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        );
      },
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.week, this.size = 40});

  final int week;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: AppColors.coverGradient(week),
      ),
      alignment: Alignment.center,
      child: Text(
        'W${week.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: size * 0.28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
