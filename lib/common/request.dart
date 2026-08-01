import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

class Request {
  late final Dio dio;
  late final Dio _clashDio;

  /// Mirrors [_clashDio] but always connects directly, ignoring the local
  /// mixed-proxy. Used as a fallback when the proxied fetch is refused.
  late final Dio _directDio;
  String? userAgent;

  Request() {
    dio = Dio(BaseOptions(headers: {'User-Agent': browserUa}));
    _clashDio = Dio();
    _clashDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (Uri uri) {
          client.userAgent = globalState.ua;
          return AppHttpOverrides.handleFindProxy(uri);
        };
        return client;
      },
    );
    _directDio = Dio();
    _directDio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.userAgent = globalState.ua;
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
  }

  /// Fetch [url] through the clash proxy, but retry once directly if the proxied
  /// attempt failed in a way the direct path can plausibly fix.
  ///
  /// Refusal: while the core is starting/reconfiguring the request is routed to
  /// `localhost:<mixedPort>` (see [AppHttpOverrides.handleFindProxy]) which is
  /// briefly not listening, surfacing as `SocketException` (errno 1225 =
  /// WSAECONNREFUSED on Windows). Common trigger: installing a profile from a deep
  /// link while connected.
  ///
  /// Timeout: the port accepts but the selected outbound is a black hole — notably
  /// when that outbound is the video-call tunnel and the tunnel itself is what we are
  /// trying to repair. Only callers that set a timeout can hit this branch.
  Future<Response<T>> _getWithDirectFallback<T>(
    String url,
    Options options,
  ) async {
    final wasProxied = AppHttpOverrides.handleFindProxy(
      Uri.parse(url),
    ).startsWith('PROXY');
    try {
      return await _clashDio.get<T>(url, options: options);
    } on DioException catch (e) {
      const timeouts = {
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      };
      final recoverable = e.error is SocketException || timeouts.contains(e.type);
      if (wasProxied && recoverable) {
        commonPrint.log(
          'proxied fetch failed (${e.type.name}), retrying direct: $url',
          logLevel: LogLevel.warning,
        );
        return _directDio.get<T>(url, options: options);
      }
      rethrow;
    }
  }

  Future<Response<Uint8List>> getFileResponseForUrl(String url) async {
    try {
      return await _getWithDirectFallback<Uint8List>(
        url,
        Options(responseType: ResponseType.bytes),
      );
    } catch (e) {
      commonPrint.log('getFileResponseForUrl error ${e.toString()}');
      if (e is DioException) {
        if (e.type == DioExceptionType.unknown) {
          throw currentAppLocalizations.unknownNetworkError;
        } else if (e.type == DioExceptionType.badResponse) {
          throw currentAppLocalizations.networkException;
        }
        rethrow;
      }
      throw currentAppLocalizations.unknownNetworkError;
    }
  }

  Future<Response<String>> getTextResponseForUrl(String url) async {
    return _getWithDirectFallback<String>(
      url,
      Options(responseType: ResponseType.plain),
    );
  }

  Future<VideoCallTunnelLinkResult> getVideoCallTunnelLink(
    String subscriptionUrl,
  ) async {
    final uri = buildVideoCallTunnelLinkUri(subscriptionUrl);
    if (uri == null) {
      return const VideoCallTunnelLinkResult(
        VideoCallTunnelLinkStatus.invalidSubscription,
      );
    }
    try {
      final response = await _getWithDirectFallback<Object?>(
        uri.toString(),
        Options(
          responseType: ResponseType.json,
          validateStatus: (_) => true,
          headers: const {'Cache-Control': 'no-cache'},
          // This request is how a broken tunnel gets repaired, and the proxied path
          // may run through that very tunnel. Bound it well under the sidecar's 20s
          // SOCKS CONNECT timeout so the direct retry actually gets a turn.
          sendTimeout: videoCallTunnelLinkTimeout,
          receiveTimeout: videoCallTunnelLinkTimeout,
        ),
      );
      return parseVideoCallTunnelLinkResponse(
        response.statusCode,
        response.data,
      );
    } catch (error) {
      commonPrint.log(
        'getVideoCallTunnelLink failed (${error.runtimeType})',
        logLevel: LogLevel.warning,
      );
      return const VideoCallTunnelLinkResult(VideoCallTunnelLinkStatus.error);
    }
  }

  Future<MemoryImage?> getImage(String url) async {
    if (url.isEmpty) return null;
    final response = await dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) return null;
    return MemoryImage(data);
  }

  Future<Map<String, dynamic>?> checkForUpdate({
    UpdateChannel channel = UpdateChannel.stable,
    bool includeCurrent = false,
  }) async {
    final pa = updatePlatformArch();
    if (pa == null) return null;
    final version = globalState.appVersion;
    try {
      final response = await dio.get(
        '$updateBaseUrl/api/app/latest',
        queryParameters: {
          'platform': pa.$1,
          'arch': pa.$2,
          'channel': channel.name,
        },
        options: Options(responseType: ResponseType.json),
      );
      if (response.statusCode != 200) return null;
      final data = response.data as Map<String, dynamic>;
      if (data['update'] != true) return null;
      final remoteVersion = (data['version'] ?? '').toString();
      final hasUpdate = utils.isUpdateAvailable(
        remoteVersion: remoteVersion,
        currentVersion: version,
        channel: channel,
      );
      if (!hasUpdate && !includeCurrent) return null;
      return {...data, '_hasUpdate': hasUpdate};
    } catch (e) {
      commonPrint.log('checkForUpdate failed', logLevel: LogLevel.warning);
      return null;
    }
  }

  /// Download an update artifact to [savePath], reporting progress in [0,1].
  Future<void> downloadUpdate(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    await dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) onProgress(received / total);
      },
    );
  }

  final Map<String, IpInfo Function(Map<String, dynamic>)> _ipInfoSources = {
    'https://ipwho.is': IpInfo.fromIpWhoIsJson,
    'https://api.myip.com': IpInfo.fromMyIpJson,
    'https://ipapi.co/json': IpInfo.fromIpApiCoJson,
    'https://ident.me/json': IpInfo.fromIdentMeJson,
    'http://ip-api.com/json': IpInfo.fromIpAPIJson,
    'https://api.ip.sb/geoip': IpInfo.fromIpSbJson,
    'https://ipinfo.io/json': IpInfo.fromIpInfoIoJson,
  };

  Future<Result<IpInfo?>> checkIp({CancelToken? cancelToken}) async {
    var failureCount = 0;
    final token = cancelToken ?? CancelToken();
    final futures = _ipInfoSources.entries.map((source) async {
      final Completer<Result<IpInfo?>> completer = Completer();
      void handleFailRes() {
        if (!completer.isCompleted && failureCount == _ipInfoSources.length) {
          completer.complete(Result.success(null));
        }
      }

      final future = dio
          .get<Map<String, dynamic>>(
            source.key,
            cancelToken: token,
            options: Options(responseType: ResponseType.json),
          )
          .timeout(const Duration(seconds: 10));
      future
          .then((res) {
            if (res.statusCode == HttpStatus.ok && res.data != null) {
              completer.complete(Result.success(source.value(res.data!)));
              return;
            }
            commonPrint.log('checkIp data empty', logLevel: LogLevel.info);
            failureCount++;
            handleFailRes();
          })
          .catchError((e) {
            failureCount++;
            if (e is DioException && e.type == DioExceptionType.cancel) {
              completer.complete(Result.error('cancelled'));
              return;
            }
            commonPrint.log('checkIp error $e', logLevel: LogLevel.warning);
            handleFailRes();
          });
      return completer.future;
    });
    final res = await Future.any(futures);
    token.cancel();
    return res;
  }

  Future<bool> pingHelper() async {
    try {
      final response = await dio
          .get(
            'http://$localhost:$helperPort/ping',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      if (kDebugMode) {
        return true;
      }
      return (response.data as String) == globalState.coreSHA256;
    } catch (_) {
      return false;
    }
  }

  Future<String> startCoreByHelper(String arg) async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/start',
            data: json.encode({'path': appPath.corePath, 'arg': arg}),
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        return 'Windows TUN helper returned HTTP ${response.statusCode}.';
      }
      final data = response.data as String;
      return data;
    } catch (error) {
      return 'Failed to start core through the Windows TUN helper: $error';
    }
  }

  Future<bool> stopCoreByHelper() async {
    try {
      final response = await dio
          .post(
            'http://$localhost:$helperPort/stop',
            options: Options(responseType: ResponseType.plain),
          )
          .timeout(const Duration(milliseconds: 2000));
      if (response.statusCode != HttpStatus.ok) {
        return false;
      }
      final data = response.data as String;
      return data.isEmpty;
    } catch (_) {
      return false;
    }
  }
}

final request = Request();
