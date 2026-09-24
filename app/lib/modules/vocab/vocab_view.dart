import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme.dart';
import '../../data/models/vocab.dart';
import '../shared/app_surface.dart';
import '../shared/state_views.dart';
import 'vocab_cubit.dart';
import 'vocab_group_args.dart';

class VocabView extends StatelessWidget {
  const VocabView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      appBar: AppBar(
        backgroundColor: AppColors.card(scheme),
        title: Text(
          'N2 全量词汇表',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => context.read<VocabCubit>().load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<VocabCubit, VocabState>(
        builder: (context, state) {
          if (state.loading && state.book == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = state.error;
          if (error != null && state.book == null) {
            return ErrorStateView(
              message: error,
              onRetry: () => context.read<VocabCubit>().load(force: true),
            );
          }
          final book = state.book;
          if (book == null) {
            return const EmptyStateView(
              icon: Icons.menu_book_outlined,
              title: '还没有词表',
              message: '发布 content/vocab/n2.json 后下拉刷新即可。',
            );
          }
          return _VocabBody(book: book, state: state);
        },
      ),
    );
  }
}

class _VocabBody extends StatelessWidget {
  const _VocabBody({required this.book, required this.state});

  final VocabBook book;
  final VocabState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = state.visibleGroups;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.offlineNotice != null)
                OfflineBanner(message: state.offlineNotice!),
              Text(
                book.subtitle ?? '按记忆维度分组，方便碎时间背诵',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '共 ${book.groups.length} 组 · ${book.wordCount} 词',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: context.read<VocabCubit>().setQuery,
                decoration: InputDecoration(
                  hintText: '搜日语 / 读音 / 中文',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.card(scheme),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.mdAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final kind in VocabGroupKind.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(kind.labelZh),
                          selected: state.kindFilter == kind,
                          onSelected: (_) =>
                              context.read<VocabCubit>().setKindFilter(kind),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: groups.isEmpty
              ? const EmptyStateView(
                  icon: Icons.search_off,
                  title: '没有匹配的词组',
                  message: '换个关键词或清掉筛选再试。',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupCard(group: group);
                  },
                ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final VocabGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppInkSurface(
      shadowed: true,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.vocabGroup,
        arguments: VocabGroupArgs(group: group),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _KindBadge(kind: group.kind),
                      const SizedBox(width: 8),
                      Text(
                        '${group.words.length} 词',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    group.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (group.hint != null && group.hint!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      group.hint!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final VocabGroupKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandSoft(scheme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        kind.labelZh,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
