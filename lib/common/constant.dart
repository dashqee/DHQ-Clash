// ignore_for_file: constant_identifier_names

import 'dart:math';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';

const appName = 'DHQClash';
const appHelperService = 'FlClashHelperService';
const coreName = 'clash.meta';
const browserUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const packageName = 'com.follow.clash';
final unixSocketPath = '/tmp/FlClashSocket_${Random().nextInt(10000)}.sock';
final windowsPipeName = '\\\\.\\pipe\\FlClashCore_${Random().nextInt(10000)}';
const helperPort = 47890;
const maxTextScale = 1.4;
const minTextScale = 0.8;
final baseInfoEdgeInsets = EdgeInsets.symmetric(
  vertical: 16.mAp,
  horizontal: 16.mAp,
);
final listHeaderPadding = EdgeInsets.only(
  left: 16.mAp,
  right: 8.mAp,
  top: 24.mAp,
  bottom: 8.mAp,
);
const sheetAppBarHeight = 68.0;

const watchExecution = false;

// Hosts whose install-config deep links import silently (with auto-connect).
// Anything else keeps the confirmation dialog: a silently installed foreign
// profile would route all traffic through an attacker's proxy. Must list the
// subscription domain(s) (PUBLIC_BASE_URL host on the backend) — update when
// the production domain changes.
const trustedInstallHosts = ['144.31.155.223.sslip.io'];

// Base URL of our Mini App backend, which mirrors GitHub Releases for in-app
// updates (github.com is unreachable in the VPN's target regions). Update
// together with the production domain.
const updateBaseUrl = 'https://api.dhqclash.app';

bool isTrustedInstallUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    return false;
  }
  return trustedInstallHosts.contains(uri.host);
}

final defaultTextScaleFactor =
    WidgetsBinding.instance.platformDispatcher.textScaleFactor;
const httpTimeoutDuration = Duration(milliseconds: 5000);
const moreDuration = Duration(milliseconds: 100);
const animateDuration = Duration(milliseconds: 100);
const midDuration = Duration(milliseconds: 200);
const commonDuration = Duration(milliseconds: 300);
const defaultUpdateDuration = Duration(days: 1);
const MMDB = 'GEOIP.metadb';
const ASN = 'ASN.mmdb';
const GEOIP = 'GEOIP.dat';
const GEOSITE = 'GEOSITE.dat';
final double kHeaderHeight = system.isDesktop
    ? !system.isMacOS
          ? 40
          : 28
    : 0;
const profilesDirectoryName = 'profiles';
const localhost = '127.0.0.1';
const clashConfigKey = 'clash_config';
const configKey = 'config';
const double dialogCommonWidth = 300;
const repository = 'dashqee/DHQ-Clash';
const telegramUrl = 'https://t.me/dhqclashconfigbot';
const coreRepositoryUrl = 'https://github.com/MetaCubeX/mihomo';
const defaultExternalController = '127.0.0.1:9090';
const maxMobileWidth = 600;
const maxLaptopWidth = 840;
const defaultTestUrl = 'https://www.gstatic.com/generate_204';
final commonFilter = ImageFilter.blur(
  sigmaX: 5,
  sigmaY: 5,
  tileMode: TileMode.clamp,
);

const listEquality = ListEquality();
const navigationItemListEquality = ListEquality<NavigationItem>();
const trackerInfoListEquality = ListEquality<TrackerInfo>();
const stringListEquality = ListEquality<String>();
const intListEquality = ListEquality<int>();
const logListEquality = ListEquality<Log>();
const groupListEquality = ListEquality<Group>();
const ruleListEquality = ListEquality<Rule>();
const scriptListEquality = ListEquality<Script>();
const externalProviderListEquality = ListEquality<ExternalProvider>();
const packageListEquality = ListEquality<Package>();
const profileListEquality = ListEquality<Profile>();
const proxyGroupsEquality = ListEquality<ProxyGroup>();
const hotKeyActionListEquality = ListEquality<HotKeyAction>();
const stringAndStringMapEquality = MapEquality<String, String>();
const stringAndStringMapEntryListEquality =
    ListEquality<MapEntry<String, String>>();
const stringAndStringMapEntryIterableEquality =
    IterableEquality<MapEntry<String, String>>();
const stringAndObjectMapEntryIterableEquality =
    IterableEquality<MapEntry<String, Object?>>();
const delayMapEquality = MapEquality<String, Map<String, int?>>();
const stringSetEquality = SetEquality<String>();
const keyboardModifierListEquality = SetEquality<KeyboardModifier>();

const viewModeColumnsMap = {
  ViewMode.mobile: [2, 1],
  ViewMode.laptop: [3, 2],
  ViewMode.desktop: [4, 3],
};

const proxiesListStoreKey = PageStorageKey<String>('proxies_list');
const toolsStoreKey = PageStorageKey<String>('tools');
const profilesStoreKey = PageStorageKey<String>('profiles');

// "Fruit mix" — vibrant, appetizing fruit hues shipped as the default palette.
// Tangerine is the active default (a warm, friendly seed; red is intentionally
// avoided as the primary because it reads as "disconnected/error" here).
const fruitStrawberry = 0xFFEF5350;
const fruitTangerine = 0xFFFF7043;
const fruitLemon = 0xFFFFCA28;
const fruitKiwi = 0xFF9CCC65;
const fruitBlueberry = 0xFF42A5F5;
const fruitGrape = 0xFFAB47BC;
const fruitDragonfruit = 0xFFEC407A;

const defaultPrimaryColor = fruitTangerine;

double getWidgetHeight(num lines) {
  final space = 14.mAp;
  return max(lines * (80.ap + space) - space, 0);
}

const maxLength = 1000;

const mainIsolate = 'FlClashMainIsolate';

const serviceIsolate = 'FlClashServiceIsolate';

const defaultPrimaryColors = [
  fruitStrawberry,
  fruitTangerine,
  fruitLemon,
  fruitKiwi,
  fruitBlueberry,
  fruitGrape,
  fruitDragonfruit,
];

const scriptTemplate = '''
const main = (config) => {
  return config;
}''';

const backupDatabaseName = 'database.sqlite';
const configJsonName = 'config.json';
