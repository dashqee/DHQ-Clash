import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'common.dart';
import 'core.dart';

part 'generated/app.freezed.dart';

typedef DelayMap = Map<String, Map<String, int?>>;

@freezed
abstract class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool isInit,
    @Default(false) bool backBlock,
    @Default(PageLabel.dashboard) PageLabel pageLabel,
    @Default([]) List<Package> packages,
    @Default(0) int sortNum,
    required Size viewSize,
    @Default(0) double sideWidth,
    @Default({}) DelayMap delayMap,
    @Default([]) List<Group> groups,
    @Default(0) int checkIpNum,
    required Brightness brightness,
    int? runTime,
    @Default([]) List<ExternalProvider> providers,
    String? localIp,
    required FixedList<TrackerInfo> requests,
    required int version,
    required FixedList<Log> logs,
    required FixedList<Traffic> traffics,
    required Traffic totalTraffic,
    @Default(false) bool realTunEnable,
    @Default(false) bool loading,
    required SystemUiOverlayStyle systemUiOverlayStyle,
    @Default(CoreStatus.connecting) CoreStatus coreStatus,
  }) = _AppState;
}

extension AppStateExt on AppState {
  ViewMode get viewMode => utils.getViewMode(viewSize.width);

  bool get isStart => runTime != null;
}

/// An update the backend offered, kept until it is installed.
///
/// Held in memory only: every launch asks the backend again, so "remind me
/// later" is exactly that — the next start brings the prompt back.
@freezed
abstract class AppUpdateInfo with _$AppUpdateInfo {
  const factory AppUpdateInfo({
    required String version,
    @Default('') String notes,
    @Default('') String url,
    @Default('') String filename,
    @Default('') String sha256,
    @Default(false) bool hasUpdate,
  }) = _AppUpdateInfo;

  factory AppUpdateInfo.fromResponse(
    Map<String, dynamic> data, {
    required String appVersion,
  }) {
    final version = (data['version'] ?? '').toString();
    return AppUpdateInfo(
      version: version,
      notes: (data['notes'] ?? '').toString(),
      url: (data['url'] ?? '').toString(),
      filename: (data['filename'] ?? '').toString(),
      sha256: (data['sha256'] ?? '').toString(),
      hasUpdate:
          data['_hasUpdate'] as bool? ??
          utils.compareVersions(version, appVersion) > 0,
    );
  }
}
