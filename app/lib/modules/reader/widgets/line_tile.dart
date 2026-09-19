import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/article.dart';
import '../../../services/settings_service.dart';
import 'furigana_text.dart';

/// 一行课文。折叠时只有日语原文和播放键；
/// 展开后在原文上方插入注音，下方依次是翻译、语法解析和生词。
class LineTile extends StatelessWidget {
  const LineTile({
    super.key,
    required this.line,
    required this.isDialogue,
    required this.expanded,
    required this.playing,
    required this.fontScale,
    required this.annotationStyle,
    required this.inlineFurigana,
    required this.onTap,
    required this.onPlay,
  });

  final ArticleLine line;
  final bool isDialogue;
  final bool expanded;
  final bool playing;
  final double fontScale;
  final AnnotationStyle annotationStyle;
  final bool inlineFurigana;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final baseStyle = TextStyle(
      fontSize: 17 * fontScale,
      height: 1.5,
      color: scheme.onSurface,
      locale: japaneseLocale,
    );
    final rubyStyle = TextStyle(
      fontSize: 10 * fontScale,
      height: 1.0,
      color: scheme.onSurfaceVariant,
    );

    return Card(
      color: playing ? scheme.primaryContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (expanded) _annotationLine(context),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDialogue && line.speaker != null) ...[
                    _SpeakerTag(name: line.speaker!),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: expanded && inlineFurigana && line.furigana.isNotEmpty
                        ? FuriganaText(
                            text: line.jp,
                            spans: line.furigana,
                            baseStyle: baseStyle,
                            rubyStyle: rubyStyle,
                          )
                        : Text(line.jp, style: baseStyle, locale: japaneseLocale),
                  ),
                  if (line.isSentenceEnd)
                    IconButton(
                      onPressed: onPlay,
                      visualDensity: VisualDensity.compact,
                      tooltip: playing ? '停止' : '朗读这句',
                      icon: Icon(
                        playing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline,
                        color: playing ? scheme.primary : scheme.outline,
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: scheme.outlineVariant),
                const SizedBox(height: 10),
                Text(
                  line.zh,
                  style: TextStyle(
                    fontSize: 14 * fontScale,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (line.grammar.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(text: '语法'),
                  for (final point in line.grammar)
                    _GrammarRow(point: point, fontScale: fontScale),
                ],
                if (line.vocab.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _SectionLabel(text: '生词'),
                  for (final item in line.vocab)
                    _VocabRow(item: item, fontScale: fontScale),
                ],
                if (line.note != null && line.note!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    line.note!,
                    style: TextStyle(
                      fontSize: 12 * fontScale,
                      color: scheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _annotationLine(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = switch (annotationStyle) {
      AnnotationStyle.kana => line.reading,
      AnnotationStyle.romaji => line.romaji ?? line.reading,
      AnnotationStyle.none => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 40),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12 * fontScale,
          height: 1.4,
          color: scheme.primary,
          locale: annotationStyle == AnnotationStyle.kana ? japaneseLocale : null,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _GrammarRow extends StatelessWidget {
  const _GrammarRow({required this.point, required this.fontScale});

  final GrammarPoint point;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (point.module != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    point.module!,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Text(
                point.point,
                style: TextStyle(
                  fontSize: 13 * fontScale,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  locale: japaneseLocale,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            point.explain,
            style: TextStyle(
              fontSize: 12.5 * fontScale,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabRow extends StatelessWidget {
  const _VocabRow({required this.item, required this.fontScale});

  final VocabItem item;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5, right: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12.5 * fontScale, color: scheme.onSurfaceVariant),
          children: [
            TextSpan(
              text: item.word,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                locale: japaneseLocale,
              ),
            ),
            TextSpan(text: '（${item.reading}）', locale: japaneseLocale),
            if (item.pos != null) TextSpan(text: '${item.pos}　'),
            TextSpan(text: item.zh),
            if (item.note != null)
              TextSpan(
                text: '　※${item.note}',
                style: TextStyle(color: scheme.outline, fontSize: 11.5 * fontScale),
              ),
          ],
        ),
      ),
    );
  }
}
