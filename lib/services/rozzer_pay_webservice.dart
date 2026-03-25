// ignore: deprecated_member_use
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

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

    final String sessionKey =
        'rzp_${orderItemId}_${DateTime.now().millisecondsSinceEpoch}';
    js.context[sessionKey] = false;

    try {
      final Map<String, dynamic> options = {
        'key': AppConfig.razorpayKey,
        'amount': (amount * 100).toInt(),
        'currency': 'INR',
        'name': 'SandHere',
        'description': 'Order #$orderItemId',
        'prefill': {'name': customerName, 'email': email, 'contact': phone},
        'notes': {'order_id': orderItemId.toString()},
        'theme': {'color': '#15803D'},
        'handler': (response) {
          final handled = js.context[sessionKey] == true;
          if (handled) return;
          js.context[sessionKey] = true;

          if (response['razorpay_payment_id'] != null) {
            final paymentId = response['razorpay_payment_id'].toString();
            onSuccess(paymentId);
          } else if (response['error'] != null) {
            final errorCode =
                response['error']['code']?.toString() ?? 'unknown';
            final errorDesc =
                response['error']['description']?.toString() ??
                'Payment failed';
            onError('Razorpay $errorCode: $errorDesc');
          } else {
            onError('Payment cancelled.');
          }
        },
      };

      final jsOptions = js.JsObject.jsify(options);
      final rzp = js.JsObject(js.context['Razorpay'] as js.JsFunction, [
        jsOptions,
      ]);
      rzp.callMethod('open');
    } catch (e) {
      final errorMsg = e.toString().contains('Razorpay')
          ? 'Razorpay unavailable - ensure Razorpay checkout script is loaded'
          : 'Failed to initialize Razorpay: $e';
      onError(errorMsg);
      js.context[sessionKey] = true;
    }
  }
}
