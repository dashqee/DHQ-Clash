import 'package:fl_clash/common/common.dart';
import 'package:flutter/material.dart';

import 'button.dart';
import 'dialog.dart';

/// "A new version is out": install it now, or be asked again next launch.
///
/// Pops `true` to install and `false` for later. There is deliberately no
/// "never again": the way to stop these is the auto-check switch in Settings,
/// not a button people press to make a dialog go away.
class UpdatePromptDialog extends StatelessWidget {
  final String version;
  final String notes;

  const UpdatePromptDialog({
    super.key,
    required this.version,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final textTheme = context.textTheme;
    return CommonDialog(
      title: appLocalizations.discoverNewVersion,
      maxWidth: 480,
      actions: [
        TextButton(
          key: const ValueKey('update-remind-later'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(appLocalizations.remindLater),
        ),
        BrandButton(
          key: const ValueKey('update-install'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(appLocalizations.installUpdate),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(version, style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            appLocalizations.releaseNotes,
            style: textTheme.titleSmall?.copyWith(color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          Text(
            notes.isEmpty ? appLocalizations.noInfo : notes,
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
