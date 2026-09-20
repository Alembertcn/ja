class LessonArgs {
  const LessonArgs({
    required this.path,
    required this.title,
  });

  /// 内容源相对路径，如 `lessons/W01_….md`
  final String path;
  final String title;
}
