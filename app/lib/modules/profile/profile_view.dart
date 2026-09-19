import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/app_config.dart';
import '../../services/settings_service.dart';
import 'profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const _SectionTitle('朗读'),
          _Panel(children: [_speechSpeed(context), const _Divider(), _previewTile()]),
          const _SectionTitle('阅读'),
          _Panel(children: [
            _annotationStyle(context),
            const _Divider(),
            _inlineFurigana(),
            const _Divider(),
            _fontScale(context),
            const _Divider(),
            _expandMode(),
          ]),
          const _SectionTitle('内容'),
          _Panel(children: [_contentSource(context), const _Divider(), _cache(context)]),
          const _SectionTitle('学习数据'),
          const _PhaseTwoCard(),
          const _SectionTitle('关于'),
          _Panel(children: [_about()]),
        ],
      ),
    );
  }

  Widget _speechSpeed(BuildContext context) {
    return Obx(() {
      final speed = controller.settings.speechSpeed.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: const Text('语速'),
            subtitle: const Text('1.0 为正常语速，跟读建议 0.7–0.9'),
            trailing: Text('${speed.toStringAsFixed(2)}×'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              value: speed,
              min: 0.5,
              max: 1.5,
              divisions: 20,
              label: '${speed.toStringAsFixed(2)}×',
              onChanged: controller.settings.setSpeechSpeed,
            ),
          ),
        ],
      );
    });
  }

  Widget _previewTile() {
    return Obx(() {
      final available = controller.tts.japaneseAvailable.value;
      return ListTile(
        title: const Text('试听'),
        subtitle: Text(
          available ? '日本語の発音を確認します。' : '未检测到日语语音，朗读可能无声',
        ),
        trailing: const Icon(Icons.volume_up_outlined),
        onTap: controller.previewSpeech,
      );
    });
  }

  Widget _annotationStyle(BuildContext context) {
    return Obx(() {
      final current = controller.settings.annotationStyle.value;
      return ListTile(
        title: const Text('展开后的注音'),
        subtitle: Text('原文上方那一行显示 ${current.label}'),
        trailing: DropdownButton<AnnotationStyle>(
          value: current,
          underline: const SizedBox.shrink(),
          items: [
            for (final style in AnnotationStyle.values)
              DropdownMenuItem(value: style, child: Text(style.label)),
          ],
          onChanged: (style) {
            if (style != null) controller.settings.setAnnotationStyle(style);
          },
        ),
      );
    });
  }

  Widget _inlineFurigana() {
    return Obx(() => SwitchListTile(
          title: const Text('汉字上方标注假名'),
          subtitle: const Text('展开时在汉字头顶叠加 ruby 注音'),
          value: controller.settings.inlineFurigana.value,
          onChanged: controller.settings.setInlineFurigana,
        ));
  }

  Widget _fontScale(BuildContext context) {
    return Obx(() {
      final scale = controller.settings.fontScale.value;
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
              onChanged: controller.settings.setFontScale,
            ),
          ),
        ],
      );
    });
  }

  Widget _expandMode() {
    return Obx(() => SwitchListTile(
          title: const Text('一次只展开一行'),
          subtitle: const Text('关掉后可以同时展开多行对照'),
          value: controller.settings.expandSingle.value,
          onChanged: controller.settings.setExpandSingle,
        ));
  }

  Widget _contentSource(BuildContext context) {
    return Obx(() => ListTile(
          title: const Text('内容源'),
          subtitle: Text(
            controller.settings.contentBaseUrl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editBaseUrl(context),
        ));
  }

  Future<void> _editBaseUrl(BuildContext context) async {
    final field = TextEditingController(text: controller.settings.contentBaseUrl);
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
    if (result != null) {
      await controller.applyBaseUrl(result);
    }
  }

  Widget _cache(BuildContext context) {
    return Obx(() {
      final stats = controller.cacheStats.value;
      final subtitle = stats == null
          ? '统计中…'
          : '${stats.articleCount} 篇课文 · ${stats.readableSize}'
              '${stats.lastFetchedAt == null ? '' : ' · 最近更新 ${_formatTime(stats.lastFetchedAt!)}'}';
      return ListTile(
        title: const Text('离线缓存'),
        subtitle: Text(subtitle),
        trailing: TextButton(
          onPressed: () => _confirmClear(context),
          child: const Text('清除'),
        ),
      );
    });
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除离线缓存？'),
        content: const Text('已下载的课文会被删除，下次打开需要联网重新拉取。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) {
      await controller.clearCache();
      Get.snackbar('已清除', '本地缓存已清空并重新拉取课文列表',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  Widget _about() {
    return Obx(() => ListTile(
          title: const Text('JA 日语精读'),
          subtitle: Text(
            controller.appVersion.isEmpty ? '版本读取中…' : '版本 ${controller.appVersion}',
          ),
          trailing: const Icon(Icons.info_outline),
        ));
  }

  static String _formatTime(DateTime time) {
    final local = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.month}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

class _PhaseTwoCard extends StatelessWidget {
  const _PhaseTwoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text('学习画像与 AI 教练',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('二期',
                      style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '会记录阅读时长、展开过的行、反复播放的句子和标记的生词，'
              '按语法模块号聚合出薄弱点，再由 AI 生成学习画像和下一步建议。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
            ),
          ],
        ),
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
    return Card(
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
