import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja/data/models/article.dart';
import 'package:ja/modules/reader/widgets/furigana_text.dart';

void main() {
  group('Article 解析', () {
    test('按契约解析一行课文', () {
      final article = Article.parse('''
{
  "id": "T01-test",
  "title": "テスト",
  "titleZh": "测试",
  "stage": "P0",
  "week": 1,
  "level": "N5",
  "type": "dialogue",
  "updatedAt": "2026-09-19",
  "lines": [
    {
      "id": "l01",
      "speaker": "李",
      "jp": "中国から来ました。",
      "reading": "ちゅうごくからきました",
      "romaji": "Chūgoku kara kimashita",
      "furigana": [{"start": 0, "len": 2, "ruby": "ちゅうごく"}],
      "zh": "我从中国来。",
      "grammar": [{"module": "G0-03", "point": "から", "explain": "表示起点"}],
      "vocab": [{"word": "中国", "reading": "ちゅうごく", "pos": "名詞", "zh": "中国"}]
    }
  ]
}
''');

      expect(article.isDialogue, isTrue);
      final line = article.lines.single;
      expect(line.speaker, '李');
      expect(line.furigana.single.ruby, 'ちゅうごく');
      expect(line.grammar.single.module, 'G0-03');
      expect(line.vocab.single.zh, '中国');
      // 契约里缺省即为完整句
      expect(line.isSentenceEnd, isTrue);
    });

    test('缺省的可选字段不会炸', () {
      final article = Article.parse('''
{
  "id": "T02-min",
  "title": "最小",
  "titleZh": "最小",
  "stage": "P2",
  "week": 20,
  "level": "N2",
  "type": "article",
  "updatedAt": "2026-09-19",
  "lines": [{"id": "l01", "jp": "本文。", "reading": "ほんぶん。", "zh": "正文。"}]
}
''');

      final line = article.lines.single;
      expect(line.speaker, isNull);
      expect(line.furigana, isEmpty);
      expect(line.hasDetail, isFalse);
      expect(line.audio, isNull, reason: '没有预生成音频时应为 null，播放要回落 TTS');
    });

    test('读到构建期注入的音频路径', () {
      final article = Article.parse('''
{
  "id": "T03-audio",
  "title": "音声",
  "titleZh": "音频",
  "stage": "P0",
  "week": 1,
  "level": "N5",
  "type": "article",
  "updatedAt": "2026-09-19",
  "lines": [{
    "id": "l01", "jp": "本文。", "reading": "ほんぶん。", "zh": "正文。",
    "audio": "audio/T03-audio/l01.mp3"
  }]
}
''');

      expect(article.lines.single.audio, 'audio/T03-audio/l01.mp3');
    });
  });

  group('FuriganaText', () {
    Future<void> pumpSample(WidgetTester tester, {double width = 400}) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const FuriganaText(
                  text: '中国から来ました。',
                  spans: [
                    RubySpan(start: 0, len: 2, ruby: 'ちゅうごく'),
                    RubySpan(start: 4, len: 1, ruby: 'き'),
                  ],
                  baseStyle: TextStyle(fontSize: 18),
                  rubyStyle: TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('注音渲染在汉字上方', (tester) async {
      await pumpSample(tester);

      expect(find.text('中国'), findsOneWidget);
      expect(find.text('ちゅうごく'), findsOneWidget);
      expect(find.text('来'), findsOneWidget);
      expect(find.text('き'), findsOneWidget);
      // 无注音的部分被拆成单字，便于按字换行
      expect(find.text('か'), findsOneWidget);

      expect(
        tester.getTopLeft(find.text('ちゅうごく')).dy,
        lessThan(tester.getTopLeft(find.text('中国')).dy),
      );
    });

    testWidgets('宽度够时整句排在同一行', (tester) async {
      // 曾经用 Center 包 ruby，它在宽松约束下会撑满整行，
      // 导致每个带注音的汉字块各占一行，整句被拆成四行。
      await pumpSample(tester);

      final kanji = tester.getTopLeft(find.text('中国')).dy;
      for (final char in ['か', 'ら', 'ま', 'し', 'た']) {
        expect(
          tester.getTopLeft(find.text(char)).dy,
          kanji,
          reason: '「$char」应当和「中国」在同一行',
        );
      }
      expect(tester.getTopLeft(find.text('来')).dy, kanji);
    });

    testWidgets('宽度不够时按字换行', (tester) async {
      await pumpSample(tester, width: 60);

      final first = tester.getTopLeft(find.text('中国')).dy;
      final last = tester.getTopLeft(find.text('。')).dy;
      expect(last, greaterThan(first), reason: '窄容器里应当折行');
    });
  });
}
