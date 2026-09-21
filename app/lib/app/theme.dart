import 'package:flutter/material.dart';

/// 日语文本要显式带上 ja 的 locale，否则系统可能拿中文字体渲染汉字，
/// 部分字形（直、骨、今 等）会长得不像日文。
const Locale japaneseLocale = Locale('ja', 'JP');

/// 全局圆角刻度；可点击表面请配合 [Material.borderRadius] / theme shape 使用，
/// 否则水波纹仍会按直角画在祖先 Material 上。
class AppRadii {
  AppRadii._();

  static const double sm = 10;
  static const double md = 14;
  static const double lg = 16;
  static const double xl = 20;

  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius xlAll = BorderRadius.circular(xl);

  static final ShapeBorder cardShape = RoundedRectangleBorder(borderRadius: lgAll);
  static final ShapeBorder tileShape = RoundedRectangleBorder(borderRadius: mdAll);
  static final ShapeBorder sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(xl)),
  );
}

/// MOJi 风格品牌色与通用装饰（浅色 / 深色各一套）。
class AppColors {
  AppColors._();

  static const Color brand = Color(0xFFFF2D55);

  // —— 浅色 ——
  static const Color _brandSoftLight = Color(0xFFFFE9EE);
  static const Color _brandWashLight = Color(0xFFFFF7F8);
  static const Color _pageBgLight = Color(0xFFF7F7F7);
  static const Color _cardLight = Colors.white;
  static const Color _mutedChipLight = Color(0xFFF0F0F0);
  static const Color _mutedChipFgLight = Color(0xFF666666);

  // —— 深色 ——
  static const Color _brandSoftDark = Color(0xFF4A1524);
  static const Color _brandWashDark = Color(0xFF2A1218);
  static const Color _pageBgDark = Color(0xFF121212);
  static const Color _cardDark = Color(0xFF1E1E1E);
  static const Color _mutedChipDark = Color(0xFF2C2C2C);
  static const Color _mutedChipFgDark = Color(0xFFB0B0B0);

  static const Color cardShadow = Color(0x0A000000);

  static bool _isLight(ColorScheme scheme) => scheme.brightness == Brightness.light;

  static Color pageBg(ColorScheme scheme) =>
      _isLight(scheme) ? _pageBgLight : _pageBgDark;

  static Color card(ColorScheme scheme) =>
      _isLight(scheme) ? _cardLight : _cardDark;

  static Color brandSoft(ColorScheme scheme) =>
      _isLight(scheme) ? _brandSoftLight : _brandSoftDark;

  static Color brandWash(ColorScheme scheme) =>
      _isLight(scheme) ? _brandWashLight : _brandWashDark;

  static Color mutedChipBg(ColorScheme scheme) =>
      _isLight(scheme) ? _mutedChipLight : _mutedChipDark;

  static Color mutedChipFg(ColorScheme scheme) =>
      _isLight(scheme) ? _mutedChipFgLight : _mutedChipFgDark;

  /// 头图渐变：浅色粉洗 → 深色暗红底。
  static LinearGradient headerGradient(ColorScheme scheme) {
    if (_isLight(scheme)) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_brandSoftLight, _brandWashLight, _pageBgLight],
        stops: [0.0, 0.55, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_brandWashDark, _pageBgDark, _pageBgDark],
      stops: [0.0, 0.6, 1.0],
    );
  }

  /// 等级徽标等浅色玻璃底 / 深色半透明底。
  static Color glassFill(ColorScheme scheme) => _isLight(scheme)
      ? Colors.white.withValues(alpha: 0.85)
      : scheme.surfaceContainerHighest.withValues(alpha: 0.7);

  /// 按周次生成确定性封面渐变，深浅共用（本身够醒目）。
  static LinearGradient coverGradient(int week) {
    final hues = <List<Color>>[
      const [Color(0xFFFF8A9B), Color(0xFFFF2D55)],
      const [Color(0xFFFFB4A2), Color(0xFFFF6B6B)],
      const [Color(0xFFFFC6D9), Color(0xFFE91E63)],
      const [Color(0xFFFFAB91), Color(0xFFFF5252)],
      const [Color(0xFFF8BBD0), Color(0xFFEC407A)],
      const [Color(0xFFFFCCBC), Color(0xFFFF7043)],
    ];
    final pair = hues[week.abs() % hues.length];
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: pair,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: isLight ? const Color(0xFFFFE9EE) : const Color(0xFF4A1524),
      onPrimaryContainer: isLight ? AppColors.brand : const Color(0xFFFFCDD5),
      surface: isLight ? Colors.white : const Color(0xFF1E1E1E),
      onSurface: isLight ? const Color(0xFF1C1B1F) : const Color(0xFFE6E1E5),
      onSurfaceVariant: isLight ? const Color(0xFF49454F) : const Color(0xFFCAC4D0),
      surfaceContainerLowest: isLight ? const Color(0xFFF7F7F7) : const Color(0xFF121212),
      surfaceContainerHighest: isLight ? const Color(0xFFE8E8E8) : const Color(0xFF2C2C2C),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.pageBg(scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? Colors.transparent : scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card(scheme),
        margin: EdgeInsets.zero,
        shadowColor: AppColors.cardShadow,
        clipBehavior: Clip.antiAlias,
        shape: AppRadii.cardShape,
      ),
      // ExpansionTile / 底部弹层等：shape 决定水波纹裁剪轮廓。
      expansionTileTheme: ExpansionTileThemeData(
        shape: AppRadii.tileShape,
        collapsedShape: AppRadii.tileShape,
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 60,
        backgroundColor: scheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.brand : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.brand : scheme.onSurfaceVariant,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.brand,
        thumbColor: AppColors.brand,
        inactiveTrackColor: scheme.outlineVariant,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: AppRadii.sheetShape,
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: AppRadii.cardShape,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        shape: AppRadii.cardShape,
      ),
    );
  }

  /// 设置弹窗选中档位：粉字 + 粉描边。
  static BoxDecoration chipSelected(ColorScheme scheme) => BoxDecoration(
        color: AppColors.card(scheme),
        borderRadius: AppRadii.xlAll,
        border: Border.all(color: AppColors.brand, width: 1.2),
      );

  /// 设置弹窗未选中档位。
  static BoxDecoration chipPlain(ColorScheme scheme) => BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: AppRadii.xlAll,
      );

  static TextStyle chipLabel(bool selected, ColorScheme scheme) => TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? AppColors.brand : scheme.onSurface,
      );
}
