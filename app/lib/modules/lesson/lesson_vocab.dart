// 精讲笔记 Markdown 词表：识别「读音」表并为词列注入 ja-word 链接。
// 解析规则与 tools/lesson_vocab.py 保持一致。

final _jpChar = RegExp(r'[\u3040-\u30ff\u3400-\u9fff]');
final _bold = RegExp(r'\*\*([^*]+)\*\*');
final _mdLink = RegExp(r'\[([^\]]+)\]\([^)]+\)');
final _sepCell = RegExp(r'^:?-{3,}:?$');

String stripMd(String text) {
  var t = text.replaceAllMapped(_bold, (m) => m[1]!);
  t = t.replaceAllMapped(_mdLink, (m) => m[1]!);
  return t.trim();
}

List<String> splitRow(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('|')) return const [];
  var inner = trimmed;
  if (inner.startsWith('|')) inner = inner.substring(1);
  if (inner.endsWith('|')) inner = inner.substring(0, inner.length - 1);
  return inner.split('|').map((c) => c.trim()).toList();
}

bool isSepRow(List<String> cells) {
  if (cells.isEmpty) return false;
  return cells.every((c) => _sepCell.hasMatch(c.replaceAll(' ', '')));
}

bool hasJp(String text) => _jpChar.hasMatch(text);

String speakText(String word, String reading) {
  final w = stripMd(word);
  final r = stripMd(reading);
  if (r.isNotEmpty && hasJp(r)) return r;
  if (w.isNotEmpty) return w;
  return r;
}

int? _wordColumnIndex(List<String> header, int readingIdx) {
  for (final name in ['日语', '词', '助词']) {
    final i = header.indexOf(name);
    if (i >= 0) return i;
  }
  for (var j = 0; j < header.length; j++) {
    if (j != readingIdx) return j;
  }
  return null;
}

/// 把带「读音」列的词表词列改成 `[词](ja-word:…)`，源文件本身不变。
String rewriteLessonVocabLinks(String md) {
  final lines = md.split('\n');
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    final header = splitRow(lines[i]);
    if (header.length >= 2 &&
        i + 1 < lines.length &&
        isSepRow(splitRow(lines[i + 1]))) {
      final readingIdx = header.indexOf('读音');
      final wordIdx =
          readingIdx >= 0 ? _wordColumnIndex(header, readingIdx) : null;
      if (readingIdx >= 0 && wordIdx != null) {
        out.add(lines[i]);
        out.add(lines[i + 1]);
        i += 2;
        while (i < lines.length) {
          final cells = List<String>.from(splitRow(lines[i]));
          if (cells.isEmpty || isSepRow(cells)) break;
          final need = (wordIdx > readingIdx ? wordIdx : readingIdx) + 1;
          if (cells.length < need) break;
          final word = cells[wordIdx];
          final reading = cells[readingIdx];
          if (!word.startsWith('[')) {
            final speak = speakText(word, reading);
            if (speak.isNotEmpty) {
              cells[wordIdx] =
                  '[${stripMd(word)}](ja-word:${Uri.encodeComponent(speak)})';
              lines[i] = '| ${cells.join(' | ')} |';
            }
          }
          out.add(lines[i]);
          i++;
        }
        continue;
      }
    }
    out.add(lines[i]);
    i++;
  }
  final joined = out.join('\n');
  if (md.endsWith('\n') && !joined.endsWith('\n')) return '$joined\n';
  return joined;
}
