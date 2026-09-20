import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/app_config.dart';
import '../../app/routes/app_router.dart';
import '../../app/theme.dart';
import '../../services/settings_cubit.dart';
import '../player/playback_settings_sheet.dart';
import 'profile_cubit.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _ProfileBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('朗读'),
                _Panel(children: [_PlaybackSettingsTile()]),
                const _SectionTitle('阅读'),
                _Panel(children: [
                  const _AnnotationStyleTile(),
                  const _Divider(),
                  const _InlineFuriganaTile(),
                  const _Divider(),
                  const _FontScaleTile(),
                ]),
                const _SectionTitle('内容'),
                _Panel(children: [
                  const _ContentSourceTile(),
                  const _Divider(),
                  const _CacheTile(),
                ]),
                const _SectionTitle('学习数据'),
                const _PhaseTwoCard(),
                const _SectionTitle('关于'),
                _Panel(children: [const _AboutTile()]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackSettingsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) =>
          a.speechSpeed != b.speechSpeed || a.loopMode != b.loopMode,
      builder: (context, settings) {
        return ListTile(
          leading: const Icon(Icons.graphic_eq, color: AppColors.brand),
          title: const Text('循环与倍速'),
          subtitle: Text(
            '${settings.loopMode.label} · ${settings.speechSpeed.toStringAsFixed(1)}×',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => PlaybackSettingsSheet.open(context),
        );
      },
    );
  }
}

class _AnnotationStyleTile extends StatelessWidget {
  const _AnnotationStyleTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.annotationStyle != b.annotationStyle,
      builder: (context, settings) {
        return ListTile(
          title: const Text('AI讲解页的整句注音'),
          subtitle: Text('未开 ruby 时，在原文上方显示 ${settings.annotationStyle.label}'),
          trailing: DropdownButton<AnnotationStyle>(
            value: settings.annotationStyle,
            underline: const SizedBox.shrink(),
            items: [
              for (final style in AnnotationStyle.values)
                DropdownMenuItem(value: style, child: Text(style.label)),
            ],
            onChanged: (style) {
              if (style != null) {
                context.read<SettingsCubit>().setAnnotationStyle(style);
              }
            },
          ),
        );
      },
    );
  }
}

class _InlineFuriganaTile extends StatelessWidget {
  const _InlineFuriganaTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.inlineFurigana != b.inlineFurigana,
      builder: (context, settings) {
        return SwitchListTile(
          title: const Text('汉字上方标注假名'),
          subtitle: const Text('仅作用于 AI讲解详情页的句子卡片'),
          value: settings.inlineFurigana,
          activeThumbColor: AppColors.brand,
          onChanged: context.read<SettingsCubit>().setInlineFurigana,
        );
      },
    );
  }
}

class _FontScaleTile extends StatelessWidget {
  const _FontScaleTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.fontScale != b.fontScale,
      builder: (context, settings) {
        final scale = settings.fontScale;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: const Text('正文字号'),
              trailing: Text('${(scale * 100).round()}%'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Slider(
                value: scale,
                min: 0.8,
                max: 1.6,
                divisions: 8,
                label: '${(scale * 100).round()}%',
                onChanged: context.read<SettingsCubit>().setFontScale,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContentSourceTile extends StatelessWidget {
  const _ContentSourceTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) => a.contentBaseUrl != b.contentBaseUrl,
      builder: (context, settings) {
        return ListTile(
          title: const Text('内容源'),
          subtitle: Text(
            settings.contentBaseUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editBaseUrl(context, settings.contentBaseUrl),
        );
      },
    );
  }

  Future<void> _editBaseUrl(BuildContext context, String current) async {
    final field = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('内容源地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: field,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: AppConfig.defaultContentBaseUrl,
                helperText: 'manifest.json 所在目录，结尾要带 /',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '改地址会清空本地缓存并重新拉取。',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, AppConfig.defaultContentBaseUrl),
            child: const Text('恢复默认'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, field.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    field.dispose();
    if (result != null && context.mounted) {
      await context.read<ProfileCubit>().applyBaseUrl(result);
    }
  }
}

class _CacheTile extends StatelessWidget {
  const _CacheTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final stats = state.cacheStats;
        final docPart = stats == null
            ? '课文统计中…'
            : '${stats.articleCount} 篇课文 · ${stats.readableSize}';
        final audioPart = state.audioFileCount == 0
            ? '暂无音频'
            : '${state.audioFileCount} 个音频 · ${state.audioSizeText}';
        final timePart = stats?.lastFetchedAt == null
            ? ''
            : ' · 最近 ${_formatTime(stats!.lastFetchedAt!)}';
        return ListTile(
          title: const Text('清理缓存'),
          subtitle: Text('$docPart · $audioPart$timePart'),
          trailing: TextButton(
            onPressed: () => _confirmClear(context),
            child: const Text('清理'),
          ),
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理全部缓存？'),
        content: const Text(
          '会删除本地课文数据与音频文件。下次打开将重新联网下载，便于拿到最新内容与朗读。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<ProfileCubit>().clearAllCaches();
      if (context.mounted) {
        showAppSnackBar(context, '已清理', '缓存已清空，课文列表已重新拉取');
      }
    }
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      buildWhen: (a, b) => a.appVersion != b.appVersion,
      builder: (context, state) {
        return ListTile(
          title: const Text('学JA'),
          subtitle: Text(
            state.appVersion.isEmpty ? '版本读取中…' : '版本 ${state.appVersion}',
          ),
          trailing: const Icon(Icons.info_outline),
        );
      },
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, top + 20, 20, 28),
      decoration: BoxDecoration(gradient: AppColors.headerGradient(scheme)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.coverGradient(1),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '学习者',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '学JA · 日语精读',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseTwoCard extends StatelessWidget {
  const _PhaseTwoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(scheme),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 20, color: AppColors.brand),
              const SizedBox(width: 8),
              Text(
                '学习画像与 AI 教练',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brandSoft(scheme),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '二期',
                  style: TextStyle(fontSize: 10, color: AppColors.brand),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '会记录阅读时长、展开过的行、反复播放的句子和标记的生词，'
            '按语法模块号聚合出薄弱点，再由 AI 生成学习画像和下一步建议。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(scheme),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant);
  }
}
