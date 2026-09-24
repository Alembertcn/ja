import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models/vocab.dart';
import '../shared/app_surface.dart';
import 'vocab_group_args.dart';

class VocabGroupView extends StatelessWidget {
  const VocabGroupView({super.key, required this.args});

  final VocabGroupArgs args;

  @override
  Widget build(BuildContext context) {
    final group = args.group;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      appBar: AppBar(
        backgroundColor: AppColors.card(scheme),
        title: Text(
          group.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: group.words.length + (group.hint == null ? 0 : 1),
        itemBuilder: (context, index) {
          if (group.hint != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                group.hint!,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            );
          }
          final wordIndex = group.hint == null ? index : index - 1;
          final word = group.words[wordIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WordCard(index: wordIndex + 1, word: word),
          );
        },
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  const _WordCard({required this.index, required this.word});

  final int index;
  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppInkSurface(
      shadowed: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.word,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      locale: japaneseLocale,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.reading,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.brand,
                      locale: japaneseLocale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    word.zh,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                  if (word.note != null && word.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      word.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
