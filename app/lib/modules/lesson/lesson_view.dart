import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../app/theme.dart';
import '../shared/state_views.dart';
import 'lesson_args.dart';
import 'lesson_cubit.dart';

class LessonView extends StatelessWidget {
  const LessonView({super.key, required this.args});

  final LessonArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      appBar: AppBar(
        backgroundColor: AppColors.card(scheme),
        title: Text(
          args.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => context.read<LessonCubit>().load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<LessonCubit, LessonState>(
        builder: (context, state) {
          if (state.loading && state.markdown == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final md = state.markdown;
          if (md == null) {
            return ErrorStateView(
              message: state.error ?? '加载失败',
              onRetry: () => context.read<LessonCubit>().load(force: true),
            );
          }
          return Column(
            children: [
              if (state.offlineNotice != null)
                OfflineBanner(message: state.offlineNotice!),
              Expanded(
                child: Markdown(
                  data: md,
                  selectable: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                    h1: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    h2: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                    h3: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                    p: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: scheme.onSurface,
                    ),
                    tableHead: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    tableBody: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    blockquoteDecoration: BoxDecoration(
                      color: AppColors.brandWash(scheme),
                      border: Border(
                        left: BorderSide(color: AppColors.brand, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
