import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../data/models/article.dart';
import '../../services/settings_cubit.dart';
import '../reader/widgets/furigana_text.dart';
import 'explain_args.dart';

class ExplainView extends StatefulWidget {
  const ExplainView({super.key, required this.args});

  final ExplainArgs args;

  @override
  State<ExplainView> createState() => _ExplainViewState();
}

class _ExplainViewState extends State<ExplainView> {
  final TextEditingController _input = TextEditingController();
  final List<_ChatBubble> _messages = [];
  bool _explained = false;

  ExplainArgs get args => widget.args;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _runExplain() {
    setState(() {
      _explained = true;
      if (_messages.isEmpty) {
        _messages.add(_ChatBubble(
          fromAi: true,
          text: _buildLocalExplain(args.line),
        ));
      }
    });
  }

  String _buildLocalExplain(ArticleLine line) {
    final buf = StringBuffer();
    if (line.grammar.isEmpty &&
        line.vocab.isEmpty &&
        (line.note == null || line.note!.isEmpty)) {
      return '本句暂无讲解内容。';
    }
    if (line.grammar.isNotEmpty) {
      buf.writeln('【语法】');
      for (final g in line.grammar) {
        final module = g.module == null ? '' : '（${g.module}）';
        buf.writeln('· ${g.point}$module');
        buf.writeln('  ${g.explain}');
      }
      buf.writeln();
    }
    if (line.vocab.isNotEmpty) {
      buf.writeln('【生词】');
      for (final v in line.vocab) {
        final pos = v.pos == null ? '' : ' ${v.pos}';
        final note = v.note == null ? '' : ' ※${v.note}';
        buf.writeln('· ${v.word}（${v.reading}）$pos ${v.zh}$note');
      }
      buf.writeln();
    }
    if (line.note != null && line.note!.isNotEmpty) {
      buf.writeln('【笔记】');
      buf.writeln(line.note);
    }
    return buf.toString().trim();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatBubble(fromAi: false, text: text));
      _messages.add(const _ChatBubble(
        fromAi: true,
        text: '追问功能即将支持，当前可先点「AI讲解」查看本句语法与生词。',
      ));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocBuilder<SettingsCubit, SettingsState>(
      buildWhen: (a, b) =>
          a.fontScale != b.fontScale ||
          a.inlineFurigana != b.inlineFurigana ||
          a.annotationStyle != b.annotationStyle,
      builder: (context, settings) {
        return Scaffold(
          backgroundColor: AppColors.pageBg(scheme),
          appBar: AppBar(
            backgroundColor: AppColors.card(scheme),
            title: Text(
              'AI讲解',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _SentenceCard(
                      line: args.line,
                      isDialogue: args.isDialogue,
                      fontScale: settings.fontScale,
                      inlineFurigana: settings.inlineFurigana,
                      annotationStyle: settings.annotationStyle,
                      explained: _explained,
                      onExplain: _runExplain,
                    ),
                    if (_explained) ...[
                      const SizedBox(height: 12),
                      for (final msg in _messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BubbleTile(bubble: msg),
                        ),
                    ],
                  ],
                ),
              ),
              _InputBar(
                controller: _input,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SentenceCard extends StatelessWidget {
  const _SentenceCard({
    required this.line,
    required this.isDialogue,
    required this.fontScale,
    required this.inlineFurigana,
    required this.annotationStyle,
    required this.explained,
    required this.onExplain,
  });

  final ArticleLine line;
  final bool isDialogue;
  final double fontScale;
  final bool inlineFurigana;
  final AnnotationStyle annotationStyle;
  final bool explained;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: 18 * fontScale,
      height: 1.6,
      color: scheme.onSurface,
      locale: japaneseLocale,
    );
    final rubyStyle = TextStyle(
      fontSize: 10 * fontScale,
      height: 1.0,
      color: scheme.onSurfaceVariant,
    );

    final annotation = switch (annotationStyle) {
      AnnotationStyle.kana => line.reading,
      AnnotationStyle.romaji => line.romaji ?? line.reading,
      AnnotationStyle.none => '',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
          if (isDialogue && line.speaker != null) ...[
            Text(
              '${line.speaker}：',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
                locale: japaneseLocale,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (!inlineFurigana && annotation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                annotation,
                style: TextStyle(
                  fontSize: 12 * fontScale,
                  color: AppColors.brand,
                  locale: annotationStyle == AnnotationStyle.kana ? japaneseLocale : null,
                ),
              ),
            ),
          if (inlineFurigana && line.furigana.isNotEmpty)
            FuriganaText(
              text: line.jp,
              spans: line.furigana,
              baseStyle: baseStyle,
              rubyStyle: rubyStyle,
            )
          else
            Text(line.jp, style: baseStyle, locale: japaneseLocale),
          const SizedBox(height: 12),
          Text(
            line.zh,
            style: TextStyle(
              fontSize: 14 * fontScale,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: explained ? null : onExplain,
              icon: const Icon(Icons.auto_awesome, color: AppColors.brand, size: 18),
              label: Text(
                explained ? '已生成讲解' : 'AI讲解',
                style: TextStyle(
                  color: explained ? scheme.outline : AppColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: explained
                      ? scheme.outlineVariant
                      : AppColors.brand.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble {
  const _ChatBubble({required this.fromAi, required this.text});

  final bool fromAi;
  final String text;
}

class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.bubble});

  final _ChatBubble bubble;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final align = bubble.fromAi ? Alignment.centerLeft : Alignment.centerRight;
    final bg = bubble.fromAi ? AppColors.card(scheme) : AppColors.brandSoft(scheme);
    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: AppColors.cardShadow, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          bubble.text,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppColors.card(scheme),
      elevation: 8,
      shadowColor: AppColors.cardShadow,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 8 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: '输入消息',
                      filled: true,
                      fillColor: AppColors.pageBg(scheme),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.brand,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onSend,
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '内容由AI生成，仅供参考',
              style: TextStyle(fontSize: 11, color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
