import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../data/models/practice.dart';
import '../shared/app_surface.dart';
import '../shared/state_views.dart';
import 'practice_args.dart';
import 'practice_cubit.dart';

class PracticeView extends StatefulWidget {
  const PracticeView({super.key, required this.args});

  final PracticeArgs args;

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  final Map<String, int> _answers = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: AppColors.pageBg(scheme),
      appBar: AppBar(
        backgroundColor: AppColors.card(scheme),
        title: Text(
          widget.args.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => context.read<PracticeCubit>().load(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<PracticeCubit, PracticeState>(
        builder: (context, state) {
          if (state.loading && state.practice == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final practice = state.practice;
          if (practice == null) {
            return ErrorStateView(
              message: state.error ?? '加载失败',
              onRetry: () =>
                  context.read<PracticeCubit>().load(force: true),
            );
          }
          return _content(context, practice, state.offlineNotice);
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    PracticeSet practice,
    String? offlineNotice,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final questions = [
      for (final section in practice.sections) ...section.questions,
    ];
    final correct = questions
        .where((question) => _answers[question.id] == question.answer)
        .length;
    final percent = questions.isEmpty ? 0 : (correct * 100 / questions.length).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (offlineNotice != null) OfflineBanner(message: offlineNotice),
        AppInkSurface(
          shadowed: true,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(text: practice.level, emphasized: true),
                    _Badge(text: 'W${practice.week.toString().padLeft(2, '0')}'),
                    _Badge(text: '${practice.questionCount} 题'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  practice.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  practice.goal,
                  style: TextStyle(
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (_submitted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: percent >= 80
                          ? scheme.primaryContainer
                          : scheme.errorContainer,
                      borderRadius: AppRadii.mdAll,
                    ),
                    child: Text(
                      '$correct / ${questions.length} 题正确 · $percent 分'
                      '${percent >= 80 ? ' · 本周目标已达标' : ' · 建议复习解析后重做'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: percent >= 80
                            ? scheme.onPrimaryContainer
                            : scheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        for (final section in practice.sections) ...[
          const SizedBox(height: 20),
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            section.instructions,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < section.questions.length; i++) ...[
            _QuestionCard(
              number: questions.indexOf(section.questions[i]) + 1,
              question: section.questions[i],
              selected: _answers[section.questions[i].id],
              submitted: _submitted,
              onSelected: (answer) {
                if (_submitted) return;
                setState(() => _answers[section.questions[i].id] = answer);
              },
            ),
            if (i < section.questions.length - 1) const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _submitOrRetry(questions),
          icon: Icon(_submitted ? Icons.replay : Icons.check_circle_outline),
          label: Text(_submitted ? '重新作答' : '提交答案'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  void _submitOrRetry(List<PracticeQuestion> questions) {
    if (_submitted) {
      setState(() {
        _answers.clear();
        _submitted = false;
      });
      return;
    }
    if (_answers.length < questions.length) {
      final left = questions.length - _answers.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('还有 $left 题未作答')),
      );
      return;
    }
    setState(() => _submitted = true);
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.selected,
    required this.submitted,
    required this.onSelected,
  });

  final int number;
  final PracticeQuestion question;
  final int? selected;
  final bool submitted;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppInkSurface(
      shadowed: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: AppColors.brandSoft(scheme),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    question.stem,
                    locale: japaneseLocale,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (question.passage case final passage?) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brandWash(scheme),
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  passage,
                  locale: japaneseLocale,
                  style: const TextStyle(fontSize: 14, height: 1.65),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (var i = 0; i < question.options.length; i++) ...[
              _OptionTile(
                index: i,
                text: question.options[i],
                selected: selected == i,
                correct: submitted && question.answer == i,
                wrong: submitted && selected == i && question.answer != i,
                enabled: !submitted,
                onTap: () => onSelected(i),
              ),
              if (i < question.options.length - 1) const SizedBox(height: 8),
            ],
            if (submitted) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: AppRadii.smAll,
                ),
                child: Text(
                  '${question.module.isEmpty ? '' : '${question.module} · '}${question.explanation}',
                  locale: japaneseLocale,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = correct
        ? scheme.primaryContainer
        : wrong
            ? scheme.errorContainer
            : selected
                ? AppColors.brandSoft(scheme)
                : scheme.surfaceContainerLowest;
    final foreground = correct
        ? scheme.onPrimaryContainer
        : wrong
            ? scheme.onErrorContainer
            : scheme.onSurface;

    return AppInkSurface(
      borderRadius: AppRadii.smAll,
      color: color,
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected || correct || wrong
                      ? foreground
                      : scheme.outline,
                ),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                locale: japaneseLocale,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            if (correct) Icon(Icons.check, size: 20, color: foreground),
            if (wrong) Icon(Icons.close, size: 20, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? AppColors.brandSoft(scheme)
            : AppColors.mutedChipBg(scheme),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: emphasized ? AppColors.brand : AppColors.mutedChipFg(scheme),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
