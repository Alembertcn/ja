import 'package:flutter/material.dart';

/// 日语文本要显式带上 ja 的 locale，否则系统可能拿中文字体渲染汉字，
/// 部分字形（直、骨、今 等）会长得不像日文。
const Locale japaneseLocale = Locale('ja', 'JP');

class AppTheme {
  AppTheme._();

  static const Color _seed = Color(0xFF3F6BB5);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
