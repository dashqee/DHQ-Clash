import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/providers/config.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Icon for one link of a proxy chain, or "" when it has none.
///
/// Only proxy groups carry an icon — they are the ones named after a service in
/// the config. The last link is a node out of a provider and never has one; its
/// flag lives in the name instead. Same rule as the router panel, which reads
/// the icon off the proxy by name and renders nothing when there is none.
String chainIcon(List<Group> groups, String chain) =>
    groups.getGroup(chain)?.icon ?? '';

/// mihomo returns a chain innermost first, so the node comes before the group
/// that picked it. Reversed reads as the decision did: rule, then node.
List<String> orderedChains(List<String> chains) => chains.reversed.toList();

class _ChainChip extends ConsumerWidget {
  final String chain;
  final VoidCallback? onPressed;
  final TextStyle? labelStyle;

  const _ChainChip({required this.chain, this.onPressed, this.labelStyle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched by name: a connection list rebuilds every second, and depending on
    // the whole group list would rebuild every row for any group's change.
    final icon = ref.watch(
      groupsProvider.select((groups) => chainIcon(groups, chain)),
    );
    return CommonChip(
      label: chain,
      labelStyle: labelStyle,
      onPressed: onPressed,
      // No placeholder when there is no icon: a reserved but empty box would
      // shift every node label out of line with the groups above it.
      avatar: icon.isEmpty
          ? null
          : SizedBox.square(
              dimension: globalState.measure.bodySmallHeight,
              child: CommonTargetIcon(src: icon),
            ),
    );
  }
}

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final Widget? trailing;
  final String detailTitle;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.trailing,
    required this.detailTitle,
  });

  static double get subTitleHeight {
    return globalState.measure.bodySmallHeight + 20;
  }

  Future<ImageProvider?> _getPackageIcon(TrackerInfo connection) async {
    return await app?.getPackageIcon(connection.metadata.process);
  }

  String _getSourceText(BuildContext context, TrackerInfo trackerInfo) {
    final progress = trackerInfo.progressText.isNotEmpty
        ? '${trackerInfo.progressText} · '
        : '';
    final traffic = Traffic(up: trackerInfo.upload, down: trackerInfo.download);
    return '${trackerInfo.start.getLastUpdateTimeDesc(context)} · $progress${traffic.desc}';
  }

  @override
  Widget build(BuildContext context, ref) {
    final value = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trackerInfo.desc, style: context.textTheme.bodyLarge),
        // Row(
        //   mainAxisSize: MainAxisSize.max,
        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //   spacing: 8,
        //   children: [
        //     Flexible(
        //       child: Text(trackerInfo.desc, style: context.textTheme.bodyLarge),
        //     ),
        //     Text(
        //       trackerInfo.start.lastUpdateTimeDesc,
        //       style: context.textTheme.bodySmall?.copyWith(
        //         color: context.colorScheme.onSurface.opacity60,
        //       ),
        //     ),
        //   ],
        // ),
        const SizedBox(height: 6),
        Text(
          _getSourceText(context, trackerInfo),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final chains = orderedChains(trackerInfo.chains);
    final subTitle = SizedBox(
      height: subTitleHeight,
      child: Row(
        spacing: 8,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: ListView.separated(
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              padding: EdgeInsets.zero,
              scrollDirection: Axis.horizontal,
              itemCount: chains.length,
              itemBuilder: (_, index) {
                final chain = chains[index];
                return _ChainChip(
                  chain: chain,
                  labelStyle: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    if (onClickKeyword == null) return;
                    onClickKeyword!(chain);
                  },
                );
              },
            ),
          ),
          ?trailing,
        ],
      ),
    );
    final icon = value
        ? GestureDetector(
            onTap: () {
              if (onClickKeyword == null) return;
              final process = trackerInfo.metadata.process;
              if (process.isEmpty) return;
              onClickKeyword!(process);
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              width: 42,
              height: 42,
              child: FutureBuilder<ImageProvider?>(
                future: _getPackageIcon(trackerInfo),
                builder: (_, snapshot) {
                  if (!snapshot.hasData && snapshot.data == null) {
                    return Container();
                  } else {
                    return Image(
                      image: snapshot.data!,
                      gaplessPlayback: true,
                      width: 42,
                      height: 42,
                    );
                  }
                },
              ),
            ),
          )
        : null;
    return ListItem(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () {
        showExtend(
          context,
          builder: (_) {
            return AdaptiveSheetScaffold(
              body: TrackerInfoDetailView(trackerInfo: trackerInfo),
              title: detailTitle,
            );
          },
        );
      },
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              ?icon,
              Flexible(child: title),
            ],
          ),
          const SizedBox(height: 8),
          subTitle,
        ],
      ),
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({super.key, required this.trackerInfo});

  String _getRuleText() {
    final rule = trackerInfo.rule;
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    }
    return rule;
  }

  String _getProcessText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  String _getSourceText() {
    final sourceIP = trackerInfo.metadata.sourceIP;
    if (sourceIP.isEmpty) {
      return '';
    }
    final sourcePort = trackerInfo.metadata.sourcePort;
    if (sourcePort.isNotEmpty) {
      return '$sourceIP:$sourcePort';
    }
    return sourceIP;
  }

  String _getDestinationText() {
    final destinationIP = trackerInfo.metadata.destinationIP;
    if (destinationIP.isEmpty) {
      return '';
    }
    final destinationPort = trackerInfo.metadata.destinationPort;
    if (destinationPort.isNotEmpty) {
      return '$destinationIP:$destinationPort';
    }
    return destinationIP;
  }

  Widget _buildChains(BuildContext context) {
    final chains = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final chain in orderedChains(trackerInfo.chains))
          _ChainChip(chain: chain, onPressed: () {}),
      ],
    );
    return ListItem(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(context.appLocalizations.proxyChains),
          Flexible(child: chains),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String title,
    required String desc,
    bool quickCopy = false,
  }) {
    return ListItem(
      title: Row(
        spacing: 16,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: 4,
            children: [
              Text(title),
              if (quickCopy)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.content_copy, size: 18),
                    onPressed: () {},
                  ),
                ),
            ],
          ),
          Flexible(child: Text(desc, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final items = [
      _buildItem(
        title: appLocalizations.creationTime,
        desc: trackerInfo.start.showFull,
      ),
      if (_getProcessText().isNotEmpty)
        _buildItem(title: appLocalizations.process, desc: _getProcessText()),
      _buildItem(
        title: appLocalizations.networkType,
        desc: trackerInfo.metadata.network,
      ),
      _buildItem(title: appLocalizations.rule, desc: _getRuleText()),
      if (trackerInfo.metadata.host.isNotEmpty)
        _buildItem(
          title: appLocalizations.host,
          desc: trackerInfo.metadata.host,
        ),
      if (_getSourceText().isNotEmpty)
        _buildItem(title: appLocalizations.source, desc: _getSourceText()),
      if (_getDestinationText().isNotEmpty)
        _buildItem(
          title: appLocalizations.destination,
          desc: _getDestinationText(),
        ),
      _buildItem(
        title: appLocalizations.upload,
        desc: trackerInfo.upload.traffic.show,
      ),
      _buildItem(
        title: appLocalizations.download,
        desc: trackerInfo.download.traffic.show,
      ),
      if (trackerInfo.metadata.destinationGeoIP.isNotEmpty)
        _buildItem(
          title: appLocalizations.destinationGeoIP,
          desc: trackerInfo.metadata.destinationGeoIP.join(' '),
        ),
      if (trackerInfo.metadata.destinationIPASN.isNotEmpty)
        _buildItem(
          title: appLocalizations.destinationIPASN,
          desc: trackerInfo.metadata.destinationIPASN,
        ),
      if (trackerInfo.metadata.dnsMode != null)
        _buildItem(
          title: appLocalizations.dnsMode,
          desc: trackerInfo.metadata.dnsMode!.name,
        ),
      if (trackerInfo.metadata.specialProxy.isNotEmpty)
        _buildItem(
          title: appLocalizations.specialProxy,
          desc: trackerInfo.metadata.specialProxy,
        ),
      if (trackerInfo.metadata.specialRules.isNotEmpty)
        _buildItem(
          title: appLocalizations.specialRules,
          desc: trackerInfo.metadata.specialRules,
        ),
      if (trackerInfo.metadata.remoteDestination.isNotEmpty)
        _buildItem(
          title: appLocalizations.remoteDestination,
          desc: trackerInfo.metadata.remoteDestination,
        ),
      _buildChains(context),
    ];
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: items.length,
        itemBuilder: (_, index) {
          return items[index];
        },
      ),
    );
  }
}
