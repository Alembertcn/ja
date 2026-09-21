import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/article.dart';

/// 阅读主页的一句：原文 + 可展开翻译 + 句末 AI 入口；播放中浅粉底高亮。
/// 单击整块高亮区域跳播；「翻译」/ AI 图标单独响应，不触发跳播。
class LineTile extends StatefulWidget {
  const LineTile({
    super.key,
    required this.line,
    required this.isDialogue,
    required this.playing,
    required this.fontScale,
    required this.onTap,
    required this.onExplain,
  });

  final ArticleLine line;
  final bool isDialogue;
  final bool playing;
  final double fontScale;
  final VoidCallback onTap;
  final VoidCallback onExplain;

  @override
  State<LineTile> createState() => _LineTileState();
}

class _LineTileState extends State<LineTile> {
  bool _showZh = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = widget.line;
    final fontScale = widget.fontScale;
    final playing = widget.playing;

    final baseStyle = TextStyle(
      fontSize: 17 * fontScale,
      height: 1.55,
      color: scheme.onSurface,
      locale: japaneseLocale,
      fontWeight: playing ? FontWeight.w600 : FontWeight.w400,
    );

    return Material(
      color: playing ? AppColors.brandSoft(scheme) : Colors.transparent,
      borderRadius: AppRadii.smAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppRadii.smAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isDialogue && line.speaker != null) ...[
                _SpeakerTag(name: line.speaker!),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(line.jp, style: baseStyle, locale: japaneseLocale),
                    // 单独吃掉点击，避免触发行跳播
                    GestureDetector(
                      onTap: () => setState(() => _showZh = !_showZh),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 2),
                        child: Text(
                          _showZh ? '收起' : '翻译',
                          style: TextStyle(
                            fontSize: 12 * fontScale,
                            fontWeight: FontWeight.w500,
                            color: _showZh
                                ? AppColors.brand
                                : scheme.onSurfaceVariant.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topLeft,
                      child: _showZh
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                line.zh,
                                style: TextStyle(
                                  fontSize: 13 * fontScale,
                                  height: 1.45,
                                  color: scheme.onSurfaceVariant
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              if (line.isSentenceEnd)
                IconButton(
                  onPressed: widget.onExplain,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'AI讲解',
                  icon: Icon(
                    Icons.auto_awesome,
                    color: playing ? AppColors.brand : scheme.outline,
                  ),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeakerTag extends StatelessWidget {
  const _SpeakerTag({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSecondaryContainer,
          locale: japaneseLocale,
        ),
      ),
    );
  }
}
