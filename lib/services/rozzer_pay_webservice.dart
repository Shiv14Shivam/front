// ignore_for_file: deprecated_member_use, undefined_function, avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Flutter Web–only Razorpay bridge via dart:js.
///
/// CRITICAL RULE for dart:js interop with JsObject.jsify()
/// ──────────────────────────────────────────────────────────────────────────
/// js.allowInterop() MUST be called on each Dart closure BEFORE it is placed
/// inside ANY Map or List that will be passed to JsObject.jsify().
/// jsify() does a deep recursive serialization — if it encounters a raw Dart
/// function (even inside a nested map) it serializes it as an opaque object,
/// not a JS function, so the Razorpay SDK cannot call it.
///
/// Solution: extract every callback into a named variable, wrap it with
/// allowInterop(), then reference the variable in the map literal.
/// ──────────────────────────────────────────────────────────────────────────
class RazorpayWebService {
  static final RazorpayWebService _instance = RazorpayWebService._internal();
  factory RazorpayWebService() => _instance;
  RazorpayWebService._internal();

  void openPayment({
    required int orderItemId,
    required double amount,
    required String customerName,
    required String email,
    required String phone,
    required void Function(String paymentId) onSuccess,
    required void Function(String error) onError,
  }) {
    if (!kIsWeb) {
      onError('RazorpayWebService is only available on Flutter Web.');
      return;
    }

    if (amount <= 0) {
      onError('Invalid amount: must be positive.');
      return;
    }

    if (customerName.isEmpty || email.isEmpty || phone.isEmpty) {
      onError('Customer details required.');
      return;
    }

    // Unique flag in the global JS context — ensures handler and ondismiss
    // can never both fire callbacks for the same payment session.
    final String sessionKey =
        'rzp_handled_${orderItemId}_${DateTime.now().millisecondsSinceEpoch}';
    js.context[sessionKey] = false;

    try {
      // ── Step 1: wrap every Dart closure with allowInterop() FIRST ─────────
      // Do this BEFORE constructing the options map so jsify() never sees a
      // raw Dart function — it only sees already-converted JS function refs.

      final jsHandler = js.allowInterop((dynamic response) {
        if (js.context[sessionKey] == true) return;
        js.context[sessionKey] = true;

        // Test-mode UPI returns 'payment_id'; production returns
        // 'razorpay_payment_id'. Check both so neither mode breaks.
        final paymentId =
            _jsString(response, 'razorpay_payment_id') ??
            _jsString(response, 'payment_id');

        if (paymentId != null && paymentId.isNotEmpty) {
          onSuccess(paymentId);
        } else {
          onError('Payment completed but payment ID was missing.');
        }
      });

      final jsOnDismiss = js.allowInterop(() {
        if (js.context[sessionKey] == true) return;
        js.context[sessionKey] = true;
        onError('Payment window was closed.');
      });

      // ── Step 2: build the options map using the pre-wrapped JS refs ────────
      // No Dart closures appear inline here — only the jsHandler and
      // jsOnDismiss variables which are already valid JS function objects.
      final Map<String, dynamic> options = {
        'key': AppConfig.razorpayKey,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'name': 'SandHere',
        'description': 'Order #$orderItemId',
        'prefill': {'name': customerName, 'email': email, 'contact': phone},
        'notes': {'order_id': orderItemId.toString()},
        'theme': {'color': '#15803D'},
        'handler': jsHandler,
        'modal': {'ondismiss': jsOnDismiss},
      };

      // ── Step 3: jsify and open ─────────────────────────────────────────────
      final jsOptions = js.JsObject.jsify(options);
      final rzp = js.JsObject(js.context['Razorpay'] as js.JsFunction, [
        jsOptions,
      ]);

      rzp.callMethod('open');
    } catch (e) {
      // Set flag first so a late-firing ondismiss cannot also call onError.
      if (js.context[sessionKey] != true) {
        js.context[sessionKey] = true;
        final errorMsg = e.toString().contains('Razorpay')
            ? 'Razorpay unavailable — ensure checkout.js is loaded in web/index.html'
            : 'Failed to initialize Razorpay: $e';
        onError(errorMsg);
      }
    }
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  /// Safely reads a String from a JS object by [key].
  /// Returns null if the key is missing, null, or the value is empty.
  String? _jsString(dynamic jsObject, String key) {
    try {
      final value = (jsObject as js.JsObject)[key];
      if (value == null) return null;
      final str = value.toString();
      return str.isEmpty ? null : str;
    } catch (_) {
      return null;
    }
  }
}
