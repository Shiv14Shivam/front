import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:front/config/app_config.dart';

class WebSocketService {
  static const _appKey = 'z7jb69t7onshtuge4biw';

  // ── Derive WS port from base URL instead of hardcoding ──────────────────
  // Production (https → wss, no explicit port needed)
  // Local dev (http → ws, use REVERB_PORT e.g. 8080 or 9000)
  static const _localWsPort = 9000; // only used in non-prod

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _disposed = false;

  int _retryCount = 0;
  static const _maxRetries = 5;
  Timer? _retryTimer;

  String? _token;
  int? _userId;
  bool? _isVendor;

  void Function(Map<String, dynamic> data)? onNotification;
  void Function(WsState state)? onStateChange;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  Future<void> connect({
    required String token,
    required int userId,
    required bool isVendor,
  }) async {
    _token = token;
    _userId = userId;
    _isVendor = isVendor;
    _disposed = false;

    _setState(WsState.connecting);

    final baseUri = Uri.parse(AppConfig.baseUrl);
    final isProd = baseUri.scheme == 'https';

    // Production: wss://host/app/KEY  (Railway handles TLS, no explicit port)
    // Local:      ws://host:9000/app/KEY
    final wsScheme = isProd ? 'wss' : 'ws';
    final host = baseUri.host;
    final portSegment = isProd ? '' : ':$_localWsPort';

    final wsUrl =
        '$wsScheme://$host$portSegment/app/$_appKey'
        '?protocol=7&client=flutter&version=1.0&flash=false';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        (msg) => _onMessage(
          msg as String,
          token: token,
          userId: userId,
          isVendor: isVendor,
        ),
        onError: (e) => _onError(e),
        onDone: () => _onDone(),
      );
    } catch (e) {
      _scheduleRetry();
    }
  }

  void _onMessage(
    String raw, {
    required String token,
    required int userId,
    required bool isVendor,
  }) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = msg['event'] as String? ?? '';

    switch (event) {
      case 'pusher:connection_established':
        _setState(WsState.connected);
        _retryCount = 0;
        final channel = isVendor
            ? 'private-vendor.$userId'
            : 'private-customer.$userId';
        _subscribeToChannel(channel, token: token);
        break;

      case 'pusher_internal:subscription_succeeded':
        _setState(WsState.subscribed);
        break;

      case 'pusher:subscription_error':
        _setState(WsState.authError);
        break;

      case 'order.placed':
      case 'order.updated':
        final rawData = msg['data'];
        if (rawData == null) break;
        Map<String, dynamic> data;
        if (rawData is String) {
          try {
            data = jsonDecode(rawData) as Map<String, dynamic>;
          } catch (_) {
            break;
          }
        } else {
          data = rawData as Map<String, dynamic>;
        }
        onNotification?.call(data);
        break;
    }
  }

  void _subscribeToChannel(String channelName, {required String token}) {
    _send({
      'event': 'pusher:subscribe',
      'data': {'channel': channelName, 'auth': 'Bearer $token'},
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _onError(dynamic error) {
    _setState(WsState.disconnected);
    _scheduleRetry();
  }

  void _onDone() {
    if (_disposed) return;
    _setState(WsState.disconnected);
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || _retryCount >= _maxRetries) {
      _setState(WsState.failed);
      return;
    }
    final delay = Duration(seconds: 2 * (1 << _retryCount));
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_disposed && _token != null) {
        connect(token: _token!, userId: _userId!, isVendor: _isVendor!);
      }
    });
  }

  void _setState(WsState s) {
    _state = s;
    onStateChange?.call(s);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}

enum WsState {
  disconnected,
  connecting,
  connected,
  subscribed,
  authError,
  failed,
}
