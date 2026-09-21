import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja/data/models/article.dart';
import 'package:ja/modules/lesson/lesson_vocab.dart';
import 'package:ja/modules/reader/widgets/furigana_text.dart';
import 'package:ja/services/word_audio_player.dart';

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
      expect(line.grammar, isEmpty);
      expect(article.audio, isNull, reason: '构建脚本没注入音频时应为 null');
      expect(article.cues, isEmpty);
      expect(article.hasAudio, isFalse);
    });

    test('读到构建期注入的整篇音频与 cues', () {
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
  "audio": "audio/T03-audio/article.mp3",
  "cues": [{"id": "l01", "startMs": 0, "endMs": 1200}],
  "lines": [{
    "id": "l01", "jp": "本文。", "reading": "ほんぶん。", "zh": "正文。"
  }]
}
''');

      expect(article.audio, 'audio/T03-audio/article.mp3');
      expect(article.cues.single.id, 'l01');
      expect(article.cues.single.endMs, 1200);
      expect(article.hasAudio, isTrue);
    });
  });

  group('FuriganaText', () {
    const sentence = '中国から来ました。';
    const baseStyle = TextStyle(fontSize: 18);
    const rubyStyle = TextStyle(fontSize: 10);

    Future<void> pumpAt(WidgetTester tester, Widget child) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: child),
        ),
      ));
    }

    const sample = FuriganaText(
      text: sentence,
      spans: [
        // ちゅうごく 比「中国」宽得多，正是会把正文戳出空隙的那种情况
        RubySpan(start: 0, len: 2, ruby: 'ちゅうごく'),
        RubySpan(start: 4, len: 1, ruby: 'き'),
      ],
      baseStyle: baseStyle,
      rubyStyle: rubyStyle,
    );

    testWidgets('注音渲染在汉字上方', (tester) async {
      await pumpAt(tester, sample);

      expect(find.text('中国'), findsOneWidget);
      expect(find.text('ちゅうごく'), findsOneWidget);
      expect(find.text('来'), findsOneWidget);
      expect(find.text('き'), findsOneWidget);

      expect(
        tester.getTopLeft(find.text('ちゅうごく')).dy,
        lessThan(tester.getTopLeft(find.text('中国')).dy),
      );
    });

    testWidgets('汉字与周围文字排在同一行', (tester) async {
      // Stack 的基线若被浮在上面的 ruby 抢走，汉字会掉到正文下一行，
      // 整体高度会从一行变成两行。
      await pumpAt(tester, sample);

      final oneLine = 18 * 1.5 + 10 * 1.3;
      expect(
        tester.getSize(find.byType(FuriganaText)).height,
        closeTo(oneLine, 2),
      );
    });

    testWidgets('注音比汉字宽时不撑宽正文', (tester) async {
      // 早先的实现让 ruby 参与宽度计算，「中国」「上手」两侧会被顶出空隙，
      // 整句还会因为逐字取整误差提前折行。现在 ruby 向两侧探出，正文宽度
      // 应当与不带注音的同一句话完全一致。
      await pumpAt(tester, sample);
      final withRuby = tester.getSize(find.byType(FuriganaText)).width;

      await pumpAt(tester, const Text(sentence, style: baseStyle));
      final plain = tester.getSize(find.byType(Text).first).width;

      expect(withRuby, closeTo(plain, 0.5));
    });

    testWidgets('宽度不够时正常折行', (tester) async {
      await pumpAt(tester, const SizedBox(width: 60, child: sample));

      final oneLine = 18 * 1.5 + 10 * 1.3;
      expect(
        tester.getSize(find.byType(FuriganaText)).height,
        greaterThan(oneLine * 1.5),
        reason: '窄容器里应当折成多行',
      );
    });
  });

  group('精讲笔记词表', () {
    test('读音表词列改写成 ja-word 链接', () {
      const md = '''
| 日语 | 读音 | 中文 |
|------|------|------|
| こんにちは | こんにちは | 你好 |
| 日本 | にほん／にっぽん | 日本 |
''';
      final out = rewriteLessonVocabLinks(md);
      expect(out, contains('[こんにちは](ja-word:'));
      expect(out, contains('[日本](ja-word:'));
      expect(out, contains(Uri.encodeComponent('にほん／にっぽん')));
      // 读音列本身不变
      expect(out, contains('| こんにちは | 你好 |'));
    });

    test('无读音列的表不改写', () {
      const md = '''
| 天 | 重点 |
|----|------|
| Day1 | 假名 |
''';
      expect(rewriteLessonVocabLinks(md), md);
    });

    test('助词罗马字读音改播假名列', () {
      const md = '''
| 助词 | 读音 | 用法 |
|------|------|------|
| は | wa | 主题 |
''';
      final out = rewriteLessonVocabLinks(md);
      expect(out, contains('ja-word:${Uri.encodeComponent('は')}'));
    });

    test('词音频路径与 Python text_key 一致', () {
      // 与 tools/lesson_vocab.py text_key("こんにちは") 对齐
      expect(
        WordAudioPlayer.textKey('こんにちは'),
        '50ae5df3daa73892',
      );
      expect(
        WordAudioPlayer.relativePathFor('こんにちは'),
        'audio/words/50ae5df3daa73892.mp3',
      );
    });
  });
}
