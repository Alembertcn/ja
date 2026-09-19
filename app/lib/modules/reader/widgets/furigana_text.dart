import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../data/models/article.dart';

/// 在汉字上方叠加 ruby 注音。
///
/// 没用现成的包：日语横排按字符断行本来就合法，把无注音的部分拆成单字交给 [Wrap]，
/// 既能正确换行，又能让带注音的汉字块保持整体不被拆开。
class FuriganaText extends StatelessWidget {
  const FuriganaText({
    super.key,
    required this.text,
    required this.spans,
    required this.baseStyle,
    required this.rubyStyle,
  });

  final String text;
  final List<RubySpan> spans;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;

  @override
  Widget build(BuildContext context) {
    final rubyHeight = (rubyStyle.fontSize ?? 10) * 1.35;
    final children = <Widget>[];

    void addPlain(String chunk) {
      for (final char in chunk.characters) {
        children.add(_Unit(
          base: char,
          ruby: null,
          baseStyle: baseStyle,
          rubyStyle: rubyStyle,
          rubyHeight: rubyHeight,
        ));
      }
    }

    final ordered = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    for (final span in ordered) {
      if (span.start < cursor || span.end > text.length) continue;
      if (span.start > cursor) {
        addPlain(text.substring(cursor, span.start));
      }
      children.add(_Unit(
        base: text.substring(span.start, span.end),
        ruby: span.ruby,
        baseStyle: baseStyle,
        rubyStyle: rubyStyle,
        rubyHeight: rubyHeight,
      ));
      cursor = span.end;
    }
    if (cursor < text.length) {
      addPlain(text.substring(cursor));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 2,
      children: children,
    );
  }
}

class _Unit extends StatelessWidget {
  const _Unit({
    required this.base,
    required this.ruby,
    required this.baseStyle,
    required this.rubyStyle,
    required this.rubyHeight,
  });

  final String base;
  final String? ruby;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;
  final double rubyHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: rubyHeight,
          child: ruby == null
              ? null
              : Center(
                  child: Text(
                    ruby!,
                    style: rubyStyle,
                    locale: japaneseLocale,
                    textHeightBehavior: const TextHeightBehavior(
                      applyHeightToFirstAscent: false,
                    ),
                  ),
                ),
        ),
        Text(base, style: baseStyle, locale: japaneseLocale),
      ],
    );
  }
}