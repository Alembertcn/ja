import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// 圆角可点击表面：水波纹画在本地 [Material] 上，贴合圆角轮廓。
///
/// 不要用「外层 [Container] 圆角 + 内层 [InkWell]」——水波纹会画到路由级
/// Material 上，变成直角，外层 clip 也裁不到。
class AppInkSurface extends StatelessWidget {
  const AppInkSurface({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.color,
    this.shadowed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? color;
  final bool shadowed;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppRadii.lgAll;
    final scheme = Theme.of(context).colorScheme;
    final surface = Material(
      color: color ?? AppColors.card(scheme),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? child
          : InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: child,
            ),
    );
    if (!shadowed) return surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: surface,
    );
  }
}

/// 圆角分组面板：内部 [ListTile] 等水波纹贴合面板外轮廓。
class AppPanel extends StatelessWidget {
  const AppPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.shadowed = true,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final bool shadowed;

  @override
  Widget build(BuildContext context) {
    return AppInkSurface(
      borderRadius: borderRadius ?? AppRadii.lgAll,
      shadowed: shadowed,
      child: child,
    );
  }
}
