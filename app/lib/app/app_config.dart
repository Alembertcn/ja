/// 全局常量与阶段元信息。
class AppConfig {
  AppConfig._();

  /// 内容源默认地址，指向本仓库的 GitHub Pages 发布目录。
  /// 用户可在「我的 → 内容源」里覆盖，方便本地起静态服务调试。
  static const String defaultContentBaseUrl = 'https://alembertcn.github.io/ja/';

  static const String manifestPath = 'manifest.json';

  /// 网络超时。内容都是小 JSON，给得紧一点，失败快速回落缓存。
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 12);
}

/// 学习计划里的四个阶段，列表页按此分组。
enum LearningStage {
  p0('P0', '基础搭建', 'N5–N4 假名、基础语法与听说读写'),
  p1('P1', '过渡巩固', 'N3 语法词汇闭环，短文读写'),
  p2('P2', 'N2 专项', 'N2 语法·词汇·汉字·读听系统学完'),
  p3('P3', '模考冲刺', '真题节奏、弱项补洞、时间分配');

  const LearningStage(this.code, this.title, this.description);

  final String code;
  final String title;
  final String description;

  static LearningStage? fromCode(String? code) {
    for (final stage in LearningStage.values) {
      if (stage.code == code) return stage;
    }
    return null;
  }

  /// 未知阶段排在最后。
  static int orderOf(String? code) {
    final stage = fromCode(code);
    return stage?.index ?? LearningStage.values.length;
  }
}
