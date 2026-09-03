import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/manager/window_manager.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class AppStateManager extends ConsumerStatefulWidget {
  final Widget child;

  const AppStateManager({super.key, required this.child});

  @override
  ConsumerState<AppStateManager> createState() => _AppStateManagerState();
}

class _AppStateManagerState extends ConsumerState<AppStateManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(checkIpProvider, (prev, next) {
      if (prev != next && next.a && next.c) {
        ref.read(networkDetectionProvider.notifier).startCheck();
      }
    });
    ref.listenManual(configProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(storeActionProvider.notifier)
            .savePreferencesDebounce();
      }
    });
    ref.listenManual(needUpdateGroupsProvider, (prev, next) {
      if (prev != next) {
        globalState.container
            .read(proxiesActionProvider.notifier)
            .updateGroupsDebounce();
      }
    });
    ref.listenManual(suspendProvider, (prev, next) {
      final isStart = ref.read(isStartProvider);
      if (prev != next && isStart) {
        debouncer.call(FunctionTag.suspend, () async {
          if (next == true) {
            await coreController.stopListener();
          } else {
            await coreController.startListener();
          }
          ref.read(checkIpNumProvider.notifier).add();
        });
      }
    });
    if (system.isMacOS) {
      ref.listenManual(autoSetSystemDnsStateProvider, (prev, next) async {
        if (prev == next) {
          return;
        }
        if (next.a == true && next.b == true) {
          macOS?.updateDns(false);
        } else {
          macOS?.updateDns(true);
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    commonPrint.log('$state');
    if (state == AppLifecycleState.resumed) {
      permissions.check();
      render?.resume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ref = globalState.container;
        ref.read(setupActionProvider.notifier).tryCheckIp();
        if (system.isAndroid &&
            !coreController.isCompleted &&
            !ref.read(setupActionProvider.notifier).isLaunching) {
          // Coming back from the VPN consent dialog is also a resume; the
          // launch waiting on it must not be restarted from under itself.
          ref.read(coreActionProvider.notifier).restartCore();
        }
      });
    }
  }

  @override
  void didChangePlatformBrightness() {
    globalState.container.read(themeActionProvider.notifier).updateBrightness();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (_) {
        render?.resume();
      },
      child: widget.child,
    );
  }
}

class AppEnvManager extends StatelessWidget {
  final Widget child;

  const AppEnvManager({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      if (globalState.isPre) {
        return Banner(
          message: 'DEBUG',
          location: BannerLocation.topEnd,
          child: child,
        );
      }
    }
    if (globalState.isPre) {
      return Banner(
        message: 'PRE',
        location: BannerLocation.topEnd,
        child: child,
      );
    }
    return child;
  }
}

class AppSidebarContainer extends ConsumerWidget {
  final Widget child;

  const AppSidebarContainer({super.key, required this.child});

  // Widget _buildLoading() {
  //   return Consumer(
  //     builder: (_, ref, _) {
  //       final loading = ref.watch(loadingProvider);
  //       final isMobileView = ref.watch(isMobileViewProvider);
  //       return loading && !isMobileView
  //           ? RotatedBox(
  //               quarterTurns: 1,
  //               child: const LinearProgressIndicator(),
  //             )
  //           : Container();
  //     },
  //   );
  // }

  Widget _buildBackground({
    required BuildContext context,
    required Widget child,
  }) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.line)),
      ),
      child: Material(color: Colors.transparent, child: child),
    );
    // if (!system.isMacOS) {
    //   return Material(
    //     color: context.colorScheme.surfaceContainer,
    //     child: child,
    //   );
    // }
    // return child;
    // return TransparentMacOSSidebar(
    //   child: Material(color: Colors.transparent, child: child),
    // );
  }

  void _updateSideBarWidth(WidgetRef ref, double contentWidth) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sideWidthProvider.notifier).value =
          ref.read(viewSizeProvider.select((state) => state.width)) -
          contentWidth;
    });
  }

  void _handleToPage(PageLabel pageLabel) {
    globalState.container
        .read(currentPageLabelProvider.notifier)
        .toPage(pageLabel);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationState = ref.watch(navigationStateProvider);
    final navigationItems = navigationState.navigationItems;
    final isMobileView = navigationState.viewMode == ViewMode.mobile;
    if (isMobileView) {
      return child;
    }
    final currentIndex = navigationState.currentIndex;
    final showLabel = ref.watch(appSettingProvider).showLabel;
    return Row(
      children: [
        _buildBackground(
          context: context,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (system.isMacOS) const SizedBox(height: 22),
                const SizedBox(height: 10),
                const ClipRect(child: AppIcon()),
                const SizedBox(height: 12),
                Expanded(
                  child: ScrollConfiguration(
                    behavior: HiddenBarScrollBehavior(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: NavigationRail(
                            scrollable: true,
                            minWidth: 92,
                            minExtendedWidth: 216,
                            groupAlignment: -0.72,
                            backgroundColor: Colors.transparent,
                            destinations: navigationItems
                                .map(
                                  (e) => NavigationRailDestination(
                                    icon: e.icon,
                                    label: Text(Intl.message(e.label.name)),
                                  ),
                                )
                                .toList(),
                            onDestinationSelected: (index) {
                              _handleToPage(navigationItems[index].label);
                            },
                            extended: false,
                            selectedIndex: currentIndex,
                            labelType: showLabel
                                ? NavigationRailLabelType.all
                                : NavigationRailLabelType.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceHigh,
                    side: const BorderSide(color: AppTheme.line),
                  ),
                  onPressed: () {
                    ref
                        .read(appSettingProvider.notifier)
                        .update(
                          (state) =>
                              state.copyWith(showLabel: !state.showLabel),
                        );
                  },
                  icon: const Icon(Icons.menu, color: AppTheme.muted),
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final pendingUpdate = ref.watch(pendingUpdateProvider);
                    final appLocalizations = context.appLocalizations;
                    return SidebarVersionControl(
                      version: globalState.appVersion,
                      checkUpdateLabel: appLocalizations.checkUpdate,
                      updateVersion: pendingUpdate?.version,
                      updateAvailableLabel: pendingUpdate == null
                          ? null
                          : appLocalizations.updateAvailable(
                              pendingUpdate.version,
                            ),
                      onCheckUpdate: () {
                        ref
                            .read(commonActionProvider.notifier)
                            .showPendingUpdateOrCheck();
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: ClipRect(
            child: LayoutBuilder(
              builder: (_, constraints) {
                _updateSideBarWidth(ref, constraints.maxWidth);
                return child;
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// The version in the corner of the sidebar, and the way to update it.
///
/// With [updateVersion] set the icon lights up in the brand accent and wears a
/// dot: an update was offered and not installed yet. It stays until the
/// install, so "remind me later" is never the last anyone hears of it.
class SidebarVersionControl extends StatelessWidget {
  final String version;
  final String checkUpdateLabel;
  final VoidCallback onCheckUpdate;
  final String? updateVersion;
  final String? updateAvailableLabel;

  const SidebarVersionControl({
    super.key,
    required this.version,
    required this.checkUpdateLabel,
    required this.onCheckUpdate,
    this.updateVersion,
    this.updateAvailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasUpdate = updateVersion != null;
    final iconColor = hasUpdate
        ? AppTheme.cyan
        : context.colorScheme.onSurfaceVariant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'v$version',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        IconButton(
          tooltip: hasUpdate
              ? updateAvailableLabel ?? checkUpdateLabel
              : checkUpdateLabel,
          onPressed: onCheckUpdate,
          icon: Badge(
            key: const ValueKey('sidebar-update-marker'),
            isLabelVisible: hasUpdate,
            smallSize: 9,
            backgroundColor: AppTheme.lime,
            child: Icon(Icons.system_update_alt, color: iconColor),
          ),
        ),
      ],
    );
  }
}
