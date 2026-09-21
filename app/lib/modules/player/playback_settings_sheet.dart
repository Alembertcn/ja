import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../services/settings_cubit.dart';

/// 全局播放设置：只保留循环与倍速。
class PlaybackSettingsSheet extends StatelessWidget {
  const PlaybackSettingsSheet({super.key});

  static const speedOptions = [0.6, 0.8, 1.0, 1.2, 1.4];

  static Future<void> open(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PlaybackSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '播放设置',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Text(
            '循环',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (a, b) => a.loopMode != b.loopMode,
            builder: (context, settings) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mode in PlaybackLoopMode.values)
                    _OptionChip(
                      label: mode.label,
                      selected: settings.loopMode == mode,
                      onTap: () =>
                          context.read<SettingsCubit>().setLoopMode(mode),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            '倍速',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          BlocBuilder<SettingsCubit, SettingsState>(
            buildWhen: (a, b) => a.speechSpeed != b.speechSpeed,
            builder: (context, settings) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in speedOptions)
                    _OptionChip(
                      label: '${option.toStringAsFixed(1)}×',
                      selected: (settings.speechSpeed - option).abs() < 0.01,
                      onTap: () =>
                          context.read<SettingsCubit>().setSpeechSpeed(option),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.xlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.xlAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: selected
              ? AppTheme.chipSelected(scheme)
              : AppTheme.chipPlain(scheme),
          child: Text(label, style: AppTheme.chipLabel(selected, scheme)),
        ),
      ),
    );
  }
}
