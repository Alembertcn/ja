import 'package:get/get.dart';

import '../../app/app_config.dart';
import '../../data/models/article.dart';
import '../../data/repository/content_repository.dart';

/// 列表页的一个阶段分区。
class StageGroup {
  const StageGroup({required this.stage, required this.stageCode, required this.articles});

  final LearningStage? stage;
  final String stageCode;
  final List<ArticleSummary> articles;

  String get title => stage == null ? stageCode : '${stage!.code} · ${stage!.title}';

  String get subtitle => stage?.description ?? '';
}

class LibraryController extends GetxController {
  final ContentRepository _repo = Get.find<ContentRepository>();

  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  /// 回落到缓存时的提示文案，非空就在列表顶部显示一条横幅。
  final RxnString offlineNotice = RxnString();
  final RxList<ArticleSummary> articles = <ArticleSummary>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  List<StageGroup> get groups {
    final buckets = <String, List<ArticleSummary>>{};
    for (final article in articles) {
      buckets.putIfAbsent(article.stage, () => []).add(article);
    }

    final codes = buckets.keys.toList()
      ..sort((a, b) => LearningStage.orderOf(a).compareTo(LearningStage.orderOf(b)));

    return codes.map((code) {
      final list = buckets[code]!
        ..sort((a, b) {
          final byWeek = a.week.compareTo(b.week);
          return byWeek != 0 ? byWeek : a.id.compareTo(b.id);
        });
      return StageGroup(
        stage: LearningStage.fromCode(code),
        stageCode: code,
        articles: list,
      );
    }).toList();
  }

  Future<void> load({bool force = false}) async {
    loading.value = articles.isEmpty;
    error.value = null;
    try {
      final result = await _repo.loadManifest(forceRefresh: force);
      articles.assignAll(result.data.articles);
      offlineNotice.value = result.isStale
          ? '当前显示的是离线缓存（${result.networkError}）'
          : null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> reload() => load(force: true);
}
