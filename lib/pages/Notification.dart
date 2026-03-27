// lib/pages/notifications_page.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// CORRECT FLOW
// ═══════════════════════════════════════════════════════════════════════════
//
// 1. Customer places order  → Vendor gets "New Order" (Accept/Reject buttons)
// 2. Vendor accepts         → Customer gets "Order Accepted" (Pay Now / Pay Later)
// 3a. Customer pays now     → Razorpay → backend → status=processing, paid
//                           → Both get PaymentConfirmed notification
// 3b. Customer pays later   → status stays 'accepted', payment_status='pay_later'
//                           → Vendor gets PayLaterRequested (Approve/Reject buttons)
// 4a. Vendor approves       → status='processing', payment_status='pay_later'
//                           → Customer gets PayLaterDecision(accepted=true)
//                           → Flutter shows: Pay Now button + due date
// 4b. Vendor rejects        → status='declined', payment_status='unpaid'
//                           → Customer gets PayLaterDecision(accepted=false)
//                           → Flutter shows: cancelled banner, no buttons
// 5.  Customer pays (step 4a) → status='delivered', payment_status='paid'
//                           → Both get PaymentConfirmed notification
//
// ═══════════════════════════════════════════════════════════════════════════
// BUTTON VISIBILITY MATRIX (Customer notifications)
// ═══════════════════════════════════════════════════════════════════════════
//
// status='accepted' + payment_status='unpaid'    → Pay Now + Pay Later buttons
// status='accepted' + payment_status='pay_later' → Waiting banner (no buttons)
// status='processing' + payment_status='pay_later'→ Pay Now button + due banner
// status='processing' + payment_status='paid'    → Confirmed banner only
// status='delivered'  + payment_status='paid'    → Delivered banner only
// status='declined'                              → Declined banner only
//
// ═══════════════════════════════════════════════════════════════════════════
// BUTTON VISIBILITY MATRIX (Vendor notifications)
// ═══════════════════════════════════════════════════════════════════════════
//
// status='pending'           → View Orders button
// status='pay_later_pending' → Approve Pay Later + Reject buttons
// status='processing'/etc.   → Status banner only

import 'dart:convert';
import 'package:front/config/app_config.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:front/services/api_service.dart';
import 'package:front/services/websocket_service.dart';
import 'package:front/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front/services/rozzer_pay_webservice.dart'
    if (dart.library.js) 'package:front/services/rozzer_pay_webservice.dart';

import 'package:front/services/razor_pay_native_stub.dart'
    if (dart.library.io) 'package:razorpay_flutter/razorpay_flutter.dart';

import '../utils/responsive.dart';
import '../view_type.dart';
import '../widgets/web_scaffold.dart';

// =============================================================================
// MODEL
// =============================================================================

class _Notif {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  _Notif({
    required this.id,
    required this.type,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory _Notif.fromJson(Map<String, dynamic> j) => _Notif(
    id: j['id'] as String,
    type: j['type'] as String,
    data: (j['data'] as Map<String, dynamic>?) ?? {},
    isRead: j['read_at'] != null,
    createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );

  // ── Short type helper ───────────────────────────────────────────────────────
  String get shortType => type.split('\\').last;

  // ── Status helpers ──────────────────────────────────────────────────────────
  String get orderStatus => data['status'] as String? ?? '';
  String get paymentStatus => data['payment_status'] as String? ?? 'unpaid';
  String get recipientType => data['recipient_type'] as String? ?? '';
  String get reminderType => data['reminder_type'] as String? ?? '';

  // 'pay_later_pending' is ONLY used in PayLaterRequestedNotification payload
  // to tell the vendor card to show Approve/Reject buttons.
  bool get isPayLaterPending => orderStatus == 'pay_later_pending';
  bool get isPaymentDueReminder =>
      reminderType == 'tomorrow' || reminderType == 'today';

  // ── Display helpers ─────────────────────────────────────────────────────────
  String get title => (data['title'] as String?) ?? _defaultTitle;
  String get body => (data['body'] as String?) ?? '';

  String get _defaultTitle {
    switch (shortType) {
      case 'OrderPlacedNotification':
        return 'New Order Received';
      case 'PayLaterRequestedNotification':
        return 'Pay Later Requested';
      case 'PaymentConfirmedNotification':
        return 'Payment Confirmed';
      case 'PayLaterDecisionNotification':
        return orderStatus == 'processing'
            ? 'Pay Later Approved — Pay When Ready'
            : 'Pay Later Rejected';
      case 'PaymentDueReminderNotification':
        return reminderType == 'today'
            ? 'Payment Due Today!'
            : 'Payment Due Tomorrow';
      case 'OrderStatusUpdatedNotification':
        return 'Order Status Updated';
      default:
        return 'Notification';
    }
  }

  IconData get icon {
    if (isPaymentDueReminder) {
      return reminderType == 'today'
          ? Icons.alarm_rounded
          : Icons.access_time_rounded;
    }
    if (shortType == 'PaymentConfirmedNotification') {
      return Icons.check_circle_outline_rounded;
    }
    if (shortType == 'PayLaterDecisionNotification') {
      return orderStatus == 'processing'
          ? Icons.access_time_rounded
          : Icons.cancel_outlined;
    }
    if (shortType == 'PayLaterRequestedNotification') {
      return Icons.hourglass_top_rounded;
    }
    if (shortType == 'OrderPlacedNotification') {
      return Icons.shopping_bag_outlined;
    }
    switch (orderStatus) {
      case 'accepted':
        return Icons.check_circle_outline;
      case 'declined':
        return Icons.cancel_outlined;
      case 'processing':
        return Icons.autorenew_rounded;
      case 'shipped':
        return Icons.local_shipping_outlined;
      case 'delivered':
        return Icons.done_all_rounded;
    }
    if (isPayLaterPending) return Icons.hourglass_top_rounded;
    return Icons.notifications_outlined;
  }

  Color get accentColor {
    if (isPaymentDueReminder) {
      return reminderType == 'today' ? AppColors.error : AppColors.warning;
    }
    if (shortType == 'PaymentConfirmedNotification') return AppColors.success;
    if (shortType == 'PayLaterDecisionNotification') {
      return orderStatus == 'processing' ? AppColors.warning : AppColors.error;
    }
    if (shortType == 'PayLaterRequestedNotification') return AppColors.warning;
    if (isPayLaterPending) return AppColors.warning;
    switch (orderStatus) {
      case 'accepted':
        return AppColors.success;
      case 'declined':
        return AppColors.error;
      case 'delivered':
        return AppColors.success;
      case 'processing':
        return AppColors.primary;
      case 'shipped':
        return AppColors.primaryDark;
    }
    return AppColors.warning;
  }

  Color get bgColor {
    if (isPaymentDueReminder) {
      return reminderType == 'today'
          ? const Color(0xFFFFEBEE)
          : const Color(0xFFFFF8E1);
    }
    if (shortType == 'PaymentConfirmedNotification') {
      return const Color(0xFFE8F5E9);
    }
    if (shortType == 'PayLaterDecisionNotification') {
      return orderStatus == 'processing'
          ? const Color(0xFFFFF8E1)
          : const Color(0xFFFFEBEE);
    }
    if (shortType == 'PayLaterRequestedNotification') {
      return const Color(0xFFFFF8E1);
    }
    if (isPayLaterPending) return const Color(0xFFFFF8E1);
    switch (orderStatus) {
      case 'accepted':
        return const Color(0xFFE8F5E9);
      case 'declined':
        return const Color(0xFFFFEBEE);
      case 'delivered':
        return const Color(0xFFE8F5E9);
      case 'processing':
        return AppColors.primaryMuted;
      case 'shipped':
        return AppColors.primaryMuted;
    }
    return AppColors.sandLight;
  }

  _Notif asRead() => _Notif(
    id: id,
    type: type,
    data: data,
    isRead: true,
    createdAt: createdAt,
  );

  _Notif withData(Map<String, dynamic> newData) => _Notif(
    id: id,
    type: type,
    data: newData,
    isRead: true,
    createdAt: createdAt,
  );
}

// =============================================================================
// PAGE
// =============================================================================

class NotificationsPage extends StatefulWidget {
  final Function(ViewType, {String? userType}) onSelectView;
  final bool isVendor;

  const NotificationsPage({
    super.key,
    required this.onSelectView,
    this.isVendor = true,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  final _api = ApiService();
  final _ws = WebSocketService();
  final _razorpayWeb = RazorpayWebService();
  Razorpay? _razorpayNative;

  int? _pendingPaymentOrderItemId;
  double? _pendingPaymentAmount;

  List<_Notif> _notifs = [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  final Map<int, String> _actionLoading = {};
  WsState _wsState = WsState.disconnected;
  bool _newArrived = false;

  int get _unreadCount => _notifs.where((n) => !n.isRead).length;
  List<_Notif> get _filtered =>
      _tab == 1 ? _notifs.where((n) => !n.isRead).toList() : _notifs;
  Color get _themeAccent =>
      widget.isVendor ? AppColors.vendor : AppColors.primary;
  LinearGradient get _themeGradient =>
      widget.isVendor ? AppColors.vendorGradient : AppColors.primaryGradient;
  bool get _isDesktopWeb => kIsWeb && !Responsive.isMobile(context);

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );
    _contentFade = CurvedAnimation(
      parent: _entryCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
          ),
        );

    if (!widget.isVendor) _initRazorpay();
    _loadFromHttp();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _razorpayNative?.clear();
    _ws.dispose();
    super.dispose();
  }

  void _initRazorpay() {
    if (!kIsWeb) {
      _razorpayNative = Razorpay();
      _razorpayNative!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onNativeSuccess);
      _razorpayNative!.on(Razorpay.EVENT_PAYMENT_ERROR, _onNativeError);
      _razorpayNative!.on(Razorpay.EVENT_EXTERNAL_WALLET, _onNativeWallet);
    }
  }

  void _onNativeSuccess(PaymentSuccessResponse response) =>
      _handlePaymentSuccess(response.paymentId ?? '');

  void _onNativeError(PaymentFailureResponse response) {
    final id = _pendingPaymentOrderItemId;
    if (id != null) setState(() => _actionLoading.remove(id));
    _showSnack('Payment cancelled or failed.', isSuccess: false);
    _pendingPaymentOrderItemId = null;
    _pendingPaymentAmount = null;
  }

  void _onNativeWallet(ExternalWalletResponse response) {}

  // ── After Razorpay returns a paymentId, verify with backend ─────────────
  Future<void> _handlePaymentSuccess(String paymentId) async {
    final orderItemId = _pendingPaymentOrderItemId;
    if (orderItemId == null) return;

    final result = await _api.payNow(orderItemId, razorpayPaymentId: paymentId);

    if (!mounted) return;
    setState(() => _actionLoading.remove(orderItemId));

    if (result['success'] == true) {
      _showSnack(result['message'] ?? 'Payment successful!', isSuccess: true);
      // Update local notification state to show confirmed banner
      final data = result['data'] as Map<String, dynamic>?;
      final newStatus = data?['order_status'] as String? ?? 'processing';
      _updateNotifData(orderItemId, newStatus: newStatus, payStatus: 'paid');
    } else {
      _showSnack(result['message'] ?? 'Payment failed.', isSuccess: false);
    }
    _pendingPaymentOrderItemId = null;
    _pendingPaymentAmount = null;
  }

  // ── Load notifications from HTTP ─────────────────────────────────────────
  Future<void> _loadFromHttp() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _api.getNotifications();
    if (!mounted) return;

    if (result['success'] == true) {
      final rawList = result['data'] as List? ?? [];
      setState(() {
        _notifs = rawList
            .map((e) => _Notif.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
      _entryCtrl.forward(from: 0);
    } else {
      setState(() {
        _error = result['message'] as String? ?? 'Failed to load notifications';
        _loading = false;
      });
    }
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userRaw = prefs.getString('user_data');
    if (token == null || userRaw == null) return;

    Map<String, dynamic> user;
    try {
      user = jsonDecode(userRaw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final userId = user['id'] as int?;
    if (userId == null) return;

    _ws.onStateChange = (WsState s) {
      if (mounted) setState(() => _wsState = s);
    };
    _ws.onNotification = (Map<String, dynamic> wsData) {
      if (!mounted) return;
      final notif = _Notif(
        id: 'ws_${DateTime.now().millisecondsSinceEpoch}',
        type:
            wsData['type'] as String? ??
            'App\\Notifications\\OrderStatusUpdatedNotification',
        data: wsData,
        isRead: false,
        createdAt: DateTime.now(),
      );
      setState(() {
        _notifs.insert(0, notif);
        _newArrived = true;
      });
      _showSnack(notif.title);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _newArrived = false);
      });
    };

    await _ws.connect(token: token, userId: userId, isVendor: widget.isVendor);
  }

  // ── Mark read ─────────────────────────────────────────────────────────────
  Future<void> _markAsRead(_Notif notif) async {
    if (notif.isRead) return;
    setState(() {
      final i = _notifs.indexWhere((n) => n.id == notif.id);
      if (i != -1) _notifs[i] = notif.asRead();
    });
    if (!notif.id.startsWith('ws_')) {
      await _api.markNotificationRead(notif.id);
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() => _notifs = _notifs.map((n) => n.asRead()).toList());
    await _api.markAllNotificationsRead();
    _showSnack('All notifications marked as read');
  }

  // ── PAY NOW ───────────────────────────────────────────────────────────────
  Future<void> _payNow(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    // ✅ FIXED TypeError "0.00": Safe numeric parsing
    final totalAmountRaw =
        notif.data['total_amount'] ?? notif.data['payment_due'] ?? '0';
    final totalAmount = (double.tryParse(totalAmountRaw.toString()) ?? 0.0);

    setState(() => _actionLoading[orderItemId] = 'paying');
    await _markAsRead(notif);

    _pendingPaymentOrderItemId = orderItemId;
    _pendingPaymentAmount = totalAmount.toDouble();

    final prefs = await SharedPreferences.getInstance();
    final userRaw = prefs.getString('user_data');
    String name = '', email = '', phone = '';
    if (userRaw != null) {
      try {
        final u = jsonDecode(userRaw) as Map<String, dynamic>;
        name = u['name'] as String? ?? '';
        email = u['email'] as String? ?? '';
        phone = u['phone'] as String? ?? '';
      } catch (_) {}
    }

    if (kIsWeb) {
      _razorpayWeb.openPayment(
        orderItemId: orderItemId,
        amount: _pendingPaymentAmount!,
        customerName: name,
        email: email,
        phone: phone,
        onSuccess: (paymentId) => _handlePaymentSuccess(paymentId),
        onError: (error) {
          if (!mounted) return;
          setState(() => _actionLoading.remove(orderItemId));
          _showSnack(error, isSuccess: false);
          _pendingPaymentOrderItemId = null;
          _pendingPaymentAmount = null;
        },
      );
    } else {
      final options = {
        'key': AppConfig.razorpayKey,
        'amount': (_pendingPaymentAmount! * 100).toInt(),
        'currency': 'INR',
        'name': 'SandHere',
        'description': 'Order #$orderItemId',
        'prefill': {'name': name, 'email': email, 'contact': phone},
      };
      try {
        _razorpayNative?.open(options);
      } catch (e) {
        setState(() => _actionLoading.remove(orderItemId));
        _showSnack('Could not open payment. Try again.', isSuccess: false);
        _pendingPaymentOrderItemId = null;
        _pendingPaymentAmount = null;
      }
    }
  }

  // ── PAY LATER (customer requests) ─────────────────────────────────────────
  Future<void> _payLater(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    final selectedDays = await _showDayPickerSheet();
    if (selectedDays == null || !mounted) return;

    setState(() => _actionLoading[orderItemId] = 'pay_later');
    await _markAsRead(notif);

    final result = await _api.payLater(
      orderItemId,
      daysRequested: selectedDays,
    );

    if (!mounted) return;
    setState(() => _actionLoading.remove(orderItemId));

    if (result['success'] == true) {
      final dueFormatted = result['data']?['payment_due_formatted'] ?? '';
      _showSnack(
        'Pay later requested ($selectedDays day(s)). Due: $dueFormatted. Waiting for vendor.',
        isSuccess: true,
      );
      // Update notification to show "waiting for vendor" state:
      // status stays 'accepted', payment_status changes to 'pay_later'
      _updateNotifData(
        orderItemId,
        payStatus: 'pay_later',
        // Keep order_status as 'accepted' — vendor hasn't decided yet
        // The card will show the waiting banner instead of action buttons
        extraData: {
          'days_requested': selectedDays,
          'payment_due_formatted': dueFormatted,
        },
      );
    } else {
      _showSnack(
        result['message'] ?? 'Failed to request pay later.',
        isSuccess: false,
      );
    }
  }

  // ── ACCEPT PAY LATER (vendor) ──────────────────────────────────────────────
  Future<void> _acceptPayLater(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    setState(() => _actionLoading[orderItemId] = 'accepting');
    await _markAsRead(notif);

    final result = await _api.acceptPayLater(orderItemId);

    if (!mounted) return;
    setState(() => _actionLoading.remove(orderItemId));

    if (result['success'] == true) {
      final due = result['data']?['payment_due_formatted'] ?? '';
      _showSnack(
        'Pay later approved! Order is processing. Due: $due',
        isSuccess: true,
      );
      // Update to show "approved" state — no more Approve/Reject buttons
      _updateNotifData(
        orderItemId,
        newStatus: 'processing',
        payStatus: 'pay_later',
      );
    } else {
      _showSnack(result['message'] ?? 'Failed to approve.', isSuccess: false);
    }
  }

  // ── REJECT PAY LATER (vendor) ──────────────────────────────────────────────
  Future<void> _rejectPayLater(_Notif notif) async {
    final orderItemId = notif.data['order_item_id'] as int?;
    if (orderItemId == null) return;

    final reason = await _showRejectReasonDialog();
    if (reason == null || !mounted) return;

    setState(() => _actionLoading[orderItemId] = 'rejecting');
    await _markAsRead(notif);

    final result = await _api.rejectPayLater(orderItemId, reason: reason);

    if (!mounted) return;
    setState(() => _actionLoading.remove(orderItemId));

    if (result['success'] == true) {
      _showSnack('Pay later rejected. Order cancelled.', isSuccess: false);
      _updateNotifData(orderItemId, newStatus: 'declined', payStatus: 'unpaid');
    } else {
      _showSnack(result['message'] ?? 'Failed to reject.', isSuccess: false);
    }
  }

  // ── Helper: update notif data in the list ─────────────────────────────────
  // Finds notification by orderItemId and updates its status/payment fields.
  void _updateNotifData(
    int orderItemId, {
    String? newStatus,
    String? payStatus,
    Map<String, dynamic>? extraData,
  }) {
    setState(() {
      final i = _notifs.indexWhere(
        (n) => n.data['order_item_id'] == orderItemId,
      );
      if (i != -1) {
        final updated = Map<String, dynamic>.from(_notifs[i].data);
        if (newStatus != null) updated['status'] = newStatus;
        if (payStatus != null) updated['payment_status'] = payStatus;
        if (extraData != null) updated.addAll(extraData);
        _notifs[i] = _notifs[i].withData(updated);
      }
    });
  }

  // ── Day picker bottom sheet ───────────────────────────────────────────────
  Future<int?> _showDayPickerSheet() async {
    int tempDays = 3;
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose payment days',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.titleText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vendor will approve or reject your request.',
                style: TextStyle(fontSize: 13, color: AppColors.bodyText),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final isSelected = tempDays == day;
                  return GestureDetector(
                    onTap: () => setSheet(() => tempDays = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
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
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sandLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.sand.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: AppColors.sandDark,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Due by: ${_formatDueDate(tempDays)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sandDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, tempDays);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Request $tempDays-day Pay Later',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reject reason dialog ──────────────────────────────────────────────────
  Future<String?> _showRejectReasonDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Reject Pay Later',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.titleText,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Provide a reason (optional):',
              style: TextStyle(fontSize: 13, color: AppColors.bodyText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Cannot offer credit at this time…',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.bodyText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              ctrl.text.trim().isEmpty
                  ? 'Pay later not accepted.'
                  : ctrl.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
  }

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

  void _showSnack(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WebScaffold(
      isVendor: widget.isVendor,
      onSelectView: widget.onSelectView,
      selectedIndex: widget.isVendor ? 4 : 2,
      body: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            if (!_isDesktopWeb)
              FadeTransition(
                opacity: _headerFade,
                child: SlideTransition(
                  position: _headerSlide,
                  child: _buildHeader(),
                ),
              ),
            if (_isDesktopWeb) _buildDesktopTabBar(),
            _buildWsStatusBar(),
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: _themeAccent,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _error != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadFromHttp,
                      color: _themeAccent,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: SlideTransition(
                          position: _contentSlide,
                          child: _buildBody(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _desktopTabPill(0, 'All'),
          const SizedBox(width: 8),
          _desktopTabPill(1, 'Unread'),
          const Spacer(),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllAsRead,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _themeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _themeAccent.withOpacity(0.2)),
                ),
                child: Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _themeAccent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopTabPill(int index, String label) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _themeAccent : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.bodyText,
              ),
            ),
            if (index == 1 && _unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.3)
                      : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(gradient: _themeGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => widget.onSelectView(
                      widget.isVendor
                          ? ViewType.vendorHome
                          : ViewType.customerHome,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'SandHere',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        '$_unreadCount unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  _tabPill(0, 'All'),
                  const SizedBox(width: 8),
                  _tabPill(1, 'Unread'),
                  const Spacer(),
                  if (_unreadCount > 0)
                    GestureDetector(
                      onTap: _markAllAsRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabPill(int index, String label) {
    final isActive = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? _themeAccent : Colors.white.withOpacity(0.85),
              ),
            ),
            if (index == 1 && _unreadCount > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isActive
                      ? _themeAccent
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWsStatusBar() {
    if (_wsState == WsState.subscribed && _newArrived) {
      return Container(
        height: 32,
        color: _themeAccent.withOpacity(0.08),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _themeAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'New notification arrived',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _themeAccent,
              ),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.subscribed) {
      return Container(
        height: 28,
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 6,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: 5),
            Text(
              'Live — real-time updates on',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.connecting || _wsState == WsState.connected) {
      return Container(
        height: 28,
        color: AppColors.sandLight,
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.sandDark,
              ),
            ),
            SizedBox(width: 6),
            Text(
              'Connecting to live updates…',
              style: TextStyle(fontSize: 11, color: AppColors.sandDark),
            ),
          ],
        ),
      );
    }
    if (_wsState == WsState.failed || _wsState == WsState.authError) {
      return Container(
        height: 28,
        color: const Color(0xFFFEF2F2),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 12,
              color: AppColors.error,
            ),
            const SizedBox(width: 5),
            const Text(
              'Real-time unavailable  ·  ',
              style: TextStyle(fontSize: 11, color: AppColors.error),
            ),
            GestureDetector(
              onTap: _connectWebSocket,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBody() {
    final items = _filtered;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty) _buildEmptyState() else _buildGroupedList(items),
        ],
      ),
    );
  }

  Widget _buildGroupedList(List<_Notif> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = items
        .where((n) => _dayOf(n.createdAt).isAtSameMomentAs(today))
        .toList();
    final yesterdayItems = items
        .where((n) => _dayOf(n.createdAt).isAtSameMomentAs(yesterday))
        .toList();
    final olderItems = items
        .where((n) => _dayOf(n.createdAt).isBefore(yesterday))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayItems.isNotEmpty) ...[
          _groupLabel('Today'),
          ..._cards(todayItems),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          _groupLabel('Yesterday'),
          ..._cards(yesterdayItems),
        ],
        if (olderItems.isNotEmpty) ...[
          _groupLabel('Earlier'),
          ..._cards(olderItems),
        ],
      ],
    );
  }

  DateTime _dayOf(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.subtleText,
        letterSpacing: 0.3,
      ),
    ),
  );

  List<Widget> _cards(List<_Notif> items) {
    return List.generate(items.length, (i) {
      final notif = items[i];
      final isWs = notif.id.startsWith('ws_');
      return TweenAnimationBuilder<double>(
        key: ValueKey(notif.id),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: isWs ? 400 : 250 + i * 50),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: isWs
                ? Offset(30 * (1 - value), 0)
                : Offset(0, 14 * (1 - value)),
            child: child,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _NotifCard(
            notif: notif,
            actionLoading: _actionLoading,
            isVendor: widget.isVendor,
            onTap: () => _markAsRead(notif),
            onPayNow: () => _payNow(notif),
            onPayLater: () => _payLater(notif),
            onAcceptPayLater: () => _acceptPayLater(notif),
            onRejectPayLater: () => _rejectPayLater(notif),
            onViewOrders: () =>
                widget.onSelectView(ViewType.vendorRequestedOrder),
          ),
        ),
      );
    });
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: widget.isVendor
                    ? AppColors.vendorMuted
                    : AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 44,
                color: _themeAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _tab == 1 ? 'No unread notifications' : 'No notifications yet',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.titleText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _tab == 1
                  ? "You're all caught up!"
                  : "We'll notify you when something happens",
              style: const TextStyle(fontSize: 12, color: AppColors.bodyText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.subtleText,
            ),
            const SizedBox(height: 14),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.bodyText, fontSize: 14),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadFromHttp,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: _themeGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// NOTIFICATION CARD
// =============================================================================

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final Map<int, String> actionLoading;
  final bool isVendor;
  final VoidCallback onTap;
  final VoidCallback onPayNow;
  final VoidCallback onPayLater;
  final VoidCallback onAcceptPayLater;
  final VoidCallback onRejectPayLater;
  final VoidCallback onViewOrders;

  const _NotifCard({
    required this.notif,
    required this.actionLoading,
    required this.isVendor,
    required this.onTap,
    required this.onPayNow,
    required this.onPayLater,
    required this.onAcceptPayLater,
    required this.onRejectPayLater,
    required this.onViewOrders,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // BUTTON VISIBILITY RULES
  // These getters implement the exact flow logic. Read them carefully.
  // ═══════════════════════════════════════════════════════════════════════════

  /// CUSTOMER: Order was accepted AND not yet paid AND customer hasn't
  /// requested pay later yet → show Pay Now + Pay Later buttons
  bool get _showCustomerPayButtons =>
      !isVendor &&
      notif.orderStatus == 'accepted' &&
      notif.paymentStatus == 'unpaid';

  /// CUSTOMER: Customer already requested pay later, waiting for vendor
  /// to approve or reject → show waiting banner only
  bool get _showPayLaterWaiting =>
      !isVendor &&
      notif.orderStatus == 'accepted' &&
      notif.paymentStatus == 'pay_later';

  /// CUSTOMER: Vendor approved pay later → order moved to 'processing',
  /// customer still needs to pay → show Pay Now + due date banner
  bool get _showApprovedPayLaterPayButton =>
      !isVendor &&
      notif.orderStatus == 'processing' &&
      notif.paymentStatus == 'pay_later';

  /// CUSTOMER: Payment due reminder (tomorrow or today)
  bool get _showDueReminder => !isVendor && notif.isPaymentDueReminder;

  /// VENDOR: New order received, pending vendor action
  bool get _showVendorViewOrder =>
      isVendor && notif.orderStatus == 'pending' && !notif.isPayLaterPending;

  /// VENDOR: Customer requested pay later — vendor must approve or reject
  bool get _showVendorPayLaterActions => isVendor && notif.isPayLaterPending;

  @override
  Widget build(BuildContext context) {
    final orderItemId = notif.data['order_item_id'] as int?;
    final loadingKey = orderItemId != null ? actionLoading[orderItemId] : null;
    final isPayingNow = loadingKey == 'paying';
    final isPayingLater = loadingKey == 'pay_later';
    final isAccepting = loadingKey == 'accepting';
    final isRejecting = loadingKey == 'rejecting';
    final isBusy = loadingKey != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? AppColors.border
                : notif.accentColor.withOpacity(0.3),
            width: notif.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notif.isRead
                  ? AppColors.shadowSoft
                  : notif.accentColor.withOpacity(0.07),
              blurRadius: notif.isRead ? 8 : 16,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: notif.isRead
                          ? AppColors.surfaceAlt
                          : notif.bgColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      notif.icon,
                      color: notif.isRead
                          ? AppColors.subtleText
                          : notif.accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notif.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: notif.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: AppColors.titleText,
                                ),
                              ),
                            ),
                            Text(
                              _timeAgo(notif.createdAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.subtleText,
                              ),
                            ),
                            if (!notif.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: notif.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (notif.body.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            notif.body,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.bodyText,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // ── Status banner ─────────────────────────────────────────
              if (notif.orderStatus.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildStatusBanner(),
              ],

              // ── Order detail grid ─────────────────────────────────────
              if (_hasOrderDetail) ...[
                const SizedBox(height: 10),
                _buildOrderDetail(),
              ],

              // ── [CUSTOMER] Pay Now + Pay Later buttons ────────────────
              // Shown when: order accepted, payment unpaid, no pay-later yet
              if (_showCustomerPayButtons) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                _buildCustomerPayButtons(isPayingNow, isPayingLater, isBusy),
              ],

              // ── [CUSTOMER] Waiting for vendor to decide on pay later ───
              // Shown when: order accepted, pay_later requested, vendor pending
              if (_showPayLaterWaiting) ...[
                const SizedBox(height: 10),
                _buildPayLaterWaitingBanner(),
              ],

              // ── [CUSTOMER] Pay Now (after vendor approved pay later) ───
              // Shown when: order processing (approved), payment still pay_later
              if (_showApprovedPayLaterPayButton) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                _buildApprovedPayLaterSection(isPayingNow, isBusy),
              ],

              // ── [CUSTOMER] Payment due reminder ───────────────────────
              if (_showDueReminder) ...[
                const SizedBox(height: 10),
                _buildDueReminderBanner(isPayingNow, isBusy),
              ],

              // ── [VENDOR] Accept / Reject pay later ────────────────────
              if (_showVendorPayLaterActions) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                _buildVendorPayLaterActions(isAccepting, isRejecting, isBusy),
              ],

              // ── [VENDOR] View order button ─────────────────────────────
              if (_showVendorViewOrder) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.divider),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: onViewOrders,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'View Order & Accept / Decline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.vendor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Status banner ─────────────────────────────────────────────────────────
  Widget _buildStatusBanner() {
    final status = notif.orderStatus;
    final payStatus = notif.paymentStatus;
    final data = notif.data;

    Color bg, fg;
    String text;
    IconData icon;

    switch (status) {
      // ── Customer: order accepted, needs to pay ──────────────────────────
      case 'accepted':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.success;
        icon = Icons.check_circle_outline;
        text = payStatus == 'pay_later'
            ? 'Pay later requested — waiting for vendor approval'
            : 'Order accepted — choose how to pay';
        break;

      // ── Both: order declined / pay-later rejected ───────────────────────
      case 'declined':
        bg = const Color(0xFFFFEBEE);
        fg = AppColors.error;
        icon = Icons.cancel_outlined;
        final reason =
            data['rejection_reason'] as String? ?? 'No reason provided';
        text = 'Cancelled: $reason';
        break;

      // ── Customer: vendor approved pay-later, order is moving forward ────
      // ── OR direct pay completed (payment_status=paid)
      case 'processing':
        bg = AppColors.primaryMuted;
        fg = AppColors.primary;
        icon = Icons.autorenew_rounded;
        if (payStatus == 'pay_later') {
          final due = data['payment_due_formatted'] as String? ?? '';
          final amt = data['total_amount'] ?? '';
          text = 'Order processing! Pay ₹$amt by $due when ready.';
        } else if (payStatus == 'paid') {
          text = 'Payment received — order is being processed';
        } else {
          text = 'Order is being processed';
        }
        break;

      // ── Customer: fully delivered & paid ───────────────────────────────
      case 'delivered':
        bg = const Color(0xFFE8F5E9);
        fg = AppColors.success;
        icon = Icons.done_all_rounded;
        text = 'Delivered & payment confirmed!';
        break;

      case 'shipped':
        bg = AppColors.primaryMuted;
        fg = AppColors.primaryDark;
        icon = Icons.local_shipping_outlined;
        text = 'Out for delivery!';
        break;

      // ── Vendor: pay later requested, needs decision ────────────────────
      case 'pay_later_pending':
        bg = const Color(0xFFFFF8E1);
        fg = AppColors.warning;
        icon = Icons.hourglass_top_rounded;
        final days = data['days_requested']?.toString() ?? '';
        final due = data['payment_due_formatted'] as String? ?? '';
        text = days.isNotEmpty
            ? 'Pay later: $days day(s), due $due. Approve or reject.'
            : 'Pay later requested. Approve or reject.';
        break;

      default:
        bg = AppColors.sandLight;
        fg = AppColors.sandDark;
        icon = Icons.pending_outlined;
        text = 'Awaiting vendor response';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Order detail grid ─────────────────────────────────────────────────────
  bool get _hasOrderDetail {
    final d = notif.data;
    return d['order_id'] != null ||
        d['product_name'] != null ||
        d['quantity_unit'] != null;
  }

  Widget _buildOrderDetail() {
    final d = notif.data;
    final rows = <_DetailRow>[];

    if (d['order_id'] != null)
      rows.add(_DetailRow('Order', '#${d['order_id']}'));
    if ((d['product_name'] as String? ?? '').isNotEmpty)
      rows.add(_DetailRow('Product', d['product_name'] as String));
    if (d['quantity_unit'] != null)
      rows.add(_DetailRow('Quantity', '${d['quantity_unit']} unit'));
    final subtotal = double.tryParse(d['subtotal']?.toString() ?? '0') ?? 0.0;
    rows.add(_DetailRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}'));
    if ((double.tryParse(d['delivery_charge']?.toString() ?? '0') ?? 0) > 0)
      rows.add(_DetailRow('Delivery', '₹${d['delivery_charge']}'));
    if (d['total_amount'] != null)
      rows.add(_DetailRow('Total', '₹${d['total_amount']}'));
    if (d['days_requested'] != null)
      rows.add(_DetailRow('Pay later', '${d['days_requested']} day(s)'));
    if ((d['payment_due_formatted'] as String? ?? '').isNotEmpty)
      rows.add(_DetailRow('Due by', d['payment_due_formatted'] as String));
    if (d['distance_km'] != null)
      rows.add(_DetailRow('Distance', '${d['distance_km']} km'));
    if ((d['customer_name'] as String? ?? '').isNotEmpty)
      rows.add(_DetailRow('Customer', d['customer_name'] as String));
    if ((d['customer_phone'] as String? ?? '').isNotEmpty)
      rows.add(_DetailRow('Phone', d['customer_phone'] as String));
    if ((d['vendor_name'] as String? ?? '').isNotEmpty)
      rows.add(_DetailRow('Vendor', d['vendor_name'] as String));

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: rows
            .map(
              (r) => SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.subtleText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.value,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.titleText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── [Customer] Pay Now + Pay Later buttons ───────────────────────────────
  Widget _buildCustomerPayButtons(
    bool isPayingNow,
    bool isPayingLater,
    bool isBusy,
  ) {
    final total = notif.data['total_amount'] ?? notif.data['payment_due'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: isBusy ? null : onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPayingNow
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Pay Now ₹$total',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: isBusy ? null : onPayLater,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sandDark,
                side: BorderSide(color: AppColors.sand.withOpacity(0.6)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isPayingLater
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sandDark,
                      ),
                    )
                  : const Text(
                      'Pay Later',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ── [Customer] Waiting for vendor to approve pay later ───────────────────
  Widget _buildPayLaterWaitingBanner() {
    final days = notif.data['days_requested'];
    final due = notif.data['payment_due_formatted'] as String? ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sandLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.sand.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 14,
            color: AppColors.sandDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              days != null && due.isNotEmpty
                  ? 'Pay later requested ($days day(s), due $due) — waiting for vendor approval.'
                  : 'Pay later requested — waiting for vendor approval.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.sandDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── [Customer] Vendor approved pay later — Pay Now button + info ─────────
  Widget _buildApprovedPayLaterSection(bool isPayingNow, bool isBusy) {
    final total = notif.data['total_amount'] ?? 0;
    final due = notif.data['payment_due_formatted'] as String? ?? '';
    final days = notif.data['days_requested']?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Approved banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.sandLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.sand.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: AppColors.sandDark,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  days.isNotEmpty
                      ? 'Pay later approved ($days day(s)) • Due by $due'
                      : 'Pay later approved • Due by $due',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sandDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Pay Now button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: isBusy ? null : onPayNow,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isPayingNow
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Pay Now ₹$total',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── [Customer] Payment due reminder ──────────────────────────────────────
  Widget _buildDueReminderBanner(bool isPayingNow, bool isBusy) {
    final type = notif.reminderType;
    final due = notif.data['payment_due_formatted'] as String? ?? '';
    final amt = notif.data['total_amount'] ?? '';
    final isToday = type == 'today';
    final bg = isToday ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1);
    final fg = isToday ? AppColors.error : AppColors.warning;
    final ico = isToday ? Icons.alarm_rounded : Icons.access_time_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ico, size: 14, color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isToday
                      ? 'Payment due TODAY ($due) — pay immediately!'
                      : 'Payment due tomorrow ($due)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: isBusy ? null : onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: isPayingNow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Pay ₹$amt Now',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── [Vendor] Accept / Reject pay later ────────────────────────────────────
  Widget _buildVendorPayLaterActions(
    bool isAccepting,
    bool isRejecting,
    bool isBusy,
  ) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: isBusy ? null : onAcceptPayLater,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isAccepting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Approve Pay Later',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: isBusy ? null : onRejectPayLater,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isRejecting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.error,
                      ),
                    )
                  : const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailRow {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);
}
