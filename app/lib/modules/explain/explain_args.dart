import '../../data/models/article.dart';

/// 单句 AI讲解页入参。
class ExplainArgs {
  const ExplainArgs({
    required this.line,
    required this.isDialogue,
    this.title = 'AI讲解',
  });

  final ArticleLine line;
  final bool isDialogue;
  final String title;
}
