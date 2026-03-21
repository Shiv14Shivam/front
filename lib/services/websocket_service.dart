import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:front/config/app_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WebSocketService
//
// Connects to Laravel Reverb using the Pusher protocol over WebSocket.
//
// HOW REVERB WORKS (Pusher protocol):
//   1. Connect to ws://host:8080/app/{APP_KEY}
//   2. Server sends:  {"event":"pusher:connection_established","data":"{\"socket_id\":\"...\"}"}
//   3. Subscribe to a PRIVATE channel by sending pusher:subscribe with auth token
//      from POST /broadcasting/auth
//   4. Server confirms with pusher_internal:subscription_succeeded
//   5. From then on, events arrive as:
//      {"event":"order.placed","channel":"private-vendor.3","data":"{...}"}
//
// USAGE:
//   final ws = WebSocketService();
//   await ws.connect(token: authToken, userId: 3, isVendor: true);
//   ws.onNotification = (data) { ... };
//   ws.dispose();  // on page dispose
// ─────────────────────────────────────────────────────────────────────────────

class WebSocketService {
  // ── Config — update these to match your .env ──────────────────────────────
  static const _appKey = 'z7jb69t7onshtuge4biw'; // REVERB_APP_KEY in .env
  static const _wsPort = 9000; // REVERB_PORT (default 8080)

  // ── State ──────────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _disposed = false;

  // Reconnect
  int _retryCount = 0;
  static const _maxRetries = 5;
  Timer? _retryTimer;

  // Saved params for reconnect
  String? _token;
  int? _userId;
  bool? _isVendor;

  // ── Callbacks ──────────────────────────────────────────────────────────────

  /// Called with the raw `data` map from every broadcast event
  void Function(Map<String, dynamic> data)? onNotification;

  /// Called when connection state changes
  void Function(WsState state)? onStateChange;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  // ── Connect ────────────────────────────────────────────────────────────────

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

    // Build WebSocket URL
    // Reverb listens on the same host as Laravel, just different port.
    // AppConfig.baseUrl is e.g. "http://10.0.2.2/api"
    // We strip to host and use WS scheme.
    final host = _hostFromBaseUrl(AppConfig.baseUrl);
    final wsUrl =
        'ws://$host:$_wsPort/app/$_appKey'
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

  // ── Message handling ───────────────────────────────────────────────────────

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
      // Step 2: Connection established — subscribe to private channel
      case 'pusher:connection_established':
        _setState(WsState.connected);
        _retryCount = 0;
        final channel = isVendor
            ? 'private-vendor.$userId'
            : 'private-customer.$userId';
        _subscribeToChannel(
          channel,
          token: token,
          userId: userId,
          isVendor: isVendor,
        );
        break;

      // Step 4: Subscription confirmed
      case 'pusher_internal:subscription_succeeded':
        _setState(WsState.subscribed);
        break;

      // Subscription error (auth failed)
      case 'pusher:subscription_error':
        _setState(WsState.authError);
        break;

      // Actual broadcast events
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

  // ── Private channel subscription ──────────────────────────────────────────
  // Reverb uses Pusher protocol: we need a channel auth token from
  // POST /broadcasting/auth  { socket_id, channel_name }
  // For simplicity this sends the Sanctum token as the auth — works with
  // Laravel's default BroadcastServiceProvider + Sanctum guard.

  void _subscribeToChannel(
    String channelName, {
    required String token,
    required int userId,
    required bool isVendor,
  }) {
    // We need socket_id for the auth request, but for self-contained
    // private channels (vendor.{id}, customer.{id}) Reverb accepts
    // the Bearer token directly via the pusher auth mechanism.
    // The auth string format Reverb expects: "Bearer {sanctum_token}"
    _send({
      'event': 'pusher:subscribe',
      'data': {
        'channel': channelName,
        'auth': 'Bearer $token', // Reverb validates this against Sanctum
      },
    });
  }

  // ── Socket helpers ─────────────────────────────────────────────────────────

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
    final delay = Duration(seconds: 2 * (1 << _retryCount)); // 2, 4, 8, 16, 32s
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

  // ── Dispose ────────────────────────────────────────────────────────────────

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Extracts host from base URL.
  /// "http://10.0.2.2/api" → "10.0.2.2"
  /// "http://sandbackend.test/api" → "sandbackend.test"
  static String _hostFromBaseUrl(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return 'localhost';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum WsState {
  disconnected,
  connecting,
  connected,
  subscribed, // fully live — receiving events
  authError, // Sanctum token rejected
  failed, // max retries exceeded
}
