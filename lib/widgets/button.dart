import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

import 'builder.dart';
import 'card.dart';

class CommonFloatingActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Icon icon;
  final String label;

  const CommonFloatingActionButton({
    super.key,
    this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        floatingActionButtonTheme: Theme.of(context).floatingActionButtonTheme
            .copyWith(
              extendedIconLabelSpacing: 0,
              extendedPadding: const EdgeInsets.all(16),
            ),
      ),
      child: FloatingActionButtonExtendedBuilder(
        builder: (isExtended) {
          return FloatingActionButton.extended(
            heroTag: null,
            icon: icon,
            onPressed: onPressed,
            isExtended: true,
            label: AnimatedSize(
              alignment: Alignment.centerLeft,
              duration: midDuration,
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                duration: midDuration,
                opacity: isExtended ? 1.0 : 0.4,
                curve: Curves.linear,
                child: isExtended
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(label, softWrap: false),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          );
        },
      ),
    );
  }
}

class MoreActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final Widget? trailing;

  const MoreActionButton({
    super.key,
    this.onPressed,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        radius: 18,
        onPressed: onPressed,
        child: ListTile(
          minTileHeight: 0,
          minVerticalPadding: 0,
          titleTextStyle: context.textTheme.bodyMedium?.toJetBrainsMono,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          title: Text(label, style: context.textTheme.bodyLarge),
          trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 18),
        ),
      ),
    );
  }
}

/// A stadium button on the brand gradient — the one action on a surface the
/// user is meant to take. The Start button on the dashboard is the same shape
/// at a larger size.
class BrandButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;

  const BrandButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        gradient: AppTheme.brandGradient,
        shape: StadiumBorder(side: BorderSide(color: Color(0x33FFFFFF))),
        shadows: [
          BoxShadow(
            color: Color(0x594877F4),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(120, 44),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: const StadiumBorder(),
          textStyle: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        child: child,
      ),
    );
  }
}
