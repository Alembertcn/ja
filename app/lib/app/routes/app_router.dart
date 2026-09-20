import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/article.dart';
import '../../modules/explain/explain_args.dart';
import '../../modules/explain/explain_view.dart';
import '../../modules/home/home_view.dart';
import '../../modules/reader/reader_cubit.dart';
import '../../modules/reader/reader_view.dart';
import '../../services/audio_cache_service.dart';
import '../../services/playback_cubit.dart';
import '../../data/repository/content_repository.dart';
import 'app_routes.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeView(),
        );
      case Routes.reader:
        final summary = settings.arguments;
        if (summary is! ArticleSummary) {
          return _errorRoute('Reader 需要 ArticleSummary');
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => BlocProvider(
            create: (ctx) => ReaderCubit(
              summary: summary,
              repo: ctx.read<ContentRepository>(),
              audioCache: ctx.read<AudioCacheService>(),
              playback: ctx.read<PlaybackCubit>(),
            ),
            child: const ReaderView(),
          ),
        );
      case Routes.explain:
        final args = settings.arguments;
        if (args is! ExplainArgs) {
          return _errorRoute('Explain 需要 ExplainArgs');
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => ExplainView(args: args),
        );
      default:
        return _errorRoute('未知路由 ${settings.name}');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text(message)),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String title, [String? message]) {
  final text = message == null ? title : '$title：$message';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
