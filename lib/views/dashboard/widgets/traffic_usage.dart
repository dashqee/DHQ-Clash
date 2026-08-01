import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrafficUsage extends StatelessWidget {
  const TrafficUsage({super.key});

  Widget _buildTrafficDataItem(
    BuildContext context,
    Icon icon,
    num trafficValue,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: [
        Flexible(
          flex: 1,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              icon,
              const SizedBox(width: 8),
              Flexible(
                flex: 1,
                child: Text(
                  trafficValue.traffic.value,
                  style: context.textTheme.bodySmall,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        Text(
          trafficValue.traffic.unit,
          style: context.textTheme.bodySmall?.toLighter,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    const primaryColor = AppTheme.blue;
    const secondaryColor = AppTheme.violet;
    return SizedBox(
      height: getWidgetHeight(2.5),
      child: RepaintBoundary(
        child: CommonCard(
          info: Info(
            label: appLocalizations.trafficUsage,
            iconData: Icons.data_saver_off,
          ),
          onPressed: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final totalTraffic = ref.watch(totalTrafficProvider);
              final upTotalTrafficValue = totalTraffic.up;
              final downTotalTrafficValue = totalTraffic.down;
              final totalTrafficValue =
                  upTotalTrafficValue + downTotalTrafficValue;
              return Padding(
                padding: baseInfoEdgeInsets.copyWith(top: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            SizedBox.square(
                              key: const ValueKey('traffic-usage-chart'),
                              dimension: 66,
                              child: DonutChart(
                                data: [
                                  DonutChartData(
                                    value: upTotalTrafficValue.toDouble(),
                                    color: primaryColor,
                                  ),
                                  DonutChartData(
                                    value: downTotalTrafficValue.toDouble(),
                                    color: secondaryColor,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FittedBox(
                                    key: const ValueKey('traffic-usage-total'),
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${totalTrafficValue.traffic.value} '
                                      '${totalTrafficValue.traffic.unit}',
                                      style: context.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  _TrafficLegend(
                                    color: primaryColor,
                                    label: appLocalizations.upload,
                                  ),
                                  const SizedBox(height: 4),
                                  _TrafficLegend(
                                    color: secondaryColor,
                                    label: appLocalizations.download,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildTrafficDataItem(
                      context,
                      const Icon(
                        Icons.arrow_upward,
                        color: primaryColor,
                        size: 14,
                      ),
                      upTotalTrafficValue,
                    ),
                    const SizedBox(height: 8),
                    _buildTrafficDataItem(
                      context,
                      const Icon(
                        Icons.arrow_downward,
                        color: secondaryColor,
                        size: 14,
                      ),
                      downTotalTrafficValue,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrafficLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _TrafficLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 8,
          decoration: ShapeDecoration(
            color: color,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
