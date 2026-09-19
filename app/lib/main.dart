import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'app/bindings/initial_binding.dart';
import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'app/theme.dart';
import 'data/local/app_database.dart';
import 'data/remote/content_api.dart';
import 'data/repository/content_repository.dart';
import 'services/audio_cache_service.dart';
import 'services/playback_service.dart';
import 'services/settings_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  final settings = Get.put(SettingsService(), permanent: true);
  final database = Get.put(AppDatabase(), permanent: true);
  final api = Get.put(ContentApi(() => settings.contentBaseUrl), permanent: true);
  Get.put(ContentRepository(api, database), permanent: true);

  final tts = await Get.putAsync(() => TtsService(settings).init(), permanent: true);
  final audioCache = await Get.putAsync(
    () => AudioCacheService(api).init(),
    permanent: true,
  );
  Get.put(PlaybackService(tts, audioCache, settings), permanent: true);

  runApp(const JaApp());
}

class JaApp extends StatelessWidget {
  const JaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JA 日语精读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: Routes.home,
      initialBinding: InitialBinding(),
      getPages: AppPages.pages,
      locale: const Locale('zh', 'CN'),
      fallbackLocale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), japaneseLocale, Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
