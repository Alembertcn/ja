import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repository/content_repository.dart';
import '../../services/settings_service.dart';
import '../../services/tts_service.dart';
import '../library/library_controller.dart';

class ProfileController extends GetxController {
  final SettingsService settings = Get.find<SettingsService>();
  final TtsService tts = Get.find<TtsService>();
  final ContentRepository _repo = Get.find<ContentRepository>();

  final Rxn<CacheStats> cacheStats = Rxn<CacheStats>();
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
  }

  Future<void> clearCache() async {
    await _repo.clearCache();
    await refreshStats();
    await Get.find<LibraryController>().reload();
  }

  /// 换内容源后缓存里的 etag 就对不上了，直接清掉重拉。
  Future<void> applyBaseUrl(String url) async {
    settings.setContentBaseUrl(url);
    await clearCache();
  }

  Future<void> previewSpeech() =>
      tts.speakLine('__preview__', '日本語の発音を確認します。');
}
