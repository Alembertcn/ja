import 'package:get/get.dart';

import '../../data/models/article.dart';
import '../../data/repository/content_repository.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';

class ReaderController extends GetxController {
  ReaderController(this.summary);

  /// 从列表页带过来的轻量信息，正文没到之前先用它渲染标题。
  final ArticleSummary summary;

  final ContentRepository _repo = Get.find<ContentRepository>();
  final TtsService tts = Get.find<TtsService>();
  final SettingsService settings = Get.find<SettingsService>();

  final Rxn<Article> article = Rxn<Article>();
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final RxnString offlineNotice = RxnString();

  /// 当前展开的行。单行模式下最多一个元素。
  final RxSet<String> expandedLineIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    tts.stop();
    super.onClose();
  }

  Future<void> load({bool force = false}) async {
    loading.value = article.value == null;
    error.value = null;
    try {
      final result = await _repo.loadArticle(summary, forceRefresh: force);
      article.value = result.data;
      offlineNotice.value =
          result.isStale ? '当前显示的是离线缓存（${result.networkError}）' : null;
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  bool isExpanded(String lineId) => expandedLineIds.contains(lineId);

  void toggleLine(String lineId) {
    if (expandedLineIds.contains(lineId)) {
      expandedLineIds.remove(lineId);
      return;
    }
    if (settings.expandSingle.value) {
      expandedLineIds.clear();
    }
    expandedLineIds.add(lineId);
  }

  void expandAll() {
    final lines = article.value?.lines;
    if (lines == null) return;
    expandedLineIds.addAll(lines.map((line) => line.id));
  }

  void collapseAll() => expandedLineIds.clear();

  Future<void> playLine(ArticleLine line) => tts.speakLine(line.id, line.jp);

  Future<void> playAll() async {
    final lines = article.value?.lines;
    if (lines == null || lines.isEmpty) return;
    await tts.speakAll(
      lines.map((line) => SpeakItem(line.id, line.jp)).toList(growable: false),
    );
  }

  Future<void> stop() => tts.stop();
}
