import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repository/content_repository.dart';
import '../../services/audio_cache_service.dart';
import '../../services/playback_service.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../library/library_controller.dart';

class ProfileController extends GetxController {
  final SettingsService settings = Get.find<SettingsService>();
  final TtsService tts = Get.find<TtsService>();
  final PlaybackService playback = Get.find<PlaybackService>();
  final AudioCacheService _audioCache = Get.find<AudioCacheService>();
  final ContentRepository _repo = Get.find<ContentRepository>();

  final Rxn<CacheStats> cacheStats = Rxn<CacheStats>();
  final RxInt audioFileCount = 0.obs;
  final RxInt audioBytes = 0.obs;
  final RxString appVersion = ''.obs;

  @override
  void onInit() {
    super.onInit();
    refreshStats();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    appVersion.value = '${info.version}+${info.buildNumber}';
  }

  Future<void> refreshStats() async {
    cacheStats.value = await _repo.cacheStats();
    final audio = await _audioCache.stats();
    audioFileCount.value = audio.files;
    audioBytes.value = audio.bytes;
  }

  String get audioSizeText => _readableSize(audioBytes.value);

  Future<void> clearCache() async {
    await _repo.clearCache();
    await refreshStats();
    await Get.find<LibraryController>().reload();
  }

  Future<void> clearAudioCache() async {
    await _audioCache.clear();
    await refreshStats();
  }

  /// 换内容源后缓存里的 etag 和音频都对不上了，一起清掉重拉。
  Future<void> applyBaseUrl(String url) async {
    settings.setContentBaseUrl(url);
    await _audioCache.clear();
    await clearCache();
  }

  Future<void> previewSpeech() =>
      playback.previewTts('日本語の発音を確認します。');

  static String _readableSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
