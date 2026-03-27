// lib/pages/payment_page.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import 'package:front/services/rozzer_pay_webservice.dart';
import 'package:front/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front/services/razor_pay_native_stub.dart'
    if (dart.library.io) 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:front/config/app_config.dart';

class PaymentPage extends StatefulWidget {
  final int orderItemId;
  final double totalAmount;
  final String productName;
  final String vendorName;
  final int quantity;
  final VoidCallback? onPaymentComplete;

  const PaymentPage({
    super.key,
    required this.orderItemId,
    required this.totalAmount,
    required this.productName,
    required this.vendorName,
    required this.quantity,
    this.onPaymentComplete,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _api = ApiService();
  final _razorpayWeb = RazorpayWebService();
  Razorpay? _razorpayNative;

  bool _isPayingNow = false;
  bool _isPayingLater = false;

  // ─────────────────────────────────────────────────────────────────────────
  // FIX for "always sends 3 days":
  //
  // _selectedDays is the source of truth written by pill taps.
  // _confirmPayLater() snapshots it into a local `final daysToRequest`
  // at the moment the button is tapped, guaranteeing the API call uses
  // the actual user selection rather than a potentially stale rebuild value.
  //
  // Additionally, the day picker card uses StatefulBuilder with a local
  // `pickerDays` variable that is kept in sync with _selectedDays.
  // This means the pill highlights and the button label update instantly
  // via setCard() without waiting for a full parent setState() rebuild.
  // ─────────────────────────────────────────────────────────────────────────
  int _selectedDays = 3;
  bool _showDayPicker = false;

  bool? _success;
  String _resultMessage = '';
  bool _isPayLaterResult = false;

  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    if (!kIsWeb) _initNativeRazorpay();
  }

  @override
  void dispose() {
    _razorpayNative?.clear();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString('user_data');
    if (userRaw == null) return;
    try {
      final user = jsonDecode(userRaw) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _userName = user['name'] as String? ?? '';
          _userEmail = user['email'] as String? ?? '';
          _userPhone = user['phone'] as String? ?? '';
        });
      }
    } catch (_) {}
  }

  // ── Native Razorpay ───────────────────────────────────────────────────────
  void _initNativeRazorpay() {
    _razorpayNative = Razorpay();
    _razorpayNative!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onNativeSuccess);
    _razorpayNative!.on(Razorpay.EVENT_PAYMENT_ERROR, _onNativeError);
    _razorpayNative!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onNativeWallet);
  }

  void _onNativeSuccess(PaymentSuccessResponse r) =>
      _verifyPaymentWithBackend(r.paymentId ?? '');

  void _onNativeError(PaymentFailureResponse r) {
    if (!mounted) return;
    setState(() {
      _isPayingNow = false;
      _success = false;
      _resultMessage = 'Payment cancelled or failed. Please try again.';
    });
  }

  void _onNativeWallet(ExternalWalletResponse r) {}

  // ── Pay Now ───────────────────────────────────────────────────────────────
  void _startPayNow() {
    if (_isPayingNow || _isPayingLater) return;
    setState(() => _isPayingNow = true);

    if (kIsWeb) {
      // Web path: RazorpayWebService has the _handled flag that prevents
      // ondismiss firing onError after a successful payment (the bug that
      // caused the "Payment Failed" browser alert).
      _razorpayWeb.openPayment(
        orderItemId: widget.orderItemId,
        amount: widget.totalAmount,
        customerName: _userName,
        email: _userEmail,
        phone: _userPhone,
        onSuccess: _verifyPaymentWithBackend,
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isPayingNow = false;
            _success = false;
            _resultMessage = error;
          });
        },
      );
    } else {
      // Native path: razorpay_flutter package
      final options = {
        'key': AppConfig.razorpayKey,
        'amount': (widget.totalAmount * 100).toInt(),
        'currency': 'INR',
        'name': 'SandHere',
        'description': 'Order #${widget.orderItemId}',
        'prefill': {
          'name': _userName,
          'email': _userEmail,
          'contact': _userPhone,
        },
        'notes': {'order_item_id': widget.orderItemId.toString()},
        'theme': {'color': '#15803D'},
      };
      try {
        _razorpayNative?.open(options);
      } catch (e) {
        setState(() {
          _isPayingNow = false;
          _success = false;
          _resultMessage = 'Could not open payment. Please try again.';
        });
      }
    }
  }

  Future<void> _verifyPaymentWithBackend(String paymentId) async {
    final result = await _api.payNow(
      widget.orderItemId,
      razorpayPaymentId: paymentId,
    );
    if (!mounted) return;
    setState(() {
      _isPayingNow = false;
      _isPayLaterResult = false;
      _success = result['success'] == true;
      _resultMessage =
          result['message'] ??
          (_success! ? 'Payment successful!' : 'Payment failed.');
    });
    if (_success == true) widget.onPaymentComplete?.call();
  }

  // ── Pay Later ─────────────────────────────────────────────────────────────
  Future<void> _confirmPayLater() async {
    if (_isPayingNow || _isPayingLater) return;

    // FIX: snapshot _selectedDays into a local final RIGHT NOW.
    // Any parent setState() that happens during the async gap below
    // cannot change this local value, so the API always receives
    // exactly what the user tapped.
    final daysToRequest = _selectedDays;

    setState(() {
      _isPayingLater = true;
      _showDayPicker = false;
    });

    final result = await _api.payLater(
      widget.orderItemId,
      daysRequested: daysToRequest,
    );

    if (!mounted) return;
    final success = result['success'] == true;
    final dueFormatted =
        result['data']?['payment_due_formatted'] as String? ?? '';

    setState(() {
      _isPayingLater = false;
      _isPayLaterResult = success;
      _success = success;
      _resultMessage = success
          ? 'Pay later requested for $daysToRequest day(s).\n'
                'Payment due: $dueFormatted\n\n'
                'The vendor will approve or reject your request.'
          : result['message'] ?? 'Failed to set pay later.';
    });
    // NOTE: onPaymentComplete is NOT called here.
    // The vendor must approve the pay-later request first.
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatDueDate(int days) {
    final due = DateTime.now().add(Duration(days: days));
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${due.day} ${m[due.month]} ${due.year}';
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_success != null) return _buildResultScreen();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text(
          'Payment',
          style: TextStyle(
            color: AppColors.titleText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.titleText,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildOrderSummaryCard(),
                const SizedBox(height: 20),
                if (_showDayPicker) ...[
                  _buildDayPickerCard(),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildPayNowButton(),
                  const SizedBox(height: 12),
                  _buildPayLaterButton(),
                ],
                const SizedBox(height: 24),
                _buildSecureNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Order summary card ────────────────────────────────────────────────────
  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.titleText,
                      ),
                    ),
                    Text(
                      'Sold by ${widget.vendorName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.bodyText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          _summaryRow('Order ID', '#${widget.orderItemId}'),
          _summaryRow('Quantity', '${widget.quantity} unit'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '₹${widget.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.bodyText),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.titleText,
          ),
        ),
      ],
    ),
  );

  // ── Pay Now button ────────────────────────────────────────────────────────
  Widget _buildPayNowButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: (_isPayingNow || _isPayingLater) ? null : _startPayNow,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isPayingNow
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Opening Payment…', style: TextStyle(fontSize: 15)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pay Now  ₹${widget.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Pay Later button ──────────────────────────────────────────────────────
  Widget _buildPayLaterButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: (_isPayingNow || _isPayingLater)
            ? null
            : () => setState(() => _showDayPicker = true),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.sandDark,
          side: BorderSide(color: AppColors.sand.withOpacity(0.7), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 20,
              color: AppColors.sandDark.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            const Text(
              'Pay Later',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // ── Day picker card ───────────────────────────────────────────────────────
  //
  // FIX: StatefulBuilder wraps the entire card so pill taps call setCard()
  // which rebuilds ONLY this card (fast, no full tree rebuild). The local
  // `pickerDays` variable drives the pill highlight and the button label.
  // Each pill tap ALSO calls setState(() => _selectedDays = day) so the
  // parent always holds the latest value for _confirmPayLater() to read.
  Widget _buildDayPickerCard() {
    return StatefulBuilder(
      builder: (context, setCard) {
        // Local variable that mirrors _selectedDays.
        // Scoped to this builder so it won't be reset by parent rebuilds.
        int pickerDays = _selectedDays;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.sand.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Text(
                    'Choose payment days',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.titleText,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showDayPicker = false),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.subtleText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Vendor will approve or reject your request.',
                style: TextStyle(fontSize: 12, color: AppColors.bodyText),
              ),
              const SizedBox(height: 16),

              // Day pills 1–7
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final isSelected = pickerDays == day;
                  return GestureDetector(
                    onTap: () {
                      // setCard: updates local pickerDays → fast pill highlight
                      setCard(() => pickerDays = day);
                      // setState: keeps parent _selectedDays in sync
                      setState(() => _selectedDays = day);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        day == 1 ? '1 day' : '$day days',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.bodyText,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Due date preview — uses pickerDays for live update
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sandLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.sand.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: AppColors.sandDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Payment due by: ${_formatDueDate(pickerDays)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sandDark,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Confirm button — label uses pickerDays for live update
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isPayingLater ? null : _confirmPayLater,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isPayingLater
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Request $pickerDays-Day Pay Later',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Secure note ───────────────────────────────────────────────────────────
  Widget _buildSecureNote() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: AppColors.subtleText.withOpacity(0.7),
        ),
        const SizedBox(width: 5),
        Text(
          'Secured by Razorpay',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.subtleText.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // ── Result screen ─────────────────────────────────────────────────────────
  Widget _buildResultScreen() {
    final isSuccess = _success == true;

    final icon = isSuccess
        ? (_isPayLaterResult
              ? Icons.access_time_rounded
              : Icons.check_circle_rounded)
        : Icons.error_outline_rounded;

    final iconColor = isSuccess
        ? (_isPayLaterResult ? AppColors.warning : AppColors.success)
        : AppColors.error;

    final iconBg = isSuccess
        ? (_isPayLaterResult
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFE8F5E9))
        : const Color(0xFFFFEBEE);

    final heading = isSuccess
        ? (_isPayLaterResult ? 'Request Sent!' : 'Payment Done!')
        : 'Something went wrong';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, size: 44, color: iconColor),
                ),
                const SizedBox(height: 20),
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.titleText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _resultMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.bodyText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSuccess
                        ? () => Navigator.of(context).maybePop()
                        : () => setState(() {
                            _success = null;
                            _resultMessage = '';
                            _isPayLaterResult = false;
                          }),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess
                          ? (_isPayLaterResult
                                ? AppColors.primary
                                : AppColors.success)
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isSuccess ? 'Back to Home' : 'Try Again',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
