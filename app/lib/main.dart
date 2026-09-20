import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_storage/get_storage.dart';

import 'app/routes/app_router.dart';
import 'app/routes/app_routes.dart';
import 'app/theme.dart';
import 'data/local/app_database.dart';
import 'data/remote/content_api.dart';
import 'data/repository/content_repository.dart';
import 'modules/home/home_cubit.dart';
import 'modules/library/library_cubit.dart';
import 'modules/plan/plan_cubit.dart';
import 'modules/profile/profile_cubit.dart';
import 'services/audio_cache_service.dart';
import 'services/playback_cubit.dart';
import 'services/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  final settings = SettingsCubit();
  final database = AppDatabase();
  final api = ContentApi(() => settings.contentBaseUrl);
  final repo = ContentRepository(api, database);
  final audioCache = await AudioCacheService(api).init();
  final playback = PlaybackCubit(audioCache, settings);
  final library = LibraryCubit(repo);
  final plan = PlanCubit(repo);
  final home = HomeCubit();
  final profile = ProfileCubit(
    settings: settings,
    audioCache: audioCache,
    repo: repo,
    library: library,
  );

  runApp(JaApp(
    settings: settings,
    database: database,
    api: api,
    repo: repo,
    audioCache: audioCache,
    playback: playback,
    library: library,
    plan: plan,
    home: home,
    profile: profile,
  ));
}

class JaApp extends StatelessWidget {
  const JaApp({
    super.key,
    required this.settings,
    required this.database,
    required this.api,
    required this.repo,
    required this.audioCache,
    required this.playback,
    required this.library,
    required this.plan,
    required this.home,
    required this.profile,
  });

  final SettingsCubit settings;
  final AppDatabase database;
  final ContentApi api;
  final ContentRepository repo;
  final AudioCacheService audioCache;
  final PlaybackCubit playback;
  final LibraryCubit library;
  final PlanCubit plan;
  final HomeCubit home;
  final ProfileCubit profile;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: database),
        RepositoryProvider.value(value: api),
        RepositoryProvider.value(value: repo),
        RepositoryProvider.value(value: audioCache),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: playback),
          BlocProvider.value(value: home),
          BlocProvider.value(value: library),
          BlocProvider.value(value: plan),
          BlocProvider.value(value: profile),
        ],
        child: MaterialApp(
          title: '学JA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          initialRoute: Routes.home,
          onGenerateRoute: AppRouter.onGenerateRoute,
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [
            Locale('zh', 'CN'),
            japaneseLocale,
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
        ),
      ),
    );
  }
}
