import 'dart:math';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

@visibleForTesting
double outboundRuleGradientAngle(double progress) {
  final normalizedProgress = progress % 1;
  return -pi / 4 + normalizedProgress * 2 * pi;
}

LinearGradient _ruleGradient(double progress) {
  return LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: const [AppTheme.violet, AppTheme.blue, AppTheme.cyan],
    transform: GradientRotation(outboundRuleGradientAngle(progress)),
  );
}

class OutboundModeV2 extends ConsumerStatefulWidget {
  const OutboundModeV2({super.key});

  @override
  ConsumerState<OutboundModeV2> createState() => _OutboundModeV2State();
}

class _OutboundModeV2State extends ConsumerState<OutboundModeV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
      animationBehavior: AnimationBehavior.preserve,
      debugLabel: 'outbound-rule-gradient',
    );
    ref.listenManual(patchClashConfigProvider.select((state) => state.mode), (
      _,
      mode,
    ) {
      if (mode == Mode.rule) {
        _gradientController.repeat();
      } else {
        _gradientController
          ..stop()
          ..reset();
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _gradientController.dispose();
    super.dispose();
  }

  void _handleChangeMode(Mode mode) {
    globalState.container.read(setupActionProvider.notifier).changeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final height = getWidgetHeight(1);
    return SizedBox(
      height: height,
      child: CommonCard(
        child: Consumer(
          builder: (_, ref, _) {
            final mode = ref.watch(
              patchClashConfigProvider.select((state) => state.mode),
            );
            return AnimatedBuilder(
              animation: _gradientController,
              builder: (_, _) {
                final progress = _gradientController.value;
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            for (final item in Mode.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  child: _ModeSegment(
                                    mode: item,
                                    selected: item == mode,
                                    animationProgress: progress,
                                    onPressed: () => _handleChangeMode(item),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      key: const ValueKey('outbound-mode-footer'),
                      height: 7,
                      decoration: BoxDecoration(
                        color: switch (mode) {
                          Mode.rule => null,
                          Mode.global => context.colorScheme.primary,
                          Mode.direct => context.colorScheme.tertiary,
                        },
                        gradient: mode == Mode.rule
                            ? _ruleGradient(progress)
                            : null,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final Mode mode;
  final bool selected;
  final double animationProgress;
  final VoidCallback onPressed;

  const _ModeSegment({
    required this.mode,
    required this.selected,
    required this.animationProgress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = selected && mode == Mode.rule
        ? _ruleGradient(animationProgress)
        : null;
    final backgroundColor = !selected
        ? Colors.transparent
        : switch (mode) {
            Mode.rule => null,
            Mode.global => context.colorScheme.primaryContainer,
            Mode.direct => context.colorScheme.tertiaryContainer,
          };
    final foregroundColor = !selected
        ? AppTheme.muted
        : switch (mode) {
            Mode.rule => Colors.white,
            Mode.global => context.colorScheme.onPrimaryContainer,
            Mode.direct => context.colorScheme.onTertiaryContainer,
          };
    return Semantics(
      key: ValueKey('outbound-mode-${mode.name}'),
      selected: selected,
      button: true,
      child: AnimatedScale(
        scale: selected ? 1 : 0.97,
        duration: commonDuration,
        curve: Curves.easeOutCubic,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor,
            gradient: gradient,
            borderRadius: AppTheme.borderRadiusSm,
            border: Border.all(
              color: selected
                  ? foregroundColor.withValues(alpha: 0.28)
                  : AppTheme.line,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color:
                          (mode == Mode.rule ? AppTheme.blue : foregroundColor)
                              .withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: AppTheme.borderRadiusSm,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Intl.message(mode.name),
                      maxLines: 1,
                      style: context.textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
