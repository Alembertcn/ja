class PracticeArgs {
  const PracticeArgs({
    required this.path,
    required this.title,
  });

  /// 内容源相对路径，如 `exercises/W01.json`。
  final String path;
  final String title;
}
