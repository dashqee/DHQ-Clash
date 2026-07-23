import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app now has one permanent DHQ Clash theme. This screen only keeps the
/// accessibility control that changes text scale.
class ThemeView extends StatelessWidget {
  const ThemeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: context.appLocalizations.textScale,
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: TextScaleItem(),
      ),
    );
  }
}

class TextScaleItem extends ConsumerWidget {
  const TextScaleItem({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textScale = ref.watch(
      themeSettingProvider.select((state) => state.textScale),
    );
    final process = '${(textScale.scale * 100).round()}%';

    return CommonCard(
      info: Info(
        label: context.appLocalizations.textScale,
        iconData: Icons.text_fields,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.appLocalizations.textScale,
                    style: context.textTheme.titleSmall,
                  ),
                ),
                Switch(
                  value: textScale.enable,
                  onChanged: (value) {
                    ref
                        .read(themeSettingProvider.notifier)
                        .update(
                          (state) => state.copyWith.textScale(enable: value),
                        );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DisabledMask(
                    status: !textScale.enable,
                    child: ActivateBox(
                      active: textScale.enable,
                      child: SliderTheme(
                        data: SliderDefaultsM3(context),
                        child: Slider(
                          min: minTextScale,
                          max: maxTextScale,
                          value: textScale.scale,
                          onChanged: (value) {
                            ref
                                .read(themeSettingProvider.notifier)
                                .update(
                                  (state) =>
                                      state.copyWith.textScale(scale: value),
                                );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  constraints: const BoxConstraints(minWidth: 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceHigh,
                    borderRadius: AppTheme.borderRadiusSm,
                    border: Border.all(color: AppTheme.line),
                  ),
                  child: Text(
                    process,
                    textAlign: TextAlign.center,
                    style: context.textTheme.titleSmall?.copyWith(
                      color: AppTheme.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
