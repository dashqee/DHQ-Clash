import 'dart:math';

import 'package:defer_pointer/defer_pointer.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'widgets/start_button.dart';

typedef _IsEditWidgetBuilder = Widget Function(bool isEdit);

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> {
  final key = GlobalKey<SuperGridState>();
  final _isEditNotifier = ValueNotifier<bool>(false);
  final _addedWidgetsNotifier = ValueNotifier<List<GridItem>>([]);

  @override
  void dispose() {
    _isEditNotifier.dispose();
    _addedWidgetsNotifier.dispose();
    super.dispose();
  }

  Widget _buildIsEdit(_IsEditWidgetBuilder builder) {
    return ValueListenableBuilder(
      valueListenable: _isEditNotifier,
      builder: (_, isEdit, _) {
        return builder(isEdit);
      },
    );
  }

  Future<void> _handleConnection() async {
    final coreStatus = ref.read(coreStatusProvider);
    if (coreStatus == CoreStatus.connecting) {
      return;
    }
    final tip = coreStatus == CoreStatus.connected
        ? context.appLocalizations.forceRestartCoreTip
        : context.appLocalizations.restartCoreTip;
    final res = await globalState.showMessage(message: TextSpan(text: tip));
    if (res != true) {
      return;
    }
    globalState.container.read(coreActionProvider.notifier).restartCore();
  }

  List<Widget> _buildActions(bool isEdit) {
    final appLocalizations = context.appLocalizations;
    return [
      if (!isEdit)
        Consumer(
          builder: (_, ref, _) {
            final coreStatus = ref.watch(coreStatusProvider);
            return Tooltip(
              message: appLocalizations.coreStatus,
              child: FadeScaleBox(
                alignment: Alignment.centerRight,
                child: coreStatus == CoreStatus.connected
                    ? IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green.harmonizeWith(
                            context.colorScheme.primary,
                          ),
                          foregroundColor: switch (Theme.brightnessOf(
                            context,
                          )) {
                            Brightness.light =>
                              context.colorScheme.onSurfaceVariant,
                            Brightness.dark =>
                              context.colorScheme.onPrimaryFixedVariant,
                          },
                        ),
                        onPressed: _handleConnection,
                        icon: const Icon(
                          Icons.check,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : FilledButton.icon(
                        key: ValueKey(coreStatus),
                        onPressed: _handleConnection,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => Colors.greenAccent,
                            CoreStatus.disconnected =>
                              context.colorScheme.error,
                          },
                          foregroundColor: switch (coreStatus) {
                            CoreStatus.connecting => null,
                            CoreStatus.connected => switch (Theme.brightnessOf(
                              context,
                            )) {
                              Brightness.light =>
                                context.colorScheme.onSurfaceVariant,
                              Brightness.dark => null,
                            },
                            CoreStatus.disconnected =>
                              context.colorScheme.onError,
                          },
                        ),
                        icon: SizedBox(
                          height: globalState.measure.bodyMediumHeight,
                          width: globalState.measure.bodyMediumHeight,
                          child: switch (coreStatus) {
                            CoreStatus.connecting => Padding(
                              padding: const EdgeInsets.all(2),
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: context.colorScheme.onPrimary,
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                            CoreStatus.connected => const Icon(
                              Icons.check_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                            CoreStatus.disconnected => const Icon(
                              Icons.restart_alt_sharp,
                              fontWeight: FontWeight.w900,
                            ),
                          },
                        ),
                        label: Text(switch (coreStatus) {
                          CoreStatus.connecting => appLocalizations.connecting,
                          CoreStatus.connected => appLocalizations.connected,
                          CoreStatus.disconnected =>
                            appLocalizations.disconnected,
                        }),
                      ),
              ),
            );
          },
        ),
      if (isEdit)
        ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, addedChildren, child) {
            if (addedChildren.isEmpty) {
              return Container();
            }
            return child!;
          },
          child: IconButton(
            onPressed: () {
              _showAddWidgetsModal();
            },
            icon: const Icon(Icons.add_circle),
          ),
        ),
      FadeRotationScaleBox(
        child: isEdit
            ? IconButton(
                key: const ValueKey(true),
                icon: const Icon(Icons.save, key: ValueKey('save-icon')),
                onPressed: _handleUpdateIsEdit,
              )
            : IconButton(
                key: const ValueKey(false),
                icon: const Icon(Icons.edit, key: ValueKey('edit-icon')),
                onPressed: _handleUpdateIsEdit,
              ),
      ),
    ];
  }

  void _showAddWidgetsModal() {
    showSheet(
      builder: (_) {
        return ValueListenableBuilder(
          valueListenable: _addedWidgetsNotifier,
          builder: (_, value, _) {
            return AdaptiveSheetScaffold(
              body: _AddDashboardWidgetModal(
                items: value,
                onAdd: (gridItem) {
                  key.currentState?.handleAdd(gridItem);
                },
              ),
              title: context.appLocalizations.add,
            );
          },
        );
      },
      context: context,
    );
  }

  Future<void> _handleUpdateIsEdit() async {
    if (_isEditNotifier.value == true) {
      await _handleSave();
    }
    _isEditNotifier.value = !_isEditNotifier.value;
  }

  Future<void> _handleSave() async {
    final currentState = key.currentState;
    if (currentState == null) {
      return;
    }
    if (mounted && currentState.children.isNotEmpty) {
      await currentState.isTransformCompleter;
      final dashboardWidgets = currentState.children
          .map((item) => DashboardWidget.getDashboardWidget(item))
          .toList();
      ref
          .read(appSettingProvider.notifier)
          .update(
            (state) => state.copyWith(dashboardWidgets: dashboardWidgets),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardStateProvider);
    final gridWidth = min(dashboardState.contentWidth, 1120);
    final columns = max(4 * ((gridWidth / 280).ceil()), 8);
    final spacing = 14.mAp;
    final children = [
      ...dashboardState.dashboardWidgets
          .where(
            (item) => item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addedWidgetsNotifier.value = DashboardWidget.values
          .where(
            (item) =>
                !children.contains(item.widget) &&
                item.platforms.contains(SupportPlatform.currentPlatform),
          )
          .map((item) => item.widget)
          .toList();
    });
    return _buildIsEdit(
      (isEdit) => CommonScaffold(
        title: context.appLocalizations.dashboard,
        actions: _buildActions(isEdit),
        floatingActionButton: const StartButton(),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20).copyWith(bottom: 96),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: isEdit
                  ? SystemBackBlock(
                      child: CommonPopScope(
                        child: SuperGrid(
                          key: key,
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          children: children,
                          onUpdate: () {
                            _handleSave();
                          },
                        ),
                        onPop: (context) {
                          _handleUpdateIsEdit();
                          return false;
                        },
                      ),
                    )
                  : Column(
                      children: [
                        const _ConnectionOverview(),
                        const SizedBox(height: 20),
                        Grid(
                          crossAxisCount: columns,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                          children: children,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionOverview extends ConsumerWidget {
  const _ConnectionOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appLocalizations = context.appLocalizations;
    final coreStatus = ref.watch(coreStatusProvider);
    final mode = ref.watch(
      patchClashConfigProvider.select((state) => state.mode),
    );
    final runTime = ref.watch(runTimeProvider);
    final statusColor = switch (coreStatus) {
      CoreStatus.connected => AppTheme.cyan,
      CoreStatus.connecting => AppTheme.blue,
      CoreStatus.disconnected => AppTheme.danger,
    };
    final statusLabel = switch (coreStatus) {
      CoreStatus.connected => appLocalizations.connected,
      CoreStatus.connecting => appLocalizations.connecting,
      CoreStatus.disconnected => appLocalizations.disconnected,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.78),
        border: Border.all(color: AppTheme.line),
        borderRadius: AppTheme.borderRadiusXl,
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final status = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: AppTheme.borderRadiusMd,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(Icons.monitor_heart_outlined, color: statusColor),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appLocalizations.status.toUpperCase(),
                      style: context.textTheme.labelSmall?.copyWith(
                        color: AppTheme.muted,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(statusLabel, style: context.textTheme.titleLarge),
                    const SizedBox(height: 3),
                    Text(
                      '${appLocalizations.mode}: ${Intl.message(mode.name)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final metrics = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverviewMetric(
                label: appLocalizations.mode,
                value: Intl.message(mode.name),
              ),
              const SizedBox(width: 10),
              _OverviewMetric(
                label: appLocalizations.time,
                value: coreStatus == CoreStatus.connected
                    ? utils.getTimeText(runTime)
                    : '—',
                accent: coreStatus == CoreStatus.connected,
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                status,
                const SizedBox(height: 18),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: metrics,
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: status),
              const SizedBox(width: 24),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _OverviewMetric({
    required this.label,
    required this.value,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.borderRadiusSm,
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: context.textTheme.labelSmall?.copyWith(
              color: AppTheme.muted,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.titleMedium?.copyWith(
              color: accent ? AppTheme.lime : AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddDashboardWidgetModal extends StatelessWidget {
  final List<GridItem> items;
  final Function(GridItem item) onAdd;

  const _AddDashboardWidgetModal({required this.items, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return DeferredPointerHandler(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Grid(
          crossAxisCount: 8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: items
              .map(
                (item) => item.wrap(
                  builder: (child) {
                    return _AddedContainer(
                      onAdd: () {
                        onAdd(item);
                      },
                      child: child,
                    );
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _AddedContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onAdd;

  const _AddedContainer({required this.child, required this.onAdd});

  @override
  State<_AddedContainer> createState() => _AddedContainerState();
}

class _AddedContainerState extends State<_AddedContainer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(_AddedContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {}
  }

  Future<void> _handleAdd() async {
    widget.onAdd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ActivateBox(child: widget.child),
        Positioned(
          top: -8,
          right: -8,
          child: DeferPointer(
            child: SizedBox(
              width: 24,
              height: 24,
              child: IconButton.filled(
                iconSize: 20,
                padding: const EdgeInsets.all(2),
                onPressed: _handleAdd,
                icon: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
