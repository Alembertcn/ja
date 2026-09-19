import 'package:get/get.dart';

import '../../data/models/article.dart';
import '../../data/repository/content_repository.dart';
import '../../services/audio_cache_service.dart';
import '../../services/playback_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';

class ReaderController extends GetxController {
  ReaderController(this.summary);

  /// 从列表页带过来的轻量信息，正文没到之前先用它渲染标题。
  final ArticleSummary summary;

  final ContentRepository _repo = Get.find<ContentRepository>();
  final AudioCacheService _audioCache = Get.find<AudioCacheService>();
  final PlaybackService playback = Get.find<PlaybackService>();
  final TtsService tts = Get.find<TtsService>();
  final SettingsService settings = Get.find<SettingsService>();

  final Rxn<Article> article = Rxn<Article>();
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final RxnString offlineNotice = RxnString();

  /// 当前展开的行。单行模式下最多一个元素。
  final RxSet<String> expandedLineIds = <String>{}.obs;

  final RxBool prefetching = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    playback.stop();
    super.onClose();
  }

  /// 这篇有没有可用的预生成音频。没有的话朗读只能靠系统 TTS。
  bool get hasGeneratedAudio =>
      article.value?.lines.any((line) => line.audio != null) ?? false;

  /// 既没音频又没日语语音时，点播放不会有任何声音，要如实告诉用户。
  bool get playbackUnavailable =>
      !hasGeneratedAudio && !tts.japaneseAvailable.value;

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

  Future<void> playLine(ArticleLine line) => playback.playLine(line);

  Future<void> playAll() async {
    final lines = article.value?.lines;
    if (lines == null || lines.isEmpty) return;
    await playback.playAll(lines);
  }

  Future<void> stop() => playback.stop();

  /// 把整篇音频先下下来，之后断网也能听。
  Future<void> prefetchAudio() async {
    final lines = article.value?.lines;
    if (lines == null || prefetching.value) return;
    final paths = lines
        .map((line) => line.audio)
        .whereType<String>()
        .toList(growable: false);
    if (paths.isEmpty) return;

    prefetching.value = true;
    try {
      final ok = await _audioCache.prefetch(paths);
      Get.snackbar(
        ok == paths.length ? '已缓存到本地' : '部分下载失败',
        '$ok / ${paths.length} 句音频可离线播放',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      prefetching.value = false;
    }
  }
}
