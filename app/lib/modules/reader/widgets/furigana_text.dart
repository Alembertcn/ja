import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../app/theme.dart';
import '../../../data/models/article.dart';

/// 在汉字上方叠加 ruby 注音。
///
/// 无注音的部分作为普通 [TextSpan] 交给文本引擎排版，断行、标点压缩、字距都按
/// 日文规则走；只有带注音的汉字才是内联 widget。早先把每个字拆成独立 Text 丢给
/// Wrap 的做法会累积取整误差导致提前折行，行尾标点也没法压缩。
///
/// 注音比汉字宽时（「上手」配「じょうず」）让 ruby 向两侧探出，而不是撑宽汉字，
/// 这既是日文排版的惯例（ルビのはみ出し），也避免正文被戳出一个个空隙。
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
    final baseSize = baseStyle.fontSize ?? 16;
    final rubySize = rubyStyle.fontSize ?? baseSize * 0.55;
    final rubyHeight = rubySize * 1.3;

    final children = <InlineSpan>[];

    void addPlain(String chunk) {
      if (chunk.isNotEmpty) children.add(TextSpan(text: chunk));
    }

    final ordered = [...spans]..sort((a, b) => a.start.compareTo(b.start));
    var cursor = 0;
    for (final span in ordered) {
      if (span.start < cursor || span.end > text.length) continue;
      addPlain(text.substring(cursor, span.start));
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: _RubyUnit(
          base: text.substring(span.start, span.end),
          ruby: span.ruby,
          baseStyle: baseStyle,
          rubyStyle: rubyStyle,
          rubyHeight: rubyHeight,
        ),
      ));
      cursor = span.end;
    }
    addPlain(text.substring(cursor));

    return Text.rich(
      TextSpan(children: children),
      style: baseStyle,
      locale: japaneseLocale,
      // 给每行预留出注音的高度，否则探出去的 ruby 会被上一行压住
      strutStyle: StrutStyle(
        fontSize: baseSize,
        height: (baseSize * 1.5 + rubyHeight) / baseSize,
        forceStrutHeight: true,
      ),
    );
  }
}

/// 汉字块本身决定宽度和基线，ruby 用 Stack 浮在上方，不参与宽度计算。
class _RubyUnit extends StatelessWidget {
  const _RubyUnit({
    required this.base,
    required this.ruby,
    required this.baseStyle,
    required this.rubyStyle,
    required this.rubyHeight,
  });

  final String base;
  final String ruby;
  final TextStyle baseStyle;
  final TextStyle rubyStyle;
  final double rubyHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Text(base, style: baseStyle, locale: japaneseLocale),
        Positioned(
          top: -rubyHeight,
          // Stack report 的是所有孩子里最高的那条基线，ruby 浮在上面，
          // 不屏蔽的话整个单元会按 ruby 的基线去对齐，汉字就掉到正文下一行去了。
          child: _NoBaseline(
            child: Text(
              ruby,
              style: rubyStyle,
              locale: japaneseLocale,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
            ),
          ),
        ),
      ],
    );
  }
}

/// 让子节点在基线计算里「隐身」，其余行为与普通容器一致。
class _NoBaseline extends SingleChildRenderObjectWidget {
  const _NoBaseline({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoBaseline();
}

class _RenderNoBaseline extends RenderProxyBox {
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => null;
}
