import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _quickOptionHeight = 104.0;

class MacOSTunHelperButton extends ConsumerStatefulWidget {
  final Future<bool> Function()? checkInstalled;
  final Future<AuthorizeCode> Function()? install;
  final Future<void> Function()? onInstalled;

  const MacOSTunHelperButton({
    super.key,
    this.checkInstalled,
    this.install,
    this.onInstalled,
  });

  @override
  ConsumerState<MacOSTunHelperButton> createState() =>
      _MacOSTunHelperButtonState();
}

class _MacOSTunHelperButtonState extends ConsumerState<MacOSTunHelperButton> {
  bool? _installed;
  bool _installing = false;

  Future<bool> _checkInstalled() {
    return widget.checkInstalled?.call() ?? system.checkIsAdmin();
  }

  Future<AuthorizeCode> _install() {
    return widget.install?.call() ??
        system.authorizeCore(forceMacOSHelperInstall: true);
  }

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final installed = await _checkInstalled();
    if (!mounted) return;
    setState(() {
      _installed = installed;
    });
  }

  Future<void> _handleInstall() async {
    if (_installing) return;
    setState(() {
      _installing = true;
    });
    var installed = false;
    try {
      final code = await _install();
      if (code != AuthorizeCode.error) {
        if (widget.onInstalled != null) {
          await widget.onInstalled!();
        } else {
          await ref.read(coreActionProvider.notifier).restartCore();
        }
      }
      installed = await _checkInstalled();
    } catch (error) {
      commonPrint.log(
        'macOS TUN access reinstall failed: $error',
        logLevel: LogLevel.warning,
      );
    }
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _installing = false;
    });
    context.showNotifier(
      installed
          ? context.appLocalizations.macosTunHelperInstallSuccess
          : context.appLocalizations.macosTunHelperInstallFailed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final installed = _installed == true;
    return Tooltip(
      message: context.appLocalizations.macosTunHelper,
      child: IconButton.filledTonal(
        onPressed: _installing ? null : _handleInstall,
        icon: _installing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                installed
                    ? Icons.verified_user_outlined
                    : Icons.admin_panel_settings_outlined,
              ),
      ),
    );
  }
}

class TUNButton extends StatelessWidget {
  const TUNButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: _quickOptionHeight,
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return Builder(
                builder: (context) {
                  return AdaptiveSheetScaffold(
                    body: generateListView(
                      generateSection(
                        items: [
                          if (system.isDesktop) const TUNItem(),
                          if (system.isMacOS) const AutoSetSystemDnsItem(),
                          const TunStackItem(),
                        ],
                      ),
                    ),
                    title: appLocalizations.tun,
                  );
                },
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.tun,
          iconData: Icons.stacked_line_chart,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: baseInfoEdgeInsets.copyWith(top: 0, bottom: 0, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    patchClashConfigProvider.select(
                      (state) => state.tun.enable,
                    ),
                  );
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: enable,
                    onChanged: (value) {
                      ref
                          .read(patchClashConfigProvider.notifier)
                          .update((state) => state.copyWith.tun(enable: value));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SystemProxyButton extends StatelessWidget {
  const SystemProxyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: _quickOptionHeight,
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [const SystemProxyItem(), const BypassDomainItem()],
                  ),
                ),
                title: appLocalizations.systemProxy,
              );
            },
          );
        },
        info: Info(
          label: appLocalizations.systemProxy,
          iconData: Icons.shuffle,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: baseInfoEdgeInsets.copyWith(top: 0, bottom: 0, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final systemProxy = ref.watch(
                    networkSettingProvider.select((state) => state.systemProxy),
                  );
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: systemProxy,
                    onChanged: (value) {
                      ref
                          .read(networkSettingProvider.notifier)
                          .update(
                            (state) => state.copyWith(systemProxy: value),
                          );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VpnButton extends StatelessWidget {
  const VpnButton({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: _quickOptionHeight,
      child: CommonCard(
        onPressed: () {
          showSheet(
            context: context,
            builder: (_) {
              return AdaptiveSheetScaffold(
                body: generateListView(
                  generateSection(
                    items: [
                      const VPNItem(),
                      const VpnSystemProxyItem(),
                      const TunStackItem(),
                    ],
                  ),
                ),
                title: 'VPN',
              );
            },
          );
        },
        info: const Info(label: 'VPN', iconData: Icons.stacked_line_chart),
        child: Container(
          alignment: Alignment.center,
          padding: baseInfoEdgeInsets.copyWith(top: 0, bottom: 0, right: 16),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: TooltipText(
                  text: Text(
                    appLocalizations.options,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.adjustSize(-2).toLight,
                  ),
                ),
              ),
              Consumer(
                builder: (_, ref, _) {
                  final enable = ref.watch(
                    vpnSettingProvider.select((state) => state.enable),
                  );
                  return Switch(
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    value: enable,
                    onChanged: (value) {
                      ref
                          .read(vpnSettingProvider.notifier)
                          .update((state) => state.copyWith(enable: value));
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
